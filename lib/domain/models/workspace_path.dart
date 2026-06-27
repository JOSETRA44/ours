class WorkspacePath {
  final int id;
  final int workspaceId;
  final String path;
  // 'file' | 'folder'
  final String pathType;
  final String? label;
  final int sortOrder;

  const WorkspacePath({
    required this.id,
    required this.workspaceId,
    required this.path,
    required this.pathType,
    this.label,
    required this.sortOrder,
  });

  bool get isFolder => pathType == 'folder';

  WorkspacePath copyWith({
    int? id,
    int? workspaceId,
    String? path,
    String? pathType,
    String? label,
    int? sortOrder,
  }) {
    return WorkspacePath(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      path: path ?? this.path,
      pathType: pathType ?? this.pathType,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
