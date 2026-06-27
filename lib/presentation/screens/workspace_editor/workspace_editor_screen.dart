import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/models/cdp_tab.dart';
import '../../../domain/models/workspace.dart';
import '../../../domain/models/workspace_url.dart';
import '../../../domain/models/workspace_path.dart';
import '../../../domain/models/workspace_command.dart';
import '../../../domain/models/active_session.dart';
import '../../../presentation/providers/repository_providers.dart';
import '../../../presentation/providers/service_providers.dart';
import '../../../presentation/providers/workspace_providers.dart';
import '../../../presentation/providers/activation_notifier.dart';
import '../../shared_widgets/activation_button.dart';
import 'widgets/url_editor_section.dart';
import 'widgets/path_editor_section.dart';
import 'widgets/command_editor_section.dart';

class WorkspaceEditorScreen extends ConsumerStatefulWidget {
  final Workspace workspace;
  final ActiveSession? activeSession;

  const WorkspaceEditorScreen({
    super.key,
    required this.workspace,
    required this.activeSession,
  });

  @override
  ConsumerState<WorkspaceEditorScreen> createState() =>
      _WorkspaceEditorScreenState();
}

class _WorkspaceEditorScreenState
    extends ConsumerState<WorkspaceEditorScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late List<WorkspaceUrl> _urls;
  late List<WorkspacePath> _paths;
  late List<WorkspaceCommand> _commands;
  bool _dirty = false;
  bool _capturingFromChrome = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.workspace.name);
    _descCtrl =
        TextEditingController(text: widget.workspace.description ?? '');
    _urls = List.from(widget.workspace.urls);
    _paths = List.from(widget.workspace.paths);
    _commands = List.from(widget.workspace.commands);
  }

  @override
  void didUpdateWidget(WorkspaceEditorScreen old) {
    super.didUpdateWidget(old);
    if (old.workspace.id != widget.workspace.id) {
      _nameCtrl.text = widget.workspace.name;
      _descCtrl.text = widget.workspace.description ?? '';
      _urls = List.from(widget.workspace.urls);
      _paths = List.from(widget.workspace.paths);
      _commands = List.from(widget.workspace.commands);
      _dirty = false;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isActive =>
      widget.activeSession?.workspaceId == widget.workspace.id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activationState =
        ref.watch(workspaceActivationNotifierProvider);
    final isLoading = activationState.isLoading;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                    TextField(
                      controller: _descCtrl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Add a description...',
                        hintStyle: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (_isActive) const _MirrorActiveBadge(),
              const SizedBox(width: 8),
              ActivationButton(
                isActive: _isActive,
                isLoading: isLoading,
                onPressed: () => ref
                    .read(workspaceActivationNotifierProvider.notifier)
                    .toggle(widget.workspace.id),
              ),
            ],
          ),
        ),

        // Error banner
        if (activationState.hasError)
          MaterialBanner(
            content: Text(activationState.error.toString()),
            backgroundColor: theme.colorScheme.errorContainer,
            actions: [
              TextButton(
                onPressed: () => ref
                    .read(workspaceActivationNotifierProvider.notifier)
                    .build(),
                child: const Text('Dismiss'),
              ),
            ],
          ),

        // Editor body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrlEditorSection(
                  urls: _urls,
                  onDelete: (u) => setState(() {
                    _urls.remove(u);
                    _dirty = true;
                  }),
                  onAdd: _addUrl,
                ),
                const SizedBox(height: 8),
                if (_isActive)
                  const _MirrorInfoBanner()
                else
                  _CaptureFromChromeButton(
                    isCapturing: _capturingFromChrome,
                    onPressed: _captureFromChrome,
                  ),
                const SizedBox(height: 24),
                PathEditorSection(
                  paths: _paths,
                  onDelete: (p) => setState(() {
                    _paths.remove(p);
                    _dirty = true;
                  }),
                  onAdd: _addPath,
                ),
                const SizedBox(height: 24),
                CommandEditorSection(
                  commands: _commands,
                  onDelete: (c) => setState(() {
                    _commands.remove(c);
                    _dirty = true;
                  }),
                  onAdd: _addCommand,
                ),
              ],
            ),
          ),
        ),

        // Bottom action bar
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete workspace'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                onPressed: _confirmDelete,
              ),
              Row(
                children: [
                  if (_dirty) ...[
                    TextButton(
                      onPressed: _revertChanges,
                      child: const Text('Revert'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton(
                    onPressed: _dirty ? _save : null,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addUrl() async {
    final urlCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Browser Tab'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && urlCtrl.text.trim().isNotEmpty) {
      setState(() {
        _urls.add(WorkspaceUrl(
          id: 0,
          workspaceId: widget.workspace.id,
          url: urlCtrl.text.trim(),
          label: labelCtrl.text.trim().isEmpty
              ? null
              : labelCtrl.text.trim(),
          sortOrder: _urls.length,
        ));
        _dirty = true;
      });
    }
  }

  Future<void> _addPath(String pathType) async {
    String? picked;
    if (pathType == 'folder') {
      picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select a folder',
      );
    } else {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select a file',
      );
      picked = result?.files.single.path;
    }

    if (picked != null) {
      final labelCtrl = TextEditingController();
      if (!mounted) return;
      final label = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Add ${pathType == 'folder' ? 'Folder' : 'File'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(picked!, style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 8),
              TextField(
                controller: labelCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Label (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(labelCtrl.text.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      );

      if (label != null) {
        setState(() {
          _paths.add(WorkspacePath(
            id: 0,
            workspaceId: widget.workspace.id,
            path: picked!,
            pathType: pathType,
            label: label.isEmpty ? null : label,
            sortOrder: _paths.length,
          ));
          _dirty = true;
        });
      }
    }
  }

  Future<void> _addCommand() async {
    final cmdCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Terminal Command'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cmdCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Command',
                hintText: 'npm run dev',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dirCtrl,
              decoration: const InputDecoration(
                labelText: 'Working directory (optional)',
                hintText: r'C:\Projects\myapp',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && cmdCtrl.text.trim().isNotEmpty) {
      setState(() {
        _commands.add(WorkspaceCommand(
          id: 0,
          workspaceId: widget.workspace.id,
          command: cmdCtrl.text.trim(),
          workingDirectory:
              dirCtrl.text.trim().isEmpty ? null : dirCtrl.text.trim(),
          label: labelCtrl.text.trim().isEmpty
              ? null
              : labelCtrl.text.trim(),
          sortOrder: _commands.length,
        ));
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    final repo = ref.read(workspaceRepositoryProvider);
    await repo.updateWorkspace(
      widget.workspace.id,
      WorkspacesCompanion(
        name: Value(_nameCtrl.text.trim()),
        description: Value(
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await repo.saveWorkspaceItems(
      workspaceId: widget.workspace.id,
      urls: _urls,
      paths: _paths,
      commands: _commands,
    );
    ref.invalidate(selectedWorkspaceDetailProvider);
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace saved')),
      );
    }
  }

  void _revertChanges() {
    setState(() {
      _nameCtrl.text = widget.workspace.name;
      _descCtrl.text = widget.workspace.description ?? '';
      _urls = List.from(widget.workspace.urls);
      _paths = List.from(widget.workspace.paths);
      _commands = List.from(widget.workspace.commands);
      _dirty = false;
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete workspace?'),
        content: Text(
          'This will permanently delete "${widget.workspace.name}" and all its items.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(workspaceRepositoryProvider)
          .deleteWorkspace(widget.workspace.id);
      ref.read(selectedWorkspaceIdProvider.notifier).state = null;
    }
  }

  Future<void> _captureFromChrome() async {
    setState(() => _capturingFromChrome = true);
    try {
      final service = ref.read(workspaceActivationServiceProvider);
      final tabs = await service.captureCurrentBrowserTabs();

      if (!mounted) return;

      if (tabs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No navigable tabs found. Is Chrome running with debugging enabled?'),
          ),
        );
        return;
      }

      // Show selection dialog
      final selected = await _showTabSelectionDialog(tabs);
      if (selected == null || selected.isEmpty) return;

      setState(() {
        for (final tab in selected) {
          final alreadyExists = _urls.any((u) => u.url == tab.url);
          if (!alreadyExists) {
            _urls.add(WorkspaceUrl(
              id: 0,
              workspaceId: widget.workspace.id,
              url: tab.url,
              label: tab.title.isNotEmpty ? tab.title : null,
              sortOrder: _urls.length,
            ));
          }
        }
        _dirty = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${selected.length} tab(s) imported from Chrome')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturingFromChrome = false);
    }
  }

  Future<List<CdpTab>?> _showTabSelectionDialog(List<CdpTab> tabs) async {
    final selected = <int>{...List.generate(tabs.length, (i) => i)};

    return showDialog<List<CdpTab>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Import ${tabs.length} tab(s) from Chrome'),
          content: SizedBox(
            width: 500,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: tabs.length,
              itemBuilder: (_, i) {
                final tab = tabs[i];
                return CheckboxListTile(
                  value: selected.contains(i),
                  onChanged: (v) => setDialogState(() {
                    if (v == true) {
                      selected.add(i);
                    } else {
                      selected.remove(i);
                    }
                  }),
                  title: Text(
                    tab.title.isNotEmpty ? tab.title : tab.url,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    tab.url,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  secondary: const Icon(Icons.language, size: 16),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(selected.map((i) => tabs[i]).toList()),
              child: Text('Import ${selected.length} tab(s)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MirrorActiveBadge extends StatelessWidget {
  const _MirrorActiveBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Mirror active',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MirrorInfoBanner extends StatelessWidget {
  const _MirrorInfoBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.sync, size: 14, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tabs are tracked automatically. '
              'This list will update when you deactivate the workspace.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureFromChromeButton extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback onPressed;

  const _CaptureFromChromeButton({
    required this.isCapturing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: isCapturing ? null : onPressed,
      icon: isCapturing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.document_scanner_outlined, size: 16),
      label: Text(isCapturing ? 'Connecting to Chrome...' : 'Capture from Chrome'),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.secondary,
        side: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
