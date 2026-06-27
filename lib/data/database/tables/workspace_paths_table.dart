import 'package:drift/drift.dart';
import 'workspaces_table.dart';

@DataClassName('WorkspacePathRow')
class WorkspacePaths extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId => integer().references(Workspaces, #id)();
  TextColumn get path => text()();
  // 'file' | 'folder'
  TextColumn get pathType => text().withDefault(const Constant('folder'))();
  TextColumn get label => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
