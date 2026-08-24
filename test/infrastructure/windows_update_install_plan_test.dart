import 'package:aularaiz/infrastructure/update/windows_update_install_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('update installer targets the running AulaRaíz directory', () {
    final arguments = buildWindowsUpdateInstallerArguments(
      installDirectory: r'C:\Users\Teacher\AppData\Local\Programs\AulaRaiz',
      installerLogPath: r'C:\Temp\aularaiz-installer.log',
    );

    expect(arguments, contains('/VERYSILENT'));
    expect(arguments, contains('/SUPPRESSMSGBOXES'));
    expect(arguments, contains('/NORESTART'));
    expect(arguments, contains('/CLOSEAPPLICATIONS'));
    expect(
      arguments,
      contains(r'/DIR=C:\Users\Teacher\AppData\Local\Programs\AulaRaiz'),
    );
    expect(arguments, contains(r'/LOG=C:\Temp\aularaiz-installer.log'));
  });

  test('update installer plan rejects empty target paths', () {
    expect(
      () => buildWindowsUpdateInstallerArguments(
        installDirectory: '   ',
        installerLogPath: r'C:\Temp\aularaiz-installer.log',
      ),
      throwsArgumentError,
    );
    expect(
      () => buildWindowsUpdateInstallerArguments(
        installDirectory: r'C:\AulaRaiz',
        installerLogPath: ' ',
      ),
      throwsArgumentError,
    );
  });
}
