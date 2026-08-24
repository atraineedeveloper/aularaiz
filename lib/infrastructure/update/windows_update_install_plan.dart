List<String> buildWindowsUpdateInstallerArguments({
  required String installDirectory,
  required String installerLogPath,
}) {
  final normalizedDirectory = installDirectory.trim();
  final normalizedLogPath = installerLogPath.trim();
  if (normalizedDirectory.isEmpty) {
    throw ArgumentError.value(
      installDirectory,
      'installDirectory',
      'Install directory cannot be empty.',
    );
  }
  if (normalizedLogPath.isEmpty) {
    throw ArgumentError.value(
      installerLogPath,
      'installerLogPath',
      'Installer log path cannot be empty.',
    );
  }

  return List<String>.unmodifiable(<String>[
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/SP-',
    '/CLOSEAPPLICATIONS',
    '/DIR=$normalizedDirectory',
    '/LOG=$normalizedLogPath',
  ]);
}
