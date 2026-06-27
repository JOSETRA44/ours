import 'package:flutter/material.dart';
import '../../../../domain/models/workspace_path.dart';
import '../../../shared_widgets/editable_list_item.dart';
import '../../../shared_widgets/section_header.dart';

class PathEditorSection extends StatelessWidget {
  final List<WorkspacePath> paths;
  final void Function(WorkspacePath) onDelete;
  final void Function(String pathType) onAdd;

  const PathEditorSection({
    super.key,
    required this.paths,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'FOLDERS & FILES',
          onAdd: () => _showAddMenu(context),
          addTooltip: 'Add folder or file',
        ),
        const SizedBox(height: 4),
        if (paths.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No paths — press + to add a folder or file',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          )
        else
          ...paths.map(
            (p) => EditableListItem(
              leading: Icon(
                p.isFolder ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                size: 16,
              ),
              primary: p.label ?? p.path,
              secondary: p.label != null ? p.path : null,
              onDelete: () => onDelete(p),
            ),
          ),
      ],
    );
  }

  void _showAddMenu(BuildContext context) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        120,
        16,
        0,
      ),
      items: [
        const PopupMenuItem(value: 'folder', child: Text('Add Folder')),
        const PopupMenuItem(value: 'file', child: Text('Add File')),
      ],
    ).then((value) {
      if (value != null) onAdd(value);
    });
  }
}
