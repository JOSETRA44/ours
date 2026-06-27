import '../../core/errors/chrome_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/workspace_repository.dart';
import '../../domain/models/active_session.dart';
import '../../domain/models/cdp_tab.dart';
import '../../domain/models/workspace.dart';
import '../../domain/models/workspace_url.dart';
import '../cdp/cdp_client.dart';
import '../cdp/chrome_launcher.dart';
import '../cdp/tab_mirror_service.dart';
import '../process/process_manager.dart';

class WorkspaceActivationService {
  final CdpClient _cdp;
  final ChromeLauncher _chromeLauncher;
  final ProcessManager _processManager;
  final WorkspaceRepository _repository;
  final TabMirrorService _mirror;

  bool _transitioning = false;

  WorkspaceActivationService({
    required CdpClient cdp,
    required ChromeLauncher chromeLauncher,
    required ProcessManager processManager,
    required WorkspaceRepository repository,
    required TabMirrorService mirror,
  })  : _cdp = cdp,
        _chromeLauncher = chromeLauncher,
        _processManager = processManager,
        _repository = repository,
        _mirror = mirror;

  Future<void> activateWorkspace(Workspace workspace) async {
    if (_transitioning) {
      throw StateError('A workspace transition is already in progress.');
    }
    _transitioning = true;

    try {
      appLogger.i('[Activation] ▶ Activating "${workspace.name}" (id=${workspace.id})');

      // Stop any active mirror before switching
      await _mirror.stop();

      // Deactivate current session first (with auto-save of live URLs)
      final existing = await _repository.getActiveSession();
      if (existing != null) {
        await _deactivateSession(existing, autoSaveUrls: true);
      }

      // Ensure isolated debug Chrome is running
      int? chromePid;
      if (!await _chromeLauncher.isCdpAvailable()) {
        final chromePath = await _chromeLauncher.detectChromePath();
        if (chromePath == null) throw const ChromeNotFoundException();
        chromePid = await _chromeLauncher.launchChrome(chromePath);
        await _chromeLauncher.waitForCdp();
      }

      await _cdp.connect();

      // Open the workspace's configured URLs as tabs
      final tabIds = <String>[];
      appLogger.i('[Activation] Opening ${workspace.urls.length} URL(s)...');
      for (final u in workspace.urls) {
        final id = await _cdp.createTab(u.url);
        tabIds.add(id);
        appLogger.d('[Activation]   → ${u.url}  (targetId=$id)');
      }

      // Open folders and files
      for (final p in workspace.paths) {
        await _processManager.openPath(p.path);
        appLogger.d('[Activation]   📁 ${p.path}');
      }

      // Spawn terminal commands
      final pids = <int>[];
      for (final cmd in workspace.commands) {
        final pid = await _processManager.spawn(
          cmd.command,
          workingDirectory: cmd.workingDirectory,
        );
        pids.add(pid);
        appLogger.d('[Activation]   ⚡ "${cmd.command}" → PID $pid');
      }

      // Persist initial session state
      await _repository.saveActiveSession(ActiveSession(
        workspaceId: workspace.id,
        activatedAt: DateTime.now(),
        cdpTabIds: tabIds,
        processIds: pids,
        chromePid: chromePid,
      ));

      // Start the automatic mirror — from now on, every tab open/close
      // in Chrome is reflected in the DB without user interaction.
      await _mirror.start(workspace.id);

      appLogger.i('[Activation] ✓ Mirror active for "${workspace.name}"');
      appLogger.i('[Activation]   initial tabIds: $tabIds');
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
      appLogger.i('[Activation] ⏹ Deactivating workspace $workspaceId');
      await _mirror.stop();
      await _deactivateSession(session, autoSaveUrls: true);
    } finally {
      _transitioning = false;
    }
  }

  /// Captures current tabs from the debug Chrome session.
  /// Used by the manual "Capture from Chrome" fallback button in the UI.
  Future<List<CdpTab>> captureCurrentBrowserTabs() async {
    appLogger.i('[Activation] Manual capture triggered');
    try {
      if (!await _chromeLauncher.isCdpAvailable()) {
        final chromePath = await _chromeLauncher.detectChromePath();
        if (chromePath == null) throw const ChromeNotFoundException();
        await _chromeLauncher.launchChrome(chromePath);
        await _chromeLauncher.waitForCdp();
      }
      if (!_cdp.isConnected) await _cdp.connect();
      return _cdp.captureOpenTabs();
    } catch (e, s) {
      appLogger.e('[Activation] captureCurrentBrowserTabs failed', error: e, stackTrace: s);
      return [];
    }
  }

