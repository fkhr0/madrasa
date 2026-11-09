/// Phone notifications while the app is closed, in the browser (Web Push).
library;

export 'web_push_stub.dart' if (dart.library.js_interop) 'web_push_web.dart';
