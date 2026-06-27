import 'workspace_url.dart';
import 'workspace_path.dart';
import 'workspace_command.dart';

class Workspace {
  final int id;
  final String name;
  final String? description;
  final int? colorValue;
  final String? iconName;
  final int sortOrder;
  final List<WorkspaceUrl> urls;
  final List<WorkspacePath> paths;
  final List<WorkspaceCommand> commands;

  const Workspace({
    required this.id,
    required this.name,
    this.description,
    this.colorValue,
    this.iconName,
    required this.sortOrder,
    required this.urls,
    required this.paths,
    required this.commands,
  });

  Workspace copyWith({
    int? id,
    String? name,
    String? description,
    int? colorValue,
    String? iconName,
    int? sortOrder,
    List<WorkspaceUrl>? urls,
    List<WorkspacePath>? paths,
    List<WorkspaceCommand>? commands,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      urls: urls ?? this.urls,
      paths: paths ?? this.paths,
      commands: commands ?? this.commands,
    );
  }
}
