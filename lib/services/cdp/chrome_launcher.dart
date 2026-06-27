import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';

class ChromeLauncher {
  final int port;

  ChromeLauncher({this.port = AppConstants.cdpPort});

  Future<bool> isCdpAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:$port/json/version'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String?> detectChromePath() async {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final candidates = [
      ...AppConstants.chromeCandidatePaths,
      p.join(localAppData, 'Google', 'Chrome', 'Application', 'chrome.exe'),
    ];
    for (final path in candidates) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  Future<int> launchChrome(String chromePath) async {
    final tmpDir = await getTemporaryDirectory();
    final userDataDir =
        p.join(tmpDir.path, 'workspace_context_manager', 'chrome_debug');

    await Directory(userDataDir).create(recursive: true);

    final process = await Process.start(
      chromePath,
      [
        '--remote-debugging-port=$port',
        '--user-data-dir=$userDataDir',
        '--no-first-run',
        '--no-default-browser-check',
      ],
      mode: ProcessStartMode.detached,
    );
    return process.pid;
  }

  Future<void> waitForCdp({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await isCdpAvailable()) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException(
        'Chrome CDP did not become available in time.', timeout);
  }
}
