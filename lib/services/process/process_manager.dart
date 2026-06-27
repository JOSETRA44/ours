import 'dart:io';

class ProcessManager {
  // Tracks processes we spawned in this session (lost on app restart)
  final _tracked = <int, Process>{};

  /// Spawns a command in a visible terminal window. Returns the PID.
  Future<int> spawn(String command, {String? workingDirectory}) async {
    // On Windows, open a new cmd window that keeps open after the command
    final process = await Process.start(
      'cmd',
      ['/c', 'start', '', 'cmd', '/k', command],
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
    _tracked[process.pid] = process;
    return process.pid;
  }

  /// Opens a file or folder with its default OS handler.
  Future<void> openPath(String path) async {
    await Process.run('explorer', [path]);
  }

  /// Kills a process by PID. Handles both tracked and orphaned (from DB) PIDs.
  Future<bool> kill(int pid) async {
    final tracked = _tracked.remove(pid);
    if (tracked != null) {
      return tracked.kill(ProcessSignal.sigterm);
    }
    return _forceKill(pid);
  }

  Future<void> killAll(List<int> pids) async {
    await Future.wait(pids.map(kill));
  }

  Future<bool> isAlive(int pid) async {
    try {
      final result = await Process.run(
        'tasklist',
        ['/FI', 'PID eq $pid', '/FO', 'CSV', '/NH'],
      );
      return (result.stdout as String).contains('"$pid"') ||
          (result.stdout as String).contains(',$pid,');
    } catch (_) {
      return false;
    }
  }

  Future<bool> _forceKill(int pid) async {
    try {
      final r = await Process.run('taskkill', ['/F', '/PID', '$pid']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
