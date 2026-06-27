import 'package:flutter/material.dart';
import '../../../../domain/models/workspace_command.dart';
import '../../../shared_widgets/editable_list_item.dart';
import '../../../shared_widgets/section_header.dart';

class CommandEditorSection extends StatelessWidget {
  final List<WorkspaceCommand> commands;
  final void Function(WorkspaceCommand) onDelete;
  final VoidCallback onAdd;

  const CommandEditorSection({
    super.key,
    required this.commands,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'TERMINAL COMMANDS',
          onAdd: onAdd,
          addTooltip: 'Add command',
        ),
        const SizedBox(height: 4),
        if (commands.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No commands — press + to add one',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          )
        else
          ...commands.map(
            (c) => EditableListItem(
              leading: const Icon(Icons.terminal, size: 16),
              primary: c.label ?? c.command,
              secondary: c.workingDirectory != null
                  ? '${c.command}  •  ${c.workingDirectory}'
                  : (c.label != null ? c.command : null),
              onDelete: () => onDelete(c),
            ),
          ),
      ],
    );
  }
}
