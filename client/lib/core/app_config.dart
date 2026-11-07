/// App-wide constants that are expected to change between delivery phases.
library;

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

/// `--dart-define=DEMO=true` switches to the scripted transcript so the UI can
/// be demoed without a backend or microphone.
///
/// Web uses the real recording session too: the `record` plugin's web backend
/// (`record_web`) captures 16 kHz mono PCM16 through an AudioWorklet.
const bool kUseDemoSession = bool.fromEnvironment('DEMO', defaultValue: false);

bool get useDemoSession => kUseDemoSession;

/// `ws(s)://host:port/ws/asr`
Uri get asrEndpoint {
  final String base =
      kWsBaseUrl.endsWith('/') ? kWsBaseUrl.substring(0, kWsBaseUrl.length - 1) : kWsBaseUrl;
  return Uri.parse('$base/ws/asr');
}