  Future<void> recoverSession() async {
    final session = await _repository.getActiveSession();
    if (session == null) {
      appLogger.d('[Activation] No session to recover');
      return;
    }

    appLogger.i('[Activation] Recovering session for workspace ${session.workspaceId}');

    if (await _chromeLauncher.isCdpAvailable()) {
      try {
        await _cdp.connect();

        final targets = await _cdp.listTargets();
        final liveIds = targets.map((t) => t['targetId'] as String).toSet();
        final validIds = session.cdpTabIds.where(liveIds.contains).toList();

        final alivePids = <int>[];
        for (final pid in session.processIds) {
          if (await _processManager.isAlive(pid)) alivePids.add(pid);
        }

        final recovered =
            session.copyWith(cdpTabIds: validIds, processIds: alivePids);
        await _repository.saveActiveSession(recovered);

        appLogger.i('[Activation] Recovery: ${validIds.length} live tabs, ${alivePids.length} live PIDs');

        // Restart the mirror for the recovered workspace
        await _mirror.start(session.workspaceId);
      } catch (e) {
        appLogger.w('[Activation] Recovery failed: $e');
        await _cdp.disconnect();
      }
    } else {
      appLogger.w('[Activation] Chrome not reachable on restart — clearing tab IDs');
      await _repository.saveActiveSession(session.copyWith(cdpTabIds: []));
    }
  }

  Future<void> _deactivateSession(
    ActiveSession session, {
    required bool autoSaveUrls,
  }) async {
    // AUTO-SAVE: Before closing tabs, snapshot live URLs and persist them
    // back into the workspace's URL list ("muscle memory").
    if (autoSaveUrls && session.cdpTabIds.isNotEmpty) {
      await _autoSaveWorkspaceUrls(session);
    }

    // Close CDP tabs (best-effort)
    try {
      if (!_cdp.isConnected) await _cdp.connect();
      for (final tabId in session.cdpTabIds) {
        await _cdp.closeTab(tabId);
      }
      await _cdp.disconnect();
    } catch (e) {
      appLogger.w('[Activation] CDP close skipped: $e');
    }

    // Kill spawned processes
    if (session.processIds.isNotEmpty) {
      await _processManager.killAll(session.processIds);
    }

    // Kill the isolated Chrome we launched
    if (session.chromePid != null) {
      await _processManager.kill(session.chromePid!);
    }

    await _repository.clearActiveSession();
    appLogger.i('[Activation] Session cleared');
  }

  /// Snapshots live Chrome tabs and writes them back as the workspace's URL list.
  /// This implements the "muscle memory" effect — the workspace evolves to match
  /// how the user actually used it during the session.
  Future<void> _autoSaveWorkspaceUrls(ActiveSession session) async {
    try {
      if (!_cdp.isConnected) await _cdp.connect();
      final liveTabs = await _cdp.captureOpenTabs();

      if (liveTabs.isEmpty) return;

      final urls = liveTabs
          .asMap()
          .entries
          .map((e) => WorkspaceUrl(
                id: 0,
                workspaceId: session.workspaceId,
                url: e.value.url,
                label: e.value.title.isNotEmpty ? e.value.title : null,
                sortOrder: e.key,
              ))
          .toList();

      // Fetch existing workspace items to preserve paths and commands
      final workspace =
          await _repository.getWorkspaceWithItems(session.workspaceId);
      if (workspace == null) return;

      await _repository.saveWorkspaceItems(
        workspaceId: session.workspaceId,
        urls: urls,
        paths: workspace.paths,
        commands: workspace.commands,
      );

      final urlArray = urls.map((u) => u.url).toList();
      appLogger.i('[Activation] AUTO-SAVE workspace ${session.workspaceId} URLs: $urlArray');
    } catch (e) {
      appLogger.w('[Activation] autoSaveWorkspaceUrls failed (ignored): $e');
    }
  }
}
