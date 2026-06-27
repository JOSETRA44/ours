import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/workspaces_table.dart';
import '../tables/workspace_urls_table.dart';
import '../tables/workspace_paths_table.dart';
import '../tables/workspace_commands_table.dart';
import '../../../domain/models/workspace.dart';
import '../../../domain/models/workspace_url.dart';
import '../../../domain/models/workspace_path.dart';
import '../../../domain/models/workspace_command.dart';

part 'workspace_dao.g.dart';

@DriftAccessor(tables: [
  Workspaces,
  WorkspaceUrls,
  WorkspacePaths,
  WorkspaceCommands,
])
class WorkspaceDao extends DatabaseAccessor<AppDatabase>
    with _$WorkspaceDaoMixin {
  WorkspaceDao(super.db);

  Stream<List<WorkspaceRow>> watchAll() {
    return (select(workspaces)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<WorkspaceRow?> getById(int id) {
    return (select(workspaces)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Workspace?> getWithItems(int id) async {
    final ws = await getById(id);
    if (ws == null) return null;

    final urls = await (select(workspaceUrls)
          ..where((t) => t.workspaceId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();

    final paths = await (select(workspacePaths)
          ..where((t) => t.workspaceId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();

    final commands = await (select(workspaceCommands)
          ..where((t) => t.workspaceId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();

    return Workspace(
      id: ws.id,
      name: ws.name,
      description: ws.description,
      colorValue: ws.colorValue,
      iconName: ws.iconName,
      sortOrder: ws.sortOrder,
      urls: urls
          .map((u) => WorkspaceUrl(
                id: u.id,
                workspaceId: u.workspaceId,
                url: u.url,
                label: u.label,
                sortOrder: u.sortOrder,
              ))
          .toList(),
      paths: paths
          .map((p) => WorkspacePath(
                id: p.id,
                workspaceId: p.workspaceId,
                path: p.path,
                pathType: p.pathType,
                label: p.label,
                sortOrder: p.sortOrder,
              ))
          .toList(),
      commands: commands
          .map((c) => WorkspaceCommand(
                id: c.id,
                workspaceId: c.workspaceId,
                command: c.command,
                workingDirectory: c.workingDirectory,
                label: c.label,
                sortOrder: c.sortOrder,
              ))
          .toList(),
    );
  }

  Future<int> insertWorkspace(WorkspacesCompanion data) {
    return into(workspaces).insert(data);
  }

  Future<void> updateWorkspace(int id, WorkspacesCompanion data) {
    return (update(workspaces)..where((t) => t.id.equals(id))).write(data);
  }

  Future<void> deleteWorkspace(int id) async {
    await (delete(workspaceUrls)
          ..where((t) => t.workspaceId.equals(id)))
        .go();
    await (delete(workspacePaths)
          ..where((t) => t.workspaceId.equals(id)))
        .go();
    await (delete(workspaceCommands)
          ..where((t) => t.workspaceId.equals(id)))
        .go();
    await (delete(workspaces)..where((t) => t.id.equals(id))).go();
  }

  Future<void> saveItems({
    required int workspaceId,
    required List<WorkspaceUrl> urls,
    required List<WorkspacePath> paths,
    required List<WorkspaceCommand> commands,
  }) async {
    await db.transaction(() async {
      await (delete(workspaceUrls)
            ..where((t) => t.workspaceId.equals(workspaceId)))
          .go();
      await (delete(workspacePaths)
            ..where((t) => t.workspaceId.equals(workspaceId)))
          .go();
      await (delete(workspaceCommands)
            ..where((t) => t.workspaceId.equals(workspaceId)))
          .go();

      for (var i = 0; i < urls.length; i++) {
        await into(workspaceUrls).insert(WorkspaceUrlsCompanion.insert(
          workspaceId: urls[i].workspaceId,
          url: urls[i].url,
          label: Value(urls[i].label),
          sortOrder: Value(i),
        ));
      }

      for (var i = 0; i < paths.length; i++) {
        await into(workspacePaths).insert(WorkspacePathsCompanion.insert(
          workspaceId: paths[i].workspaceId,
          path: paths[i].path,
          pathType: Value(paths[i].pathType),
          label: Value(paths[i].label),
          sortOrder: Value(i),
        ));
      }

      for (var i = 0; i < commands.length; i++) {
        await into(workspaceCommands)
            .insert(WorkspaceCommandsCompanion.insert(
          workspaceId: commands[i].workspaceId,
          command: commands[i].command,
          workingDirectory: Value(commands[i].workingDirectory),
          label: Value(commands[i].label),
          sortOrder: Value(i),
        ));
      }
    });
  }
}
