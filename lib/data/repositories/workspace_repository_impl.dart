import '../../data/database/app_database.dart';
import '../../domain/models/workspace.dart';
import '../../domain/models/workspace_url.dart';
import '../../domain/models/workspace_path.dart';
import '../../domain/models/workspace_command.dart';
import '../../domain/models/active_session.dart';
import 'workspace_repository.dart';

class WorkspaceRepositoryImpl implements WorkspaceRepository {
  final AppDatabase _db;

  WorkspaceRepositoryImpl(this._db);

  @override
  Stream<List<WorkspaceRow>> watchAllWorkspaces() {
    return _db.workspaceDao.watchAll();
  }

  @override
  Future<Workspace?> getWorkspaceWithItems(int id) {
    return _db.workspaceDao.getWithItems(id);
  }

  @override
  Future<int> createWorkspace(WorkspacesCompanion data) {
    return _db.workspaceDao.insertWorkspace(data);
  }

  @override
  Future<void> updateWorkspace(int id, WorkspacesCompanion data) {
    return _db.workspaceDao.updateWorkspace(id, data);
  }

  @override
  Future<void> deleteWorkspace(int id) {
    return _db.workspaceDao.deleteWorkspace(id);
  }

  @override
  Future<void> saveWorkspaceItems({
    required int workspaceId,
    required List<WorkspaceUrl> urls,
    required List<WorkspacePath> paths,
    required List<WorkspaceCommand> commands,
  }) {
    return _db.workspaceDao.saveItems(
      workspaceId: workspaceId,
      urls: urls,
      paths: paths,
      commands: commands,
    );
  }

  @override
  Stream<ActiveSession?> watchActiveSession() {
    return _db.sessionDao.watchSession();
  }

  @override
  Future<ActiveSession?> getActiveSession() {
    return _db.sessionDao.getSession();
  }

  @override
  Future<void> saveActiveSession(ActiveSession session) {
    return _db.sessionDao.upsertSession(session);
  }

  @override
  Future<void> clearActiveSession() {
    return _db.sessionDao.clearSession();
  }
}
