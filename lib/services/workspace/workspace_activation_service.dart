import 'dart:io';
import '../../core/errors/chrome_exception.dart';
import '../../data/repositories/workspace_repository.dart';
import '../../domain/models/active_session.dart';
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
    if (_transitioning) throw StateError('A workspace transition is already in progress.');
    _transitioning = true;
    try {
      // Deactivate current session first
      final existing = await _repository.getActiveSession();
      if (existing != null) {
        await _deactivateSession(existing);
      }

      // Ensure Chrome is running with CDP
      int? chromePid;
      if (!await _chromeLauncher.isCdpAvailable()) {
        // Check if Chrome is already running WITHOUT debug port
        final isRunning = await _isChromeRunning();
        if (isRunning) throw const ChromeNotDebuggableException();

        final chromePath = await _chromeLauncher.detectChromePath();
        if (chromePath == null) throw const ChromeNotFoundException();

        chromePid = await _chromeLauncher.launchChrome(chromePath);
        await _chromeLauncher.waitForCdp();
      }

      await _cdp.connect();

      // Open browser tabs
      final tabIds = <String>[];
      for (final u in workspace.urls) {
        final id = await _cdp.createTab(u.url);
        tabIds.add(id);
      }

      // Open folders and files
      for (final p in workspace.paths) {
        await _processManager.openPath(p.path);
      }

      // Spawn terminal commands
      final pids = <int>[];
      for (final cmd in workspace.commands) {
        final pid = await _processManager.spawn(
          cmd.command,
          workingDirectory: cmd.workingDirectory,
        );
        pids.add(pid);
      }

      await _repository.saveActiveSession(ActiveSession(
        workspaceId: workspace.id,
        activatedAt: DateTime.now(),
        cdpTabIds: tabIds,
        processIds: pids,
        chromePid: chromePid,
      ));
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
      await _deactivateSession(session);
    } finally {
      _transitioning = false;
    }
  }

  Future<void> _deactivateSession(ActiveSession session) async {
    // Close CDP tabs (best-effort)
    try {
      if (!_cdp.isConnected) await _cdp.connect();
      for (final tabId in session.cdpTabIds) {
        await _cdp.closeTab(tabId);
      }
      await _cdp.disconnect();
    } catch (_) {
      // Chrome may not be running anymore
    }

    // Kill spawned processes
    await _processManager.killAll(session.processIds);

    // Kill Chrome if we launched it
    if (session.chromePid != null) {
      await _processManager.kill(session.chromePid!);
    }

    await _repository.clearActiveSession();
  }

  /// Recover session state after app restart.
  Future<void> recoverSession() async {
    final session = await _repository.getActiveSession();
    if (session == null) return;

    if (await _chromeLauncher.isCdpAvailable()) {
      try {
        await _cdp.connect();
        final targets = await _cdp.listTargets();
        final liveTabIds = targets
            .map((t) => t['targetId'] as String)
            .toSet();
        final validTabIds = session.cdpTabIds
            .where(liveTabIds.contains)
            .toList();

        final alivePids = <int>[];
        for (final pid in session.processIds) {
          if (await _processManager.isAlive(pid)) {
            alivePids.add(pid);
          }
        }

        await _repository.saveActiveSession(session.copyWith(
          cdpTabIds: validTabIds,
          processIds: alivePids,
        ));
        await _cdp.disconnect();
      } catch (_) {
        // Silently ignore — session will remain as-is
      }
    } else {
      // Chrome not available — clear tab IDs, keep PIDs
      await _repository.saveActiveSession(
          session.copyWith(cdpTabIds: []));
    }
  }

  Future<bool> _isChromeRunning() async {
    try {
      final result = await Process.run(
        'tasklist',
        ['/FI', 'IMAGENAME eq chrome.exe', '/FO', 'CSV', '/NH'],
      );
      return (result.stdout as String).toLowerCase().contains('chrome.exe');
    } catch (_) {
      return false;
    }
  }
}
