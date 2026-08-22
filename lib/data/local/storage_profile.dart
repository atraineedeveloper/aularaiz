enum StorageProfile {
  production,
  demo;

  String get databaseName => switch (this) {
    StorageProfile.production => 'aularaiz-production',
    StorageProfile.demo => 'aularaiz-demo',
  };
}
