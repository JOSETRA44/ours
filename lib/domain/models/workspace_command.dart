class WorkspaceCommand {
  final int id;
  final int workspaceId;
  final String command;
  final String? workingDirectory;
  final String? label;
  final int sortOrder;

  const WorkspaceCommand({
    required this.id,
    required this.workspaceId,
    required this.command,
    this.workingDirectory,
    this.label,
    required this.sortOrder,
  });

  WorkspaceCommand copyWith({
    int? id,
    int? workspaceId,
    String? command,
    String? workingDirectory,
    String? label,
    int? sortOrder,
  }) {
    return WorkspaceCommand(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      command: command ?? this.command,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
