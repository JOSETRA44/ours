import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/workspace.dart';
import 'repository_providers.dart';
import 'service_providers.dart';
import 'workspace_providers.dart';

class WorkspaceActivationNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> activate(Workspace workspace) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(workspaceActivationServiceProvider)
          .activateWorkspace(workspace),
    );
  }

  Future<void> deactivate(int workspaceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(workspaceActivationServiceProvider)
          .deactivateWorkspace(workspaceId),
    );
  }

  Future<void> toggle(int workspaceId) async {
    final session =
        ref.read(activeSessionProvider).valueOrNull;
    if (session?.workspaceId == workspaceId) {
      await deactivate(workspaceId);
    } else {
      final ws = await ref
          .read(workspaceRepositoryProvider)
          .getWorkspaceWithItems(workspaceId);
      if (ws != null) await activate(ws);
    }
  }
}

final workspaceActivationNotifierProvider =
    AsyncNotifierProvider<WorkspaceActivationNotifier, void>(
  WorkspaceActivationNotifier.new,
);
