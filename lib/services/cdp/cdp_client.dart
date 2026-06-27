import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/cdp_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/models/cdp_tab.dart';

class CdpClient {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 0;

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
    appLogger.d('[CdpClient] Browser version: ${json['Browser']}');

    final wsUrl = json['webSocketDebuggerUrl'] as String?;
    if (wsUrl == null) {
      throw CdpConnectionException(
          'webSocketDebuggerUrl missing in /json/version — '
          'Chrome may not have started with --remote-debugging-port');
    }

    appLogger.d('[CdpClient] WebSocket URL: $wsUrl');
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    await _channel!.ready;

    _sub = _channel!.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
    );

    appLogger.i('[CdpClient] Connected ✓');
  }

  /// Opens a new tab and returns its CDP targetId.
  Future<String> createTab(String url) async {
    appLogger.d('[CdpClient] Creating tab → $url');
    final result = await _send('Target.createTarget', {'url': url});
    final targetId = result['targetId'] as String;
    appLogger.d('[CdpClient] Tab created → targetId=$targetId');
    return targetId;
  }

  /// Closes a tab by its CDP targetId. Silently ignores if already closed.
  Future<void> closeTab(String targetId) async {
    appLogger.d('[CdpClient] Closing tab → $targetId');
    try {
      await _send('Target.closeTarget', {'targetId': targetId});
      appLogger.d('[CdpClient] Tab closed ✓');
    } catch (e) {
      appLogger.d('[CdpClient] closeTab ignored (tab already gone): $e');
    }
  }

  /// Returns raw target info for all attached targets.
  Future<List<Map<String, dynamic>>> listTargets() async {
    final result = await _send('Target.getTargets', {});
    return List<Map<String, dynamic>>.from(
        result['targetInfos'] as List? ?? []);
  }

  /// Captures all open browser-page tabs (filters out DevTools, extensions, etc.).
  /// This is the snapshot method for importing the current Chrome state.
  Future<List<CdpTab>> captureOpenTabs() async {
    appLogger.i('[CdpClient] Capturing open tabs...');

    final targets = await listTargets();
    appLogger.d('[CdpClient] Total targets found: ${targets.length}');

    final tabs = targets
        .where((t) => t['type'] == 'page')
        .map((t) => CdpTab(
              targetId: t['targetId'] as String? ?? '',
              url: t['url'] as String? ?? '',
              title: t['title'] as String? ?? '',
            ))
        .where((tab) => tab.isNavigable)
        .toList();

    // ── Console snapshot log (requested for connectivity validation) ──
    appLogger.i('[CdpClient] ══════════════════════════════════════════');
    appLogger.i('[CdpClient] CAPTURED TABS SNAPSHOT (${tabs.length} tabs)');
    for (var i = 0; i < tabs.length; i++) {
      appLogger.i('[CdpClient]   [${i + 1}] ${tabs[i].url}');
      appLogger.d('[CdpClient]        title="${tabs[i].title}" targetId=${tabs[i].targetId}');
    }
    appLogger.i('[CdpClient] ══════════════════════════════════════════');

    return tabs;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (_channel == null) {
      throw CdpConnectionException(
          'Not connected to CDP. Call connect() first.');
    }

    final id = ++_nextId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    final payload = jsonEncode({'id': id, 'method': method, 'params': params});
    appLogger.t('[CdpClient] → $method (id=$id)');
    _channel!.sink.add(payload);

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
    if (id == null) {
      // CDP event (Target.targetCreated, etc.) — ignore
      return;
    }

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
      c.completeError(
          CdpConnectionException('WebSocket closed unexpectedly'));
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
}
