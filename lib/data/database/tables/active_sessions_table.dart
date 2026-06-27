import 'package:drift/drift.dart';
import 'workspaces_table.dart';

@DataClassName('ActiveSessionRow')
class ActiveSessions extends Table {
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id)();
  DateTimeColumn get activatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  // JSON-encoded List<String>
  TextColumn get cdpTabIds =>
      text().withDefault(const Constant('[]'))();
  // JSON-encoded List<int>
  TextColumn get processIds =>
      text().withDefault(const Constant('[]'))();
  // PID of Chrome if we launched it; null = Chrome was already running
  IntColumn get chromePid => integer().nullable()();

  @override
  Set<Column> get primaryKey => {workspaceId};
}
