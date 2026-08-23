import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class AppAccessibilityFrame extends StatelessWidget {
  const AppAccessibilityFrame({
    required this.child,
    required this.onOpenSettings,
    required this.onNavigateBack,
    super.key,
  });

  final Widget child;
  final VoidCallback onOpenSettings;
  final VoidCallback onNavigateBack;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(
            LogicalKeyboardKey.comma,
            control: true,
          ): onOpenSettings,
          const SingleActivator(
            LogicalKeyboardKey.arrowLeft,
            alt: true,
          ): onNavigateBack,
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
