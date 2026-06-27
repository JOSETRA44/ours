import '../../core/errors/chrome_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/workspace_repository.dart';
import '../../domain/models/active_session.dart';
import '../../domain/models/cdp_tab.dart';
import '../../domain/models/workspace.dart';
import '../cdp/cdp_client.dart';
import '../cdp/chrome_launcher.dart';
import '../process/process_manager.dart';

class WorkspaceActivationService {
  final CdpClient _cdp;
  final ChromeLauncher _chromeLauncher;
  final ProcessManager _processManager;
  final WorkspaceRepository _repository;

  bool _transitioning = false;

  WorkspaceActivationService({
    required CdpClient cdp,
    required ChromeLauncher chromeLauncher,
    required ProcessManager processManager,
    required WorkspaceRepository repository,
  })  : _cdp = cdp,
        _chromeLauncher = chromeLauncher,
        _processManager = processManager,
        _repository = repository;

  Future<void> activateWorkspace(Workspace workspace) async {
    if (_transitioning) {
      throw StateError('A workspace transition is already in progress.');
    }
    _transitioning = true;

    try {
      appLogger.i(
          '[ActivationService] Activating workspace "${workspace.name}" (id=${workspace.id})');

      // Deactivate current session first
      final existing = await _repository.getActiveSession();
      if (existing != null) {
        appLogger.i('[ActivationService] Deactivating previous session (workspaceId=${existing.workspaceId})');
        await _deactivateSession(existing);
      }

      // ── Ensure an isolated debug Chrome is running ─────────────────────
      // KEY FIX: we always launch our own isolated Chrome via --user-data-dir.
      // We do NOT check whether the user's normal Chrome is running — the
      // separate user-data-dir guarantees a completely independent process tree.
      int? chromePid;
      if (!await _chromeLauncher.isCdpAvailable()) {
        final chromePath = await _chromeLauncher.detectChromePath();
        if (chromePath == null) throw const ChromeNotFoundException();

        chromePid = await _chromeLauncher.launchChrome(chromePath);
        await _chromeLauncher.waitForCdp();
      } else {
        appLogger.i('[ActivationService] CDP already available — reusing existing session');
      }

      await _cdp.connect();

      // Open browser tabs
      final tabIds = <String>[];
      appLogger.i('[ActivationService] Opening ${workspace.urls.length} browser tab(s)...');
      for (final u in workspace.urls) {
        final id = await _cdp.createTab(u.url);
        tabIds.add(id);
      }
      appLogger.i('[ActivationService] Tabs opened → targetIds: $tabIds');

      // Open folders and files
      appLogger.i('[ActivationService] Opening ${workspace.paths.length} path(s)...');
      for (final p in workspace.paths) {
        await _processManager.openPath(p.path);
        appLogger.d('[ActivationService]   opened: ${p.path}');
      }

      // Spawn terminal commands
      final pids = <int>[];
      appLogger.i('[ActivationService] Spawning ${workspace.commands.length} command(s)...');
      for (final cmd in workspace.commands) {
        final pid = await _processManager.spawn(
          cmd.command,
          workingDirectory: cmd.workingDirectory,
        );
        pids.add(pid);
        appLogger.d('[ActivationService]   spawned: "${cmd.command}" → PID $pid');
      }

      final session = ActiveSession(
        workspaceId: workspace.id,
        activatedAt: DateTime.now(),
        cdpTabIds: tabIds,
        processIds: pids,
        chromePid: chromePid,
      );
      await _repository.saveActiveSession(session);

      appLogger.i('[ActivationService] ✓ Workspace "${workspace.name}" active');
      appLogger.i('[ActivationService]   cdpTabIds:  $tabIds');
      appLogger.i('[ActivationService]   processIds: $pids');
    } finally {
      _transitioning = false;
    }
  }

