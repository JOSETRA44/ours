import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _chromePathCtrl;
  late TextEditingController _portCtrl;

  @override
  void initState() {
    super.initState();
    _chromePathCtrl = TextEditingController(
        text: AppConstants.chromeCandidatePaths.first);
    _portCtrl =
        TextEditingController(text: AppConstants.cdpPort.toString());
  }

  @override
  void dispose() {
    _chromePathCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Chrome Integration',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _chromePathCtrl,
            decoration: const InputDecoration(
              labelText: 'Chrome executable path',
              hintText: r'C:\Program Files\Google\Chrome\Application\chrome.exe',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Remote debugging port',
              hintText: '9222',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('About',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Version'),
            trailing: const Text('1.0.0'),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text('App name'),
            trailing: const Text(AppConstants.appName),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
