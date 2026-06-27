import 'package:flutter/material.dart';
import '../../../../data/database/app_database.dart';
import '../../../../domain/models/active_session.dart';

class WorkspaceListTile extends StatelessWidget {
  final WorkspaceRow workspace;
  final ActiveSession? activeSession;
  final bool isSelected;
  final VoidCallback onTap;

  const WorkspaceListTile({
    super.key,
    required this.workspace,
    required this.activeSession,
    required this.isSelected,
    required this.onTap,
  });

  bool get _isActive => activeSession?.workspaceId == workspace.id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = workspace.colorValue != null
        ? Color(workspace.colorValue!)
        : theme.colorScheme.primary;

    return ListTile(
      selected: isSelected,
      selectedTileColor:
          theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.15),
        child: _isActive
            ? Icon(Icons.flash_on, color: color, size: 16)
            : Icon(Icons.folder_outlined, color: color, size: 16),
      ),
      title: Text(
        workspace.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _isActive
          ? Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Active',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.green),
                ),
              ],
            )
          : null,
      onTap: onTap,
    );
  }
}
