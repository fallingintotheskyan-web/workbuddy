import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Thin WebSocket transport for the ASR proxy.
///
/// It only moves text control messages and binary PCM frames; protocol parsing
/// lives in `asr_protocol.dart` and session state lives in `WsRecordingSession`.
class AsrWsClient {
  AsrWsClient({required this.endpoint, this.connectTimeout = const Duration(seconds: 8)});

  final Uri endpoint;
  final Duration connectTimeout;

  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  Future<void> connect() async {
    final WebSocketChannel channel = WebSocketChannel.connect(endpoint);
    await channel.ready.timeout(connectTimeout);
    _channel = channel;
    _subscription = channel.stream.listen(
      (dynamic data) {
        if (data is! String) return;
        try {
          final Object? decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) _messages.add(decoded);
        } catch (_) {
          // Ignore malformed frames; the server is the only writer.
        }
      },
      onError: (Object error) {
        _messages.add(<String, dynamic>{'type': 'error', 'message': error.toString()});
      },
      onDone: () {
        _messages.add(<String, dynamic>{'type': 'error', 'message': '连接已断开'});
      },
    );
  }

  void sendJson(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void sendAudio(Uint8List bytes) {
    _channel?.sink.add(bytes);
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    await _messages.close();
  }
}
