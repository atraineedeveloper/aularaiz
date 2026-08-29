import 'dart:io';

import 'package:aularaiz/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'v5 to v6 tolerates columns left by a partial prior migration',
    () async {
      final directory = await Directory.systemTemp.createTemp('aularaiz-v6-');
      final file = File(
        '${directory.path}${Platform.pathSeparator}database.sqlite',
      );
      addTearDown(() => directory.delete(recursive: true));

      final initial = AppDatabase.forTesting(NativeDatabase(file));
      await initial.customSelect('SELECT 1').getSingle();
      await initial.close();

      final raw = sqlite3.open(file.path);
      raw.execute('PRAGMA user_version = 5');
      raw.close();

      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();

      expect(version.read<int>('user_version'), 6);
    },
  );
}
