/// App-wide constants that are expected to change between delivery phases.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

const String kAppName = '课堂速记';

/// Backend base URL. On a USB-connected Android device use
/// `adb reverse tcp:8000 tcp:8000` and keep the default localhost URL.
///
/// Override at build time:
///   flutter run --dart-define=WS_BASE=ws://192.168.1.20:8000
const String kWsBaseUrl = String.fromEnvironment(
  'WS_BASE',
  defaultValue: 'ws://127.0.0.1:8000',
);

/// `--dart-define=DEMO=true` switches back to the scripted phase-1 transcript
/// so the UI can be demoed without a backend or microphone.
const bool kUseDemoSession = bool.fromEnvironment('DEMO', defaultValue: false);

/// The web platform cannot capture raw 16 kHz PCM from the microphone, so it
/// always falls back to the scripted demo session.
bool get useDemoSession => kIsWeb || kUseDemoSession;

/// `ws(s)://host:port/ws/asr`
Uri get asrEndpoint {
  final String base =
      kWsBaseUrl.endsWith('/') ? kWsBaseUrl.substring(0, kWsBaseUrl.length - 1) : kWsBaseUrl;
  return Uri.parse('$base/ws/asr');
}
