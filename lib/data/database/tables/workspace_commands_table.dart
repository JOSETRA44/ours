import 'package:drift/drift.dart';
import 'workspaces_table.dart';

@DataClassName('WorkspaceCommandRow')
class WorkspaceCommands extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId => integer().references(Workspaces, #id)();
  TextColumn get command => text()();
  TextColumn get workingDirectory => text().nullable()();
  TextColumn get label => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
