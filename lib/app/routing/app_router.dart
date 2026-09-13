import 'package:aularaiz/features/about/presentation/about_screen.dart';
import 'package:aularaiz/features/home/presentation/home_screen.dart';
import 'package:aularaiz/features/settings/presentation/receive_backup_screen.dart';
import 'package:aularaiz/features/settings/presentation/settings_screen.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/receive-backup',
      builder: (context, state) => const ReceiveBackupScreen(),
    ),
  ],
);
