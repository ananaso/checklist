#!/usr/bin/env bash
# Builds the checklist app and uploads it to the server.
#
#   deploy/deploy.sh          build and upload everything
#   deploy/deploy.sh web      only the web app
#   deploy/deploy.sh server   only the server binary (once server/ exists)
#
# Uploads go over SSH to $DEPLOY_HOST (an alias in ~/.ssh/config) under
# $REMOTE_DIR. Caddy serves $REMOTE_DIR/web directly, so a web upload is live
# immediately; checklist-server-restart.path restarts the server after a
# binary upload. See deploy/README.md for the one-time server setup.
set -euo pipefail

DEPLOY_HOST="${DEPLOY_HOST:-asahi-deploy}"
REMOTE_DIR="${REMOTE_DIR:-/srv/checklist}"
TARGET="${1:-all}"

cd "$(dirname "$0")/.."

deploy_web() {
  echo "==> Building web app"
  # --no-web-resources-cdn: serve Flutter's rendering engine ourselves rather
  # than loading it from Google's CDN.
  flutter build web --release --no-web-resources-cdn
  echo "==> Uploading web app to $DEPLOY_HOST:$REMOTE_DIR/web/"
  rsync -rlptvz --delete --chmod=D755,F644 build/web/ "$DEPLOY_HOST:$REMOTE_DIR/web/"
}

deploy_server() {
  if [[ ! -d server ]]; then
    echo "==> No server/ package yet; skipping server"
    return
  fi
  echo "==> Building server for linux-arm64"
  mkdir -p build/server
  (cd server && dart compile exe bin/server.dart \
    --target-os linux --target-arch arm64 -o ../build/server/checklist-server)
  echo "==> Uploading server to $DEPLOY_HOST:$REMOTE_DIR/bin/"
  # rsync writes to a temporary file and renames it into place, so the running
  # server is never left with a half-written binary.
  rsync -rlptvz --chmod=D755,F755 build/server/checklist-server "$DEPLOY_HOST:$REMOTE_DIR/bin/"
}

case "$TARGET" in
  all) deploy_server; deploy_web ;;
  web) deploy_web ;;
  server) deploy_server ;;
  *) echo "usage: $0 [all|web|server]" >&2; exit 2 ;;
esac

echo "==> Done"
