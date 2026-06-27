class WorkspaceUrl {
  final int id;
  final int workspaceId;
  final String url;
  final String? label;
  final int sortOrder;

  const WorkspaceUrl({
    required this.id,
    required this.workspaceId,
    required this.url,
    this.label,
    required this.sortOrder,
  });

  WorkspaceUrl copyWith({
    int? id,
    int? workspaceId,
    String? url,
    String? label,
    int? sortOrder,
  }) {
    return WorkspaceUrl(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      url: url ?? this.url,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
