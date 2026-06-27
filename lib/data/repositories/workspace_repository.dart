import '../../data/database/app_database.dart';
import '../../domain/models/workspace.dart';
import '../../domain/models/workspace_url.dart';
import '../../domain/models/workspace_path.dart';
import '../../domain/models/workspace_command.dart';
import '../../domain/models/active_session.dart';

abstract interface class WorkspaceRepository {
  Stream<List<WorkspaceRow>> watchAllWorkspaces();
  Future<Workspace?> getWorkspaceWithItems(int id);
  Future<int> createWorkspace(WorkspacesCompanion data);
  Future<void> updateWorkspace(int id, WorkspacesCompanion data);
  Future<void> deleteWorkspace(int id);
  Future<void> saveWorkspaceItems({
    required int workspaceId,
    required List<WorkspaceUrl> urls,
    required List<WorkspacePath> paths,
    required List<WorkspaceCommand> commands,
  });

  Stream<ActiveSession?> watchActiveSession();
  Future<ActiveSession?> getActiveSession();
  Future<void> saveActiveSession(ActiveSession session);
  Future<void> clearActiveSession();
}
