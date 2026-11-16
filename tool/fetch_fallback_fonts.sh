#!/usr/bin/env bash
# Copies the fallback fonts Flutter web needs for emoji and symbols into a
# web build, so the app never has to fetch them from Google Fonts.
#
#   tool/fetch_fallback_fonts.sh build/web/fonts
#
# Flutter draws text itself, so when a title contains a character its built-in
# font lacks (e.g. an emoji), it downloads a matching Noto font. The web build
# points those downloads at fonts/ on our own server (web/flutter_bootstrap.js);
# this script fills that directory. Characters from scripts not listed below
# show as empty boxes instead.
#
# The font files are fetched once from fonts.gstatic.com at build time and
# cached in build/fallback-fonts-cache/.
set -euo pipefail

# Font families to host, as named in Flutter's list. Add e.g. "Noto Sans JP"
# for Japanese (125 files, about 10 MB).
FAMILIES=(
  "Noto Color Emoji"
  "Noto Sans Symbols"
  "Noto Sans Symbols 2"
  "Noto Sans Math"
)

OUT="${1:?usage: $0 <output dir, e.g. build/web/fonts>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="$ROOT/build/fallback-fonts-cache"

# The list of fallback fonts for the Flutter version in use.
FLUTTER_ROOT="$(cd "$(dirname "$(readlink -f "$(command -v flutter)")")/.." && pwd)"
LIST="$FLUTTER_ROOT/bin/cache/flutter_web_sdk/lib/_engine/engine/font_fallback_data.dart"
if [[ ! -f "$LIST" ]]; then
  echo "Can't find Flutter's fallback font list at $LIST" >&2
  echo "(run 'flutter build web' once first)" >&2
  exit 1
fi

# Each entry is a name line, e.g. 'Noto Color Emoji 3', followed by its path.
paths=()
for family in "${FAMILIES[@]}"; do
  pattern="^    '${family}( [0-9]+)?',\$"
  while IFS= read -r path; do
    paths+=("$path")
  done < <(grep -A1 -E "$pattern" "$LIST" | grep -oE "[a-z0-9]+/v[0-9]+/[A-Za-z0-9_-]+(\.[0-9]+)?\.(woff2|ttf|otf)")
  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "No fonts found for \"$family\" in $LIST" >&2
    exit 1
  fi
done

mkdir -p "$CACHE" "$OUT"
for path in "${paths[@]}"; do
  if [[ ! -f "$CACHE/$path" ]]; then
    mkdir -p "$(dirname "$CACHE/$path")"
    curl -fsSL -o "$CACHE/$path.tmp" "https://fonts.gstatic.com/s/$path"
    mv "$CACHE/$path.tmp" "$CACHE/$path"
  fi
  mkdir -p "$(dirname "$OUT/$path")"
  cp "$CACHE/$path" "$OUT/$path"
done
echo "Copied ${#paths[@]} fallback font files into $OUT ($(du -sh "$OUT" | cut -f1))"