  Future<void> deactivateWorkspace(int workspaceId) async {
    if (_transitioning) return;
    final session = await _repository.getActiveSession();
    if (session == null || session.workspaceId != workspaceId) return;

    _transitioning = true;
    try {
      appLogger.i('[ActivationService] Deactivating workspace (id=$workspaceId)');
      await _deactivateSession(session);
    } finally {
      _transitioning = false;
    }
  }

  /// Captures all currently open navigable tabs from the debug Chrome session.
  /// Ensures CDP is available (launching an isolated Chrome if needed) before
  /// attempting the snapshot.
  ///
  /// Returns empty list if Chrome cannot be reached.
  Future<List<CdpTab>> captureCurrentBrowserTabs() async {
    appLogger.i('[ActivationService] captureCurrentBrowserTabs() called');

    try {
      if (!await _chromeLauncher.isCdpAvailable()) {
        appLogger.i('[ActivationService] CDP not available — launching debug Chrome...');
        final chromePath = await _chromeLauncher.detectChromePath();
        if (chromePath == null) throw const ChromeNotFoundException();

        await _chromeLauncher.launchChrome(chromePath);
        await _chromeLauncher.waitForCdp();
      }

      if (!_cdp.isConnected) await _cdp.connect();

      final tabs = await _cdp.captureOpenTabs();

      // ── Snapshot log (URLs array) ──
      final urlArray = tabs.map((t) => t.url).toList();
      appLogger.i('[ActivationService] SNAPSHOT URLs: $urlArray');

      return tabs;
    } catch (e, stack) {
      appLogger.e('[ActivationService] captureCurrentBrowserTabs failed', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Reconnects after app restart and validates the stored session against
  /// what's actually alive (CDP targets + OS processes).
  Future<void> recoverSession() async {
    final session = await _repository.getActiveSession();
    if (session == null) {
      appLogger.d('[ActivationService] No previous session to recover');
      return;
    }

    appLogger.i('[ActivationService] Recovering session for workspaceId=${session.workspaceId}');

    if (await _chromeLauncher.isCdpAvailable()) {
      try {
        await _cdp.connect();

        final targets = await _cdp.listTargets();
        final liveTabIds = targets.map((t) => t['targetId'] as String).toSet();
        final validTabIds =
            session.cdpTabIds.where(liveTabIds.contains).toList();

        appLogger.i('[ActivationService] Session recovery: '
            '${session.cdpTabIds.length} stored tabs → ${ validTabIds.length} still alive');

        final alivePids = <int>[];
        for (final pid in session.processIds) {
          if (await _processManager.isAlive(pid)) {
            alivePids.add(pid);
          }
        }

        await _repository.saveActiveSession(
            session.copyWith(cdpTabIds: validTabIds, processIds: alivePids));
        await _cdp.disconnect();
      } catch (e) {
        appLogger.w('[ActivationService] Session recovery failed: $e');
      }
    } else {
      appLogger.w('[ActivationService] Chrome not reachable on restart — clearing tab IDs');
      await _repository.saveActiveSession(session.copyWith(cdpTabIds: []));
    }
  }

  Future<void> _deactivateSession(ActiveSession session) async {
    // Close CDP tabs (best-effort — user may have closed them already)
    try {
      if (!_cdp.isConnected) await _cdp.connect();
      for (final tabId in session.cdpTabIds) {
        await _cdp.closeTab(tabId);
      }
      await _cdp.disconnect();
      appLogger.i('[ActivationService] CDP tabs closed');
    } catch (e) {
      appLogger.w('[ActivationService] CDP close failed (ignored): $e');
    }

    // Kill spawned processes
    if (session.processIds.isNotEmpty) {
      appLogger.i('[ActivationService] Killing processes: ${session.processIds}');
      await _processManager.killAll(session.processIds);
    }

    // Kill the isolated Chrome we launched (if we launched it)
    if (session.chromePid != null) {
      appLogger.i('[ActivationService] Killing Chrome (PID ${session.chromePid})');
      await _processManager.kill(session.chromePid!);
    }

    await _repository.clearActiveSession();
    appLogger.i('[ActivationService] Session cleared');
  }
}
