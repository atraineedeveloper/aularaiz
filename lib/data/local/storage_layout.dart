import 'dart:io';

import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:path_provider/path_provider.dart';

typedef ApplicationSupportDirectoryProvider = Future<Directory> Function();

final class AulaRaizStorageLayout {
  const AulaRaizStorageLayout._({
    required this.directory,
    required this.profile,
  });

  final Directory directory;
  final StorageProfile profile;

  static Future<AulaRaizStorageLayout> resolve(
    StorageProfile profile, {
    ApplicationSupportDirectoryProvider directoryProvider =
        getApplicationSupportDirectory,
  }) async {
    final directory = await directoryProvider();
    await directory.create(recursive: true);
    return AulaRaizStorageLayout._(directory: directory, profile: profile);
  }

  String get _prefix => profile.databaseName;

  File get databaseFile => _file('$_prefix.sqlite');

  File get restoreMarkerFile => _file('$_prefix.restore-request.json');

  File get restoreMarkerTempFile => _file('$_prefix.restore-request.tmp');

  File pendingRestoreFile(String requestId) =>
      _file('$_prefix.restore-$requestId.pending.sqlite');

  File safetyRestoreFile(String requestId) =>
      _file('$_prefix.restore-$requestId.safety.sqlite');

  File originalRestoreFile(String requestId) =>
      _file('$_prefix.restore-$requestId.original.sqlite');

  File sidecar(File database, String suffix) => File('${database.path}$suffix');

  bool isManagedRestoreArtifact(FileSystemEntity entity) {
    final name = entity.uri.pathSegments.isEmpty
        ? ''
        : entity.uri.pathSegments.last;
    return name.startsWith('$_prefix.restore-');
  }

  File _file(String name) => File(
    '${directory.path}${Platform.pathSeparator}$name',
  );
}
