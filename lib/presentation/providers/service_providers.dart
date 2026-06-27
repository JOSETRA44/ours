import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/cdp/cdp_client.dart';
import '../../services/cdp/chrome_launcher.dart';
import '../../services/process/process_manager.dart';
import '../../services/workspace/workspace_activation_service.dart';
import 'repository_providers.dart';

final cdpClientProvider = Provider<CdpClient>((ref) {
  final client = CdpClient();
  ref.onDispose(client.disconnect);
  return client;
});

final chromeLauncherProvider = Provider<ChromeLauncher>((ref) {
  return ChromeLauncher();
});

final processManagerProvider = Provider<ProcessManager>((ref) {
  return ProcessManager();
});

final workspaceActivationServiceProvider =
    Provider<WorkspaceActivationService>((ref) {
  return WorkspaceActivationService(
    cdp: ref.watch(cdpClientProvider),
    chromeLauncher: ref.watch(chromeLauncherProvider),
    processManager: ref.watch(processManagerProvider),
    repository: ref.watch(workspaceRepositoryProvider),
  );
});
