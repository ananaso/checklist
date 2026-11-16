#!/usr/bin/env bash
# Builds the checklist app and deploys it to the server.
#
#   deploy/deploy.sh          deploy the server and the web app
#   deploy/deploy.sh web      only the web app
#   deploy/deploy.sh server   only the server
#
# Everything goes over SSH to $DEPLOY_HOST (an alias in ~/.ssh/config) under
# $REMOTE_DIR:
#
#   web/      the Flutter web build, served by Caddy (live immediately)
#   src/      the server's source, uploaded and compiled on the server
#   server/   the compiled server; checklist-server-restart.path restarts the
#             service when a new build lands
#
# The server is compiled there, not here, because Dart can't cross-compile a
# server that bundles SQLite for another architecture. See deploy/README.md
# for the one-time server setup.
set -euo pipefail

DEPLOY_HOST="${DEPLOY_HOST:-asahi-deploy}"
REMOTE_DIR="${REMOTE_DIR:-/srv/checklist}"
# The Dart SDK on the server.
REMOTE_DART="${REMOTE_DART:-/opt/dart-sdk/bin/dart}"
TARGET="${1:-all}"

cd "$(dirname "$0")/.."

deploy_web() {
  echo "==> Building web app"
  # --no-web-resources-cdn: serve Flutter's rendering engine ourselves rather
  # than loading it from Google's CDN.
  flutter build web --release --no-web-resources-cdn
  tool/fetch_fallback_fonts.sh build/web/fonts
  echo "==> Uploading web app to $DEPLOY_HOST:$REMOTE_DIR/web/"
  rsync -rlptz --delete --chmod=D755,F644 build/web/ "$DEPLOY_HOST:$REMOTE_DIR/web/"
}

deploy_server() {
  echo "==> Uploading server source to $DEPLOY_HOST:$REMOTE_DIR/src/"
  rsync -rlptz --delete --chmod=D755,F644 \
    --exclude .dart_tool/ --exclude build/ \
    --include /packages/ --include /packages/checklist_core/*** \
    --include /server/*** --exclude '*' \
    ./ "$DEPLOY_HOST:$REMOTE_DIR/src/"

  echo "==> Building server on $DEPLOY_HOST"
  # The build goes to a scratch directory first, so a failed build leaves the
  # running server untouched. The stamp file is written last; the restart
  # watcher reacts to it.
  ssh "$DEPLOY_HOST" bash -s -- "$REMOTE_DIR" "$REMOTE_DART" <<'REMOTE'
set -euo pipefail
remote_dir="$1"
dart="$2"
cd "$remote_dir/src/server"
"$dart" pub get --enforce-lockfile
rm -rf "$remote_dir/build"
"$dart" build cli -o "$remote_dir/build"
rsync -rlpt --delete "$remote_dir/build/bundle/" "$remote_dir/server/"
date -Is > "$remote_dir/server/.deployed"
echo "Server built; it restarts in a moment."
REMOTE
}

case "$TARGET" in
  all) deploy_server; deploy_web ;;
  web) deploy_web ;;
  server) deploy_server ;;
  *) echo "usage: $0 [all|web|server]" >&2; exit 2 ;;
esac

echo "==> Done"
