import 'dart:ui';

import 'package:flutter/material.dart';

class RecoveryFailureApp extends StatelessWidget {
  const RecoveryFailureApp({super.key});

  @override
  Widget build(BuildContext context) {
    final english = PlatformDispatcher.instance.locale.languageCode == 'en';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 64),
                    const SizedBox(height: 24),
                    Text(
                      english
                          ? 'AulaRaíz stopped to protect your data'
                          : 'AulaRaíz se detuvo para proteger tus datos',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      english
                          ? 'A restore could not be completed or rolled back safely. The app will not continue writing to the classroom database. Do not uninstall the app or delete its data; the recovery files were preserved.'
                          : 'Una restauración no pudo completarse ni revertirse de forma segura. La app no continuará escribiendo en la base del aula. No desinstales la app ni borres sus datos; los archivos de recuperación se conservaron.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
