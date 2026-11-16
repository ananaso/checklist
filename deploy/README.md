# Deploying to the home server

How the checklist web app runs on the Asahi Fedora server:

```
Internet ─► Caddy ── forward_auth ──► Authelia (login, 127.0.0.1:9091)
              │  (only once logged in)
              ├── /api/*  ──► checklist-server (127.0.0.1:8090) ──► SQLite
              └── /*      ──► /srv/checklist/web (Flutter web build)
```

- The **web app** keeps no data of its own. It calls the checklist server for
  everything, and a WebSocket tells it when anyone changes something, so you
  both see the same lists live.
- The **checklist server** is a Dart program holding the only copy of the
  data, in `/var/lib/checklist/checklist.sqlite`. It only listens on
  localhost and refuses requests that didn't come through the login.
- **Authelia** handles logins; Caddy asks it about every request.
- The **Android app** still keeps its own local data (it doesn't use the
  server yet).

Everything is either a plain systemd service or static files served by Caddy.

| File | Goes to |
| --- | --- |
| `caddy/checklist.caddy` | your Caddyfile (paste in or `import`) |
| `authelia/configuration.yml` | `/etc/authelia/configuration.yml` |
| `authelia/users.yml.example` | `/etc/authelia/users.yml` (filled in) |
| `systemd/*.service`, `systemd/*.path` | `/etc/systemd/system/` |
| `deploy.sh` | run from your dev machine |

## One-time server setup

Everything below runs on the server unless it says otherwise. Replace
`example.com` with your domain throughout.

### 1. DNS

Point `checklist.example.com` and `auth.example.com` at the server, the same
way as your other Caddy sites.

### 2. Deploy account and directories

`deploy.sh` logs in as the account behind your `asahi-deploy` SSH alias,
uploads files with rsync and runs the server build there, so that account
needs an ordinary shell. If your existing key is locked to your website's
directory (e.g. with `rrsync`), add a second alias for this app and set
`DEPLOY_HOST` when running `deploy.sh`.

```sh
sudo dnf install -y rsync unzip
sudo mkdir -p /srv/checklist/{web,src,server,build}
sudo chown -R <deploy-user>: /srv/checklist
# SELinux: let Caddy read the web files and systemd run the server.
sudo semanage fcontext -a -t httpd_sys_content_t '/srv/checklist/web(/.*)?'
sudo semanage fcontext -a -t bin_t '/srv/checklist/server(/.*)?'
sudo restorecon -Rv /srv/checklist
```

### 3. Dart SDK (to build the server)

Dart can't cross-compile this server for another architecture, so it's built
on the server. Fedora doesn't package Dart; install the official arm64 SDK
(3.11 or newer, ideally the version that comes with your Flutter: run
`flutter --version` on your dev machine):

```sh
DART=3.14.0
curl -fLO "https://storage.googleapis.com/dart-archive/channels/stable/release/$DART/sdk/dartsdk-linux-arm64-release.zip"
sudo rm -rf /opt/dart-sdk && sudo unzip -q dartsdk-linux-arm64-release.zip -d /opt
/opt/dart-sdk/bin/dart --version
```

The last command must print a version. If it crashes instead, tell Claude:
Asahi uses 16K memory pages, which some software doesn't expect.

The first build downloads the server's packages from pub.dev and a SQLite
build from GitHub, so the server needs outbound internet for builds.

### 4. Authelia

Download the `linux-arm64` tarball from
<https://github.com/authelia/authelia/releases> (tested against v4.39.28)
and install the binary:

```sh
tar xzf authelia-v*-linux-arm64.tar.gz authelia
sudo install -m 755 authelia /usr/local/bin/authelia
```

Config, secrets and users. They're all root-only except the config, which
holds no secrets:

```sh
sudo mkdir -p /etc/authelia/secrets
sudo install -m 644 configuration.yml /etc/authelia/configuration.yml
for s in jwt_secret session_secret storage_key; do
  openssl rand -hex 64 | sudo tee /etc/authelia/secrets/$s >/dev/null
done
sudo chmod 600 /etc/authelia/secrets/*

# One password hash per person; paste each into users.yml.
authelia crypto hash generate argon2
sudo install -m 600 users.yml /etc/authelia/users.yml
```

Keep `storage_key` safe: Authelia can't read its database without it.

```sh
sudo cp authelia.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now authelia
journalctl -u authelia -f   # look for "Startup complete"
```

