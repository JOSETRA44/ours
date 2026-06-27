import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/cdp_exception.dart';

class CdpClient {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 0;

  bool get isConnected => _channel != null;

  Future<void> connect({int port = AppConstants.cdpPort}) async {
    if (isConnected) await disconnect();

    final versionResponse = await http
        .get(Uri.parse('http://localhost:$port/json/version'))
        .timeout(const Duration(seconds: 5));

    if (versionResponse.statusCode != 200) {
      throw CdpConnectionException('CDP endpoint returned ${versionResponse.statusCode}');
    }

    final json = jsonDecode(versionResponse.body) as Map<String, dynamic>;
    final wsUrl = json['webSocketDebuggerUrl'] as String?;
    if (wsUrl == null) {
      throw CdpConnectionException('webSocketDebuggerUrl not found in /json/version response');
    }

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    await _channel!.ready;

    _sub = _channel!.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
    );
  }

  Future<String> createTab(String url) async {
    final result = await _send('Target.createTarget', {'url': url});
    return result['targetId'] as String;
  }

  Future<void> closeTab(String targetId) async {
    try {
      await _send('Target.closeTarget', {'targetId': targetId});
    } catch (_) {
      // Tab may already be closed by the user
    }
  }

  Future<List<Map<String, dynamic>>> listTargets() async {
    final result = await _send('Target.getTargets', {});
    return List<Map<String, dynamic>>.from(
        result['targetInfos'] as List? ?? []);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (_channel == null) throw CdpConnectionException('Not connected to CDP');

    final id = ++_nextId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    _channel!.sink.add(jsonEncode({
      'id': id,
      'method': method,
      'params': params,
    }));

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pending.remove(id);
        throw CdpTimeoutException('Timeout waiting for response to $method');
      },
    );
  }

  void _handleMessage(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    final id = msg['id'] as int?;
    if (id == null) return; // CDP event — ignore

    final completer = _pending.remove(id);
    if (completer == null) return;

    if (msg.containsKey('error')) {
      final err = (msg['error'] as Map<String, dynamic>)['message'] as String;
      completer.completeError(CdpException(err));
    } else {
      completer.complete(
          (msg['result'] as Map<String, dynamic>?) ?? {});
    }
  }

  void _handleError(Object error) {
    for (final c in _pending.values) {
      c.completeError(CdpConnectionException('WebSocket error: $error'));
    }
    _pending.clear();
  }

  void _handleDone() {
    for (final c in _pending.values) {
      c.completeError(CdpConnectionException('WebSocket closed unexpectedly'));
    }
    _pending.clear();
    _channel = null;
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _sub = null;
    _channel = null;
    _pending.clear();
  }
}
