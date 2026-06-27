import 'package:flutter/material.dart';
import '../../../../domain/models/workspace_url.dart';
import '../../../shared_widgets/editable_list_item.dart';
import '../../../shared_widgets/section_header.dart';

class UrlEditorSection extends StatelessWidget {
  final List<WorkspaceUrl> urls;
  final void Function(WorkspaceUrl) onDelete;
  final VoidCallback onAdd;

  const UrlEditorSection({
    super.key,
    required this.urls,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'BROWSER TABS',
          onAdd: onAdd,
          addTooltip: 'Add URL',
        ),
        const SizedBox(height: 4),
        if (urls.isEmpty)
          _EmptyHint(hint: 'No URLs — press + to add one')
        else
          ...urls.map(
            (u) => EditableListItem(
              leading: const Icon(Icons.language, size: 16),
              primary: u.label ?? u.url,
              secondary: u.label != null ? u.url : null,
              onDelete: () => onDelete(u),
            ),
          ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String hint;
  const _EmptyHint({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        hint,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}
