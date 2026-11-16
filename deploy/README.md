# Deploying to the home server

How the checklist web app runs on the Asahi Fedora server:

```
Internet ─► Caddy ── forward_auth ──► Authelia (login, 127.0.0.1:9091)
              │  (only once logged in)
              ├── /api/*  ──► checklist-server (127.0.0.1:8090)   [step 2]
              └── /*      ──► /srv/checklist/web (Flutter web build)
```

Everything is either a plain systemd service or static files served by Caddy.

| File | Goes to |
| --- | --- |
| `caddy/checklist.caddy` | your Caddyfile (paste in or `import`) |
| `authelia/configuration.yml` | `/etc/authelia/configuration.yml` |
| `authelia/users.yml.example` | `/etc/authelia/users.yml` (filled in) |
| `systemd/*.service`, `systemd/*.path` | `/etc/systemd/system/` |
| `deploy.sh` | run from your dev machine |

Until step 2 (the checklist server) is built, the web app keeps its data in
each browser, so you and your partner won't see each other's lists yet. The
login, hosting and deploy flow can all be set up and tested now.

## One-time server setup

Everything below runs on the server. Replace `example.com` with your domain
throughout.

### 1. DNS

Point `checklist.example.com` and `auth.example.com` at the server, the same
way as your other Caddy sites.

### 2. Web root and deploy access

```sh
sudo mkdir -p /srv/checklist/web /srv/checklist/bin
sudo chown -R <deploy-user>: /srv/checklist
# SELinux: let Caddy read the web files and systemd run the server binary.
sudo semanage fcontext -a -t httpd_sys_content_t '/srv/checklist/web(/.*)?'
sudo semanage fcontext -a -t bin_t '/srv/checklist/bin(/.*)?'
sudo restorecon -Rv /srv/checklist
```

`<deploy-user>` is whichever account your `asahi-deploy` SSH alias logs in
as. If that key is locked to your website's directory (e.g. with `rrsync`),
add a second alias for this app and set `DEPLOY_HOST` when running
`deploy.sh`.

### 3. Authelia

Download the `linux-arm64` tarball from
<https://github.com/authelia/authelia/releases> (tested against v4.39.28)
and install the binary:

```sh
tar xzf authelia-v*-linux-arm64.tar.gz authelia
sudo install -m 755 authelia /usr/local/bin/authelia
```

Config, secrets and users (all root-only except the config, which holds no
secrets):

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

Start it:

```sh
sudo cp authelia.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now authelia
journalctl -u authelia -f   # look for "Startup complete"
```

### 4. Caddy

Add `caddy/checklist.caddy` to your Caddyfile, then:

```sh
sudo systemctl reload caddy
```

### 5. First deploy

From your dev machine (needs Flutter and rsync):

```sh
deploy/deploy.sh web
```

Open `https://checklist.example.com`. You should be sent to the Authelia login
page, then back to the app.

### 6. On each phone

1. Open `https://checklist.example.com` in Safari (or Chrome on Android).
2. Log in with **Remember me** ticked, which keeps you logged in for 3 months.
3. Share → **Add to Home Screen**.
4. Open it from the Home Screen and log in once more. Home Screen apps on iOS
   keep their own cookies, separate from Safari.

## Updating after the first deploy

```sh
deploy/deploy.sh          # web app and server
deploy/deploy.sh web      # just the web app
deploy/deploy.sh server   # just the server
```

Web changes are live as soon as the upload finishes; reload the app to pick
them up. Server uploads restart the service automatically (step 2).

Settings: `DEPLOY_HOST` (default `asahi-deploy`) and `REMOTE_DIR` (default
`/srv/checklist`), e.g. `DEPLOY_HOST=asahi-checklist deploy/deploy.sh web`.

## Step 2: the checklist server (not built yet)

Once `server/` exists:

```sh
sudo cp checklist-server.service checklist-server-restart.service \
  checklist-server-restart.path /etc/systemd/system/
sudo systemctl daemon-reload
deploy/deploy.sh server   # from your dev machine
sudo systemctl enable --now checklist-server checklist-server-restart.path
```

Then uncomment the `/api/*` block in the Caddy config and reload Caddy. The
database lives in `/var/lib/checklist/`; back that directory up.

## Troubleshooting

- **Login loop or 403 from Caddy:** `journalctl -u authelia`. Check that the
  domain in the `access_control` rule matches the site exactly.
- **Caddy 403 on the app files:** SELinux labels; rerun `restorecon -Rv
  /srv/checklist`.
- **Locked out:** five wrong passwords bans the account for an hour
  (`regulation` in the config).
- **Forgot a password:** generate a new hash, edit `/etc/authelia/users.yml`,
  `sudo systemctl restart authelia`.
