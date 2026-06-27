import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';

class ChromeLauncher {
  final int port;

  ChromeLauncher({this.port = AppConstants.cdpPort});

  Future<bool> isCdpAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:$port/json/version'))
          .timeout(const Duration(seconds: 2));
      final available = response.statusCode == 200;
      appLogger.d('[ChromeLauncher] CDP probe → ${available ? "AVAILABLE" : "NOT available"} (port $port)');
      return available;
    } catch (e) {
      appLogger.d('[ChromeLauncher] CDP probe → not available: $e');
      return false;
    }
  }

  Future<String?> detectChromePath() async {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final candidates = [
      ...AppConstants.chromeCandidatePaths,
      p.join(localAppData, 'Google', 'Chrome', 'Application', 'chrome.exe'),
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        appLogger.i('[ChromeLauncher] Chrome found at: $candidate');
        return candidate;
      }
    }
    appLogger.w('[ChromeLauncher] Chrome not found in any candidate path');
    return null;
  }

  /// Launches an isolated Chrome instance with remote debugging enabled.
  ///
  /// Uses a stable per-app user-data-dir in AppDocuments so it persists
  /// across sessions and never conflicts with the user's normal Chrome profile.
  Future<int> launchChrome(String chromePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final userDataDir = p.join(
      docsDir.path,
      'workspace_context_manager',
      'chrome_debug_profile',
    );

    await Directory(userDataDir).create(recursive: true);

    appLogger.i('[ChromeLauncher] Launching isolated Chrome...');
    appLogger.d('[ChromeLauncher]   path:         $chromePath');
    appLogger.d('[ChromeLauncher]   debug port:   $port');
    appLogger.d('[ChromeLauncher]   user-data-dir: $userDataDir');

    // ProcessStartMode.detached lets Chrome survive after this process, but
    // the returned PID is the launcher stub — Chrome spawns its own child tree.
    final process = await Process.start(
      chromePath,
      [
        '--remote-debugging-port=$port',
        '--user-data-dir=$userDataDir',
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-extensions',
        '--disable-sync',
      ],
      mode: ProcessStartMode.detached,
    );

    appLogger.i('[ChromeLauncher] Chrome launcher PID: ${process.pid}');
    return process.pid;
  }

  /// Polls CDP until available or [timeout] expires.
  Future<void> waitForCdp({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    appLogger.i('[ChromeLauncher] Waiting for CDP on port $port...');
    final deadline = DateTime.now().add(timeout);
    var attempt = 0;
    while (DateTime.now().isBefore(deadline)) {
      attempt++;
      if (await isCdpAvailable()) {
        appLogger.i('[ChromeLauncher] CDP ready after $attempt attempts');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }
    throw TimeoutException(
      '[ChromeLauncher] Chrome CDP not available after ${timeout.inSeconds}s on port $port',
      timeout,
    );
  }
}
