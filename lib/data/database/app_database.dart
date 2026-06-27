import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/workspaces_table.dart';
import 'tables/workspace_urls_table.dart';
import 'tables/workspace_paths_table.dart';
import 'tables/workspace_commands_table.dart';
import 'tables/active_sessions_table.dart';
import 'daos/workspace_dao.dart';
import 'daos/session_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Workspaces,
    WorkspaceUrls,
    WorkspacePaths,
    WorkspaceCommands,
    ActiveSessions,
  ],
  daos: [WorkspaceDao, SessionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {},
      );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final dbDir =
          Directory(p.join(dir.path, 'workspace_context_manager'));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }
      final file = File(p.join(dbDir.path, 'db.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
