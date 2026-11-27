/// Platform-conditional debug audio recorder: `dart:io` is native-only.
library;

export 'debug_recorder_io.dart' if (dart.library.js_interop) 'debug_recorder_web.dart';
