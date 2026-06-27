import 'package:flutter/material.dart';

class ActivationButton extends StatelessWidget {
  final bool isActive;
  final bool isLoading;
  final VoidCallback onPressed;

  const ActivationButton({
    super.key,
    required this.isActive,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return FilledButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Working...'),
      );
    }

    if (isActive) {
      return FilledButton.tonalIcon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.errorContainer,
          foregroundColor: theme.colorScheme.onErrorContainer,
        ),
        icon: const Icon(Icons.stop_circle_outlined, size: 18),
        label: const Text('Deactivate'),
      );
    }

    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.play_circle_outline, size: 18),
      label: const Text('Activate'),
    );
  }
}
