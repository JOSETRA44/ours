import 'dart:convert';
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/active_sessions_table.dart';
import '../../../domain/models/active_session.dart';

part 'session_dao.g.dart';

@DriftAccessor(tables: [ActiveSessions])
class SessionDao extends DatabaseAccessor<AppDatabase>
    with _$SessionDaoMixin {
  SessionDao(super.db);

  Stream<ActiveSession?> watchSession() {
    return select(activeSessions)
        .watchSingleOrNull()
        .map((row) => row == null ? null : _rowToSession(row));
  }

  Future<ActiveSession?> getSession() async {
    final row = await select(activeSessions).getSingleOrNull();
    return row == null ? null : _rowToSession(row);
  }

  Future<void> upsertSession(ActiveSession session) async {
    await into(activeSessions).insertOnConflictUpdate(
      ActiveSessionsCompanion(
        workspaceId: Value(session.workspaceId),
        activatedAt: Value(session.activatedAt),
        cdpTabIds: Value(jsonEncode(session.cdpTabIds)),
        processIds: Value(jsonEncode(session.processIds)),
        chromePid: Value(session.chromePid),
      ),
    );
  }

  Future<void> clearSession() {
    return delete(activeSessions).go();
  }

  ActiveSession _rowToSession(ActiveSessionRow row) {
    return ActiveSession(
      workspaceId: row.workspaceId,
      activatedAt: row.activatedAt,
      cdpTabIds: List<String>.from(jsonDecode(row.cdpTabIds) as List),
      processIds: List<int>.from(jsonDecode(row.processIds) as List),
      chromePid: row.chromePid,
    );
  }
}
