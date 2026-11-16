{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Fonts for emoji and symbols are served by our own server (copied in by
    // tool/fetch_fallback_fonts.sh) instead of being fetched from Google Fonts.
    fontFallbackBaseUrl: "fonts/",
  },
});
