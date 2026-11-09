import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';

/// One "something changed" message from the server, e.g.
/// `{type: message.new, conversationId: ...}`.
class RealtimeEvent {
  final String type;
  final Map<String, dynamic> data;

  const RealtimeEvent(this.type, this.data);

  String? operator [](String key) => data[key] as String?;
}

/// The live connection to the server (server/src/realtime/hub.js).
class RealtimeClient {
  final ApiClient _api;

  RealtimeClient(this._api);

  final _events = StreamController<RealtimeEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  int _failures = 0;
  bool _closed = false;
  bool _connected = false;

  Stream<RealtimeEvent> get events => _events.stream;

  bool get isConnected => _connected;

  /// The socket address: http → ws, https → wss.
  Uri get _address {
    final base = _api.resolve('/ws');
    return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws');
  }

  Future<void> connect() async {
    if (_closed) return;
    try {
      // A quick signed-in request refreshes an expired access token first.
      await _api.get('/me');
      final token = _api.accessToken;
      if (token == null) return; // signed out meanwhile

      final channel = WebSocketChannel.connect(_address);
      _channel = channel;
      await channel.ready;
      channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));

      _subscription = channel.stream.listen(
        _onMessage,
        onDone: _onLost,
        onError: (_) => _onLost(),
        cancelOnError: true,
      );
    } catch (_) {
      _onLost();
    }
  }

  void _onMessage(dynamic text) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(text as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = json['type'] as String? ?? '';
    if (type == 'ready') {
      _connected = true;
      _failures = 0;
      return;
    }
    _events.add(RealtimeEvent(type, json));
  }

  void _onLost() {
    _connected = false;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    if (_closed) return;

    // 2, 4, 8, 16, 30, 30... seconds.
    final wait = Duration(seconds: (2 << _failures.clamp(0, 4)).clamp(2, 30));
    _failures++;
    _retry?.cancel();
    _retry = Timer(wait, connect);
  }

  /// On sign-out: stop for good.
  void close() {
    _closed = true;
    _connected = false;
    _retry?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _events.close();
  }
}
