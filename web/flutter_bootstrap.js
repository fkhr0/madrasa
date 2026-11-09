{{flutter_js}}
{{flutter_build_config}}

// Starts the app without Flutter's old service worker (deprecated: it
// unregisters itself and reloads the page). Push notifications have their
// own service worker in push/sw.js.
_flutter.loader.load();
