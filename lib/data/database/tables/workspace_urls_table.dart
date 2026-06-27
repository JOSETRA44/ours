import 'package:drift/drift.dart';
import 'workspaces_table.dart';

@DataClassName('WorkspaceUrlRow')
class WorkspaceUrls extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId => integer().references(Workspaces, #id)();
  TextColumn get url => text()();
  TextColumn get label => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
