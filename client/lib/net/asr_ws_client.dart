import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Thin WebSocket transport for the ASR proxy.
///
/// Transport failures are surfaced as a `__closed` message so the session can
/// distinguish them from server-level `error` messages (which must not trigger
/// a reconnect).
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
    try {
      await channel.ready.timeout(connectTimeout);
    } catch (_) {
      try {
        await channel.sink.close();
      } catch (_) {}
      rethrow;
    }
    _channel = channel;
    _subscription = channel.stream.listen(
      (dynamic data) {
        if (data is! String) return;
        try {
          final Object? decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) _add(decoded);
        } catch (_) {
          // Ignore malformed frames; the server is the only writer.
        }
      },
      onError: (Object error) => _add(<String, dynamic>{'type': '__closed', 'message': error.toString()}),
      onDone: () => _add(<String, dynamic>{'type': '__closed', 'message': '连接已断开'}),
    );
  }

  void sendJson(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (_) {
      // Channel closed mid-flight; the onDone handler drives reconnect.
    }
  }

  void sendAudio(Uint8List bytes) {
    try {
      _channel?.sink.add(bytes);
    } catch (_) {
      // Channel closed mid-flight; the onDone handler drives reconnect.
    }
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (!_messages.isClosed) await _messages.close();
  }

  void _add(Map<String, dynamic> message) {
    if (!_messages.isClosed) _messages.add(message);
  }
}
