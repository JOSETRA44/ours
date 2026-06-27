import 'dart:async';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/workspace_repository.dart';
import 'cdp_client.dart';

/// Automatically mirrors the state of open Chrome tabs into the active session.
///
/// Strategy: listen to CDP push events (Target.targetCreated/Destroyed/Changed)
/// and debounce writes into the DB. No polling — pure event-driven.
///
/// Debounce window: 1.5s. A burst of tab-navigation events (address bar typing,
/// redirects) collapses into a single DB write after the browser settles.
class TabMirrorService {
  final CdpClient _cdp;
  final WorkspaceRepository _repository;

  StreamSubscription<dynamic>? _eventSub;
  Timer? _debounce;
  int? _mirroredWorkspaceId;

  static const _debounceDelay = Duration(milliseconds: 1500);

  TabMirrorService({
    required CdpClient cdp,
    required WorkspaceRepository repository,
  })  : _cdp = cdp,
        _repository = repository;

  bool get isActive => _mirroredWorkspaceId != null;

  /// Starts mirroring tabs into [workspaceId]'s active session.
  ///
  /// Immediately snapshots the current state, then keeps it updated
  /// via CDP events until [stop] is called.
  Future<void> start(int workspaceId) async {
    if (isActive) await stop();

    _mirroredWorkspaceId = workspaceId;
    appLogger.i('[TabMirror] Starting mirror for workspace $workspaceId');

    // Enable Chrome to emit target events
    await _cdp.enableTargetDiscovery();

    // Snapshot current state immediately
    await _syncNow(workspaceId);

    // Subscribe to push events
    _eventSub = _cdp.events.listen((event) => _onCdpEvent(event.method, event.params));

    appLogger.i('[TabMirror] Listening to CDP events');
  }

  /// Stops the mirror. Does NOT modify the session — call from deactivation flow.
  Future<void> stop() async {
    if (!isActive) return;

    appLogger.i('[TabMirror] Stopping mirror for workspace $_mirroredWorkspaceId');
    _debounce?.cancel();
    _debounce = null;
    await _eventSub?.cancel();
    _eventSub = null;
    _mirroredWorkspaceId = null;
  }

  void _onCdpEvent(String method, Map<String, dynamic> params) {
    switch (method) {
      case 'Target.targetCreated':
        final info = params['targetInfo'] as Map<String, dynamic>?;
        if (info?['type'] == 'page') {
          final url = info?['url'] as String? ?? '';
          appLogger.d('[TabMirror] targetCreated: $url');
          _scheduleSyncDebounced();
        }

      case 'Target.targetDestroyed':
        // targetId is directly in params (no targetInfo wrapper)
        final targetId = params['targetId'] as String?;
        appLogger.d('[TabMirror] targetDestroyed: $targetId');
        _scheduleSyncDebounced();

      case 'Target.targetInfoChanged':
        final info = params['targetInfo'] as Map<String, dynamic>?;
        if (info?['type'] == 'page') {
          final url = info?['url'] as String? ?? '';
          // Skip blank / chrome-internal URLs during navigation
          if (url.startsWith('http')) {
            appLogger.d('[TabMirror] targetInfoChanged: $url');
            _scheduleSyncDebounced();
          }
        }
    }
  }

  /// Schedules a sync, resetting the debounce window on each event.
  void _scheduleSyncDebounced() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      final id = _mirroredWorkspaceId;
      if (id != null) _syncNow(id);
    });
  }

  /// Full sync: queries live CDP targets and writes to DB atomically.
  Future<void> _syncNow(int workspaceId) async {
    try {
      final tabs = await _cdp.captureOpenTabs();
      final tabIds = tabs.map((t) => t.targetId).toList();
      final urls = tabs.map((t) => t.url).toList();

      appLogger.i('[TabMirror] Sync → workspace=$workspaceId  '
          'liveUrls=$urls');

      final session = await _repository.getActiveSession();
      if (session == null || session.workspaceId != workspaceId) {
        appLogger.w('[TabMirror] Session not found or workspace mismatch — skipping write');
        return;
      }

      await _repository.saveActiveSession(
        session.copyWith(cdpTabIds: tabIds),
      );

      appLogger.d('[TabMirror] Session updated with ${tabIds.length} live tab(s)');
    } catch (e) {
      appLogger.w('[TabMirror] syncNow failed (ignored): $e');
    }
  }

  void dispose() {
    _debounce?.cancel();
    _eventSub?.cancel();
  }
}