### 5. Checklist server

Install the units:

```sh
sudo cp checklist-server.service checklist-server-restart.service \
  checklist-server-restart.path /etc/systemd/system/
sudo systemctl daemon-reload
```

Build it once from your dev machine, then start it on the server:

```sh
deploy/deploy.sh server                      # dev machine
sudo systemctl enable --now checklist-server checklist-server-restart.path
journalctl -u checklist-server -f            # "Checklist server listening..."
```

### 6. Caddy

Add `caddy/checklist.caddy` to your Caddyfile, then:

```sh
sudo systemctl reload caddy
```

### 7. Web app

From your dev machine (needs Flutter, rsync and curl):

```sh
deploy/deploy.sh web
```

Open `https://checklist.example.com`. You should be sent to the Authelia login
page, then back to an empty checklist app.

### 8. Bring over your Android checklists

1. In the Android app: ⋮ → **Export**, and save the file.
2. Get the file to a computer or phone that can open the web app.
3. In the web app: ⋮ → **Import**, choose the file, confirm **Replace**.

Import replaces everything on the server, so do it before you both start
adding lists.

### 9. On each phone

1. Open `https://checklist.example.com` in Safari (or Chrome on Android).
2. Log in with **Remember me** ticked, which keeps you logged in for 3 months.
3. Share → **Add to Home Screen**.
4. Open it from the Home Screen and log in once more. Home Screen apps on iOS
   keep their own cookies, separate from Safari.

## Updating after the first deploy

```sh
deploy/deploy.sh          # server and web app
deploy/deploy.sh web      # just the web app
deploy/deploy.sh server   # just the server
```

- Web changes are live as soon as the upload finishes; reload the app to see
  them.
- The server is rebuilt on the server, and restarts by itself a moment after
  the build finishes. If the build fails, the old version keeps running.
- Deploy the server before the web app when a change touches both (the
  default `deploy.sh` order), so the new app never talks to an old server.

Settings, as environment variables: `DEPLOY_HOST` (default `asahi-deploy`),
`REMOTE_DIR` (default `/srv/checklist`) and `REMOTE_DART` (default
`/opt/dart-sdk/bin/dart`), e.g. `DEPLOY_HOST=asahi-checklist deploy/deploy.sh`.

## Backups

All checklist data is in `/var/lib/checklist/`. To take a consistent copy
while the server runs (`sudo dnf install sqlite` for the `sqlite3` command):

```sh
sudo sqlite3 /var/lib/checklist/checklist.sqlite \
  ".backup '/root/checklist-$(date +%F).sqlite'"
```

The app's ⋮ → **Export** also downloads everything as a file that **Import**
can restore.

## Local development

Run the server with the web build and no login, on your own machine:

```sh
flutter build web --no-web-resources-cdn && tool/fetch_fallback_fonts.sh build/web/fonts
cd server && dart run bin/server.dart --database /tmp/checklist.sqlite \
  --web-root ../build/web --no-auth
# open http://127.0.0.1:8090
```

Tests: `dart test` in `packages/checklist_core` and in `server`.

## Things to know

- Collapsing a group on the home screen collapses it for both of you: it's
  stored with the data like everything else.
- Emoji and symbols in titles use fonts served from `/fonts/` on your own
  server, so the app makes no requests to Google. Other scripts (e.g.
  Chinese, Japanese) show as empty boxes unless you add them to
  `tool/fetch_fallback_fonts.sh`.

## Troubleshooting

- **The app shows nothing, or reloads once and stops:** the server refused
  its calls. `journalctl -u checklist-server` and the browser's network tab:
  - `401`: the request reached the server without a login. Check that the
    `forward_auth` block includes `copy_headers Remote-User`.
  - `502`: the server isn't running (`systemctl status checklist-server`).
- **Login loop or 403 from Caddy:** `journalctl -u authelia`. Check that the
  domain in the `access_control` rule matches the site exactly.
- **Caddy 403 on the app files:** SELinux labels; rerun `restorecon -Rv
  /srv/checklist`.
- **Server won't start after a deploy (`status=203/EXEC`):** SELinux label
  on `/srv/checklist/server`; rerun `restorecon -Rv /srv/checklist`.
- **Locked out:** five wrong passwords bans the account for an hour
  (`regulation` in the Authelia config).
- **Forgot a password:** generate a new hash, edit `/etc/authelia/users.yml`,
  `sudo systemctl restart authelia`.
