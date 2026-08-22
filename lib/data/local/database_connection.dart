import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

QueryExecutor openAulaRaizConnection(StorageProfile profile) {
  return driftDatabase(
    name: profile.databaseName,
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
