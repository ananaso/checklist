# web/

The shell for the Flutter web build (`flutter build web`).

`sqlite3.wasm` and `drift_worker.js` let Drift run SQLite in the browser. They
are tied to the `sqlite3` and `drift` versions in `pubspec.lock`, so when either
package is upgraded, download the matching files again:

```sh
SQLITE3=3.7.0  # version of sqlite3 in pubspec.lock
DRIFT=2.35.2   # version of drift in pubspec.lock
curl -fLo web/sqlite3.wasm \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$SQLITE3/sqlite3.wasm"
curl -fLo web/drift_worker.js \
  "https://github.com/simolus3/drift/releases/download/drift-$DRIFT/drift_worker.js"
```

Build with `--no-web-resources-cdn` (as `deploy/deploy.sh` does) so the
rendering engine is served from our own server rather than Google's CDN.
