class ActiveSession {
  final int workspaceId;
  final DateTime activatedAt;
  final List<String> cdpTabIds;
  final List<int> processIds;
  final int? chromePid;

  const ActiveSession({
    required this.workspaceId,
    required this.activatedAt,
    required this.cdpTabIds,
    required this.processIds,
    this.chromePid,
  });

  ActiveSession copyWith({
    int? workspaceId,
    DateTime? activatedAt,
    List<String>? cdpTabIds,
    List<int>? processIds,
    int? chromePid,
  }) {
    return ActiveSession(
      workspaceId: workspaceId ?? this.workspaceId,
      activatedAt: activatedAt ?? this.activatedAt,
      cdpTabIds: cdpTabIds ?? this.cdpTabIds,
      processIds: processIds ?? this.processIds,
      chromePid: chromePid ?? this.chromePid,
    );
  }
}
