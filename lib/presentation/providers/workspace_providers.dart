import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../domain/models/active_session.dart';
import '../../domain/models/workspace.dart';
import 'repository_providers.dart';

final workspaceListProvider =
    StreamProvider<List<WorkspaceRow>>((ref) {
  return ref.watch(workspaceRepositoryProvider).watchAllWorkspaces();
});

final activeSessionProvider = StreamProvider<ActiveSession?>((ref) {
  return ref.watch(workspaceRepositoryProvider).watchActiveSession();
});

final selectedWorkspaceIdProvider =
    StateProvider<int?>((ref) => null);

final selectedWorkspaceDetailProvider =
    FutureProvider<Workspace?>((ref) async {
  final id = ref.watch(selectedWorkspaceIdProvider);
  if (id == null) return null;
  return ref.watch(workspaceRepositoryProvider).getWorkspaceWithItems(id);
});
