import 'package:aularaiz/data/local/storage_profile.dart';

final class AppRuntimeConfig {
  const AppRuntimeConfig({
    required this.storageProfile,
    this.resetDemo = false,
  });

  const AppRuntimeConfig.production()
    : storageProfile = StorageProfile.production,
      resetDemo = false;

  final StorageProfile storageProfile;
  final bool resetDemo;

  bool get isDemo => storageProfile == StorageProfile.demo;

  static AppRuntimeConfig fromArguments(Iterable<String> arguments) {
    final normalized = arguments
        .map((value) => value.trim().toLowerCase())
        .toSet();
    final resetDemo = normalized.contains('--demo-reset');
    final demo = resetDemo || normalized.contains('--demo');

    return AppRuntimeConfig(
      storageProfile: demo ? StorageProfile.demo : StorageProfile.production,
      resetDemo: resetDemo,
    );
  }
}
