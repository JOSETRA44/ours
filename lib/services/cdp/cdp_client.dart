import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/cdp_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/models/cdp_event.dart';
import '../../domain/models/cdp_tab.dart';

class CdpClient {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 0;

  // Broadcast stream of CDP push events (targetCreated, targetDestroyed, etc.)
  final _eventController = StreamController<CdpEvent>.broadcast();
  Stream<CdpEvent> get events => _eventController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect({int port = AppConstants.cdpPort}) async {
    if (isConnected) {
      appLogger.d('[CdpClient] Already connected — disconnecting first');
      await disconnect();
    }

    appLogger.i('[CdpClient] Connecting to CDP on port $port...');

    final versionResponse = await http
        .get(Uri.parse('http://localhost:$port/json/version'))
        .timeout(const Duration(seconds: 5));

    if (versionResponse.statusCode != 200) {
      throw CdpConnectionException(
          'CDP /json/version returned ${versionResponse.statusCode}');
    }

    final json = jsonDecode(versionResponse.body) as Map<String, dynamic>;
    appLogger.d('[CdpClient] Browser: ${json['Browser']}');

    final wsUrl = json['webSocketDebuggerUrl'] as String?;
    if (wsUrl == null) {
      throw CdpConnectionException(
          'webSocketDebuggerUrl missing — Chrome may not have --remote-debugging-port');
    }

    appLogger.d('[CdpClient] WS URL: $wsUrl');
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    await _channel!.ready;

    _sub = _channel!.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
    );

    appLogger.i('[CdpClient] Connected ✓');
  }

  /// Tells Chrome to start emitting Target events (targetCreated, targetDestroyed, etc.)
  /// Must be called once after connect() to enable the mirror stream.
  Future<void> enableTargetDiscovery() async {
    await _send('Target.setDiscoverTargets', {'discover': true});
    appLogger.i('[CdpClient] Target discovery enabled — events will stream');
  }

  Future<String> createTab(String url) async {
    appLogger.d('[CdpClient] createTab → $url');
    final result = await _send('Target.createTarget', {'url': url});
    final targetId = result['targetId'] as String;
    appLogger.d('[CdpClient] Tab created → $targetId');
    return targetId;
  }

  Future<void> closeTab(String targetId) async {
    appLogger.d('[CdpClient] closeTab → $targetId');
    try {
      await _send('Target.closeTarget', {'targetId': targetId});
    } catch (e) {
      appLogger.d('[CdpClient] closeTab silently ignored: $e');
    }
  }

  Future<List<Map<String, dynamic>>> listTargets() async {
    final result = await _send('Target.getTargets', {});
    return List<Map<String, dynamic>>.from(
        result['targetInfos'] as List? ?? []);
  }

  /// Returns all open page-type tabs with navigable URLs.
  Future<List<CdpTab>> captureOpenTabs() async {
    appLogger.i('[CdpClient] Capturing open tabs...');

    final targets = await listTargets();
    appLogger.d('[CdpClient] Total targets: ${targets.length}');

    final tabs = targets
        .where((t) => t['type'] == 'page')
        .map((t) => CdpTab(
              targetId: t['targetId'] as String? ?? '',
              url: t['url'] as String? ?? '',
              title: t['title'] as String? ?? '',
            ))
        .where((tab) => tab.isNavigable)
        .toList();

    appLogger.i('[CdpClient] ══════════════════════════════════════════');
    appLogger.i('[CdpClient] CAPTURED TABS (${tabs.length})');
    for (var i = 0; i < tabs.length; i++) {
      appLogger.i('[CdpClient]   [${i + 1}] ${tabs[i].url}');
    }
    appLogger.i('[CdpClient] ══════════════════════════════════════════');

    return tabs;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (_channel == null) {
      throw CdpConnectionException('Not connected. Call connect() first.');
    }

    final id = ++_nextId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    appLogger.t('[CdpClient] → $method (id=$id)');
    _channel!.sink.add(jsonEncode({'id': id, 'method': method, 'params': params}));

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pending.remove(id);
        throw CdpTimeoutException('No response for $method after 10s');
      },
    );
  }

  void _handleMessage(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    final id = msg['id'] as int?;

    if (id != null) {
      // Response to a command we sent
      final completer = _pending.remove(id);
      if (completer == null) return;

      if (msg.containsKey('error')) {
        final errMsg =
            (msg['error'] as Map<String, dynamic>)['message'] as String;
        appLogger.w('[CdpClient] ← error (id=$id): $errMsg');
        completer.completeError(CdpException(errMsg));
      } else {
        appLogger.t('[CdpClient] ← ok (id=$id)');
        completer.complete((msg['result'] as Map<String, dynamic>?) ?? {});
      }
    } else {
      // Push event from Chrome (no id)
      final method = msg['method'] as String?;
      if (method != null && !_eventController.isClosed) {
        final params =
            (msg['params'] as Map<String, dynamic>?) ?? {};
        appLogger.t('[CdpClient] event: $method');
        _eventController.add(CdpEvent(method: method, params: params));
      }
    }
  }

  void _handleError(Object error) {
    appLogger.e('[CdpClient] WebSocket error: $error');
    for (final c in _pending.values) {
      c.completeError(CdpConnectionException('WebSocket error: $error'));
    }
    _pending.clear();
  }

  void _handleDone() {
    appLogger.w('[CdpClient] WebSocket closed');
    for (final c in _pending.values) {
      c.completeError(CdpConnectionException('WebSocket closed unexpectedly'));
    }
    _pending.clear();
    _channel = null;
  }

  Future<void> disconnect() async {
    appLogger.d('[CdpClient] Disconnecting...');
    await _sub?.cancel();
    await _channel?.sink.close();
    _sub = null;
    _channel = null;
    _pending.clear();
    appLogger.d('[CdpClient] Disconnected');
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
