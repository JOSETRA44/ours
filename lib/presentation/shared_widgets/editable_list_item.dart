import 'package:flutter/material.dart';

class EditableListItem extends StatelessWidget {
  final String primary;
  final String? secondary;
  final Widget? leading;
  final VoidCallback onDelete;

  const EditableListItem({
    super.key,
    required this.primary,
    this.secondary,
    this.leading,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha:0.5),
        ),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        leading: leading,
        title: Text(
          primary,
          style: theme.textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: secondary != null
            ? Text(
                secondary!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 16),
          onPressed: onDelete,
          tooltip: 'Remove',
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
