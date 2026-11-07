/// Platform-conditional recording store: `dart:io` is only available on
/// native platforms, so the web build gets a no-op stub.
export 'recording_store_io.dart' if (dart.library.js_interop) 'recording_store_web.dart';
