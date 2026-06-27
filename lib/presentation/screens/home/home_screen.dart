import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/workspace_providers.dart';
import '../workspace_editor/workspace_editor_screen.dart';
import 'widgets/workspace_sidebar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedWorkspaceIdProvider);
    final activeSession = ref.watch(activeSessionProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace Context Manager'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          SizedBox(
            width: 240,
            child: const WorkspaceSidebar(),
          ),

          // Editor pane
          Expanded(
            child: selectedId == null
                ? _EmptyState(
                    onCreatePressed: () {
                      // Trigger create via sidebar — just focus to sidebar
                    },
                  )
                : _EditorPane(
                    workspaceId: selectedId,
                    activeSession: activeSession,
                  ),
          ),
        ],
      ),
    );
  }
}

class _EditorPane extends ConsumerWidget {
  final int workspaceId;
  final dynamic activeSession;

  const _EditorPane({
    required this.workspaceId,
    required this.activeSession,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceAsync = ref.watch(selectedWorkspaceDetailProvider);

    return workspaceAsync.when(
      data: (workspace) {
        if (workspace == null) {
          return const Center(child: Text('Workspace not found'));
        }
        return WorkspaceEditorScreen(
          workspace: workspace,
          activeSession: activeSession,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 8),
            Text('Error loading workspace: $e'),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreatePressed;

  const _EmptyState({required this.onCreatePressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspaces_outlined,
            size: 72,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Select a workspace to edit',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'or create a new one from the sidebar',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
