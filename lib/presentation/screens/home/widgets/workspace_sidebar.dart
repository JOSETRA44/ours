import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/database/app_database.dart';
import '../../../../presentation/providers/repository_providers.dart';
import '../../../../presentation/providers/workspace_providers.dart';
import 'workspace_list_tile.dart';

class WorkspaceSidebar extends ConsumerWidget {
  const WorkspaceSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(workspaceListProvider);
    final activeSession = ref.watch(activeSessionProvider).valueOrNull;
    final selectedId = ref.watch(selectedWorkspaceIdProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  'WORKSPACES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'New workspace',
                  onPressed: () => _createWorkspace(context, ref),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Expanded(
            child: workspacesAsync.when(
              data: (workspaces) => workspaces.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.workspaces_outlined,
                            size: 48,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No workspaces yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Create one'),
                            onPressed: () =>
                                _createWorkspace(context, ref),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: workspaces.length,
                      itemBuilder: (context, index) {
                        final ws = workspaces[index];
                        return WorkspaceListTile(
                          workspace: ws,
                          activeSession: activeSession,
                          isSelected: selectedId == ws.id,
                          onTap: () => ref
                              .read(selectedWorkspaceIdProvider.notifier)
                              .state = ws.id,
                        );
                      },
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createWorkspace(
      BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Workspace'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Workspace name',
            hintText: 'e.g. Project Alpha',
          ),
          onSubmitted: (_) =>
              Navigator.of(ctx).pop(nameController.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(nameController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final repo = ref.read(workspaceRepositoryProvider);
      final id = await repo.createWorkspace(
        WorkspacesCompanion.insert(name: name),
      );
      ref.read(selectedWorkspaceIdProvider.notifier).state = id;
    }
  }
}
