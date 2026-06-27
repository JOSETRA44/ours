import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../../data/database/app_database.dart';
import '../../presentation/providers/workspace_providers.dart';
import '../../presentation/providers/activation_notifier.dart';
import '../../core/constants/app_constants.dart';

class TrayService with TrayListener {
  final Ref _ref;

  TrayService(this._ref);

  Future<void> initialize() async {
    await trayManager.setIcon('assets/icons/tray_icon.ico');
    await trayManager.setToolTip(AppConstants.appName);
    trayManager.addListener(this);

    _ref.listen(workspaceListProvider, (_, __) => _rebuildMenu());
    _ref.listen(activeSessionProvider, (_, __) => _rebuildMenu());

    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() async {
    final workspaces =
        _ref.read(workspaceListProvider).valueOrNull ?? [];
    final session = _ref.read(activeSessionProvider).valueOrNull;

    final workspaceItems = workspaces.map((WorkspaceRow w) {
      final isActive = session?.workspaceId == w.id;
      return MenuItem(
        key: 'ws_${w.id}',
        label: isActive ? 'Deactivate: ${w.name}' : 'Activate: ${w.name}',
      );
    }).toList();

    final menu = Menu(items: [
      MenuItem(key: 'show_hide', label: 'Show / Hide'),
      MenuItem.separator(),
      if (workspaceItems.isEmpty)
        MenuItem(label: '(No workspaces)', disabled: true),
      ...workspaceItems,
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]);

    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_hide':
        windowManager.isVisible().then((visible) {
          if (visible) {
            windowManager.hide();
          } else {
            windowManager.show();
            windowManager.focus();
          }
        });
      case 'quit':
        windowManager.destroy();
      default:
        final key = menuItem.key;
        if (key != null && key.startsWith('ws_')) {
          final id = int.tryParse(key.substring(3));
          if (id != null) {
            _ref
                .read(workspaceActivationNotifierProvider.notifier)
                .toggle(id);
          }
        }
    }
  }

  void dispose() {
    trayManager.removeListener(this);
  }
}

final trayServiceProvider = Provider<TrayService>((ref) {
  final service = TrayService(ref);
  ref.onDispose(service.dispose);
  return service;
});
