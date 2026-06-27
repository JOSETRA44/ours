import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'presentation/providers/service_providers.dart';
import 'services/tray/tray_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(900, 600),
    center: true,
    title: 'Workspace Context Manager',
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.normal,
    skipTaskbar: false,
  );

  // Create a shared container so we can use providers before runApp
  final container = ProviderContainer();

  // Initialize tray before showing the window
  await container.read(trayServiceProvider).initialize();

  // Recover session state from previous run
  await container
      .read(workspaceActivationServiceProvider)
      .recoverSession();

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
