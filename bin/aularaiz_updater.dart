import 'dart:io';

import 'package:aularaiz/infrastructure/update/app_update.dart';
import 'package:crypto/crypto.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help')) {
    stdout.writeln(
      'AulaRaíz update coordinator. '
      'Arguments: --pid <id> --installer <path> --sha256 <hash> --app <path>',
    );
    return;
  }

  try {
    final request = _UpdateRequest.parse(args);
    await _verifyInstaller(request.installer, request.sha256);
    await _verifyAuthenticodeSignature(request.installer);
    await _waitForProcessExit(request.pid);

    final result = await Process.run(
      request.installer.path,
      const <String>[
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/SP-',
      ],
    );
    if (result.exitCode != 0) {
      throw StateError('Installer returned a non-zero exit code.');
    }

    if (!await request.app.exists()) {
      throw StateError('AulaRaíz executable was not found after update.');
    }

    await Process.start(
      request.app.path,
      const <String>[],
      mode: ProcessStartMode.detached,
    );
  } catch (_) {
    stderr.writeln('AulaRaíz could not complete the coordinated update.');
    exitCode = 1;
  }
}

final class _UpdateRequest {
  const _UpdateRequest({
    required this.pid,
    required this.installer,
    required this.sha256,
    required this.app,
  });

  factory _UpdateRequest.parse(List<String> args) {
    String requiredValue(String name) {
      final index = args.indexOf(name);
      if (index < 0 || index + 1 >= args.length) {
        throw FormatException('Missing $name.');
      }
      final value = args[index + 1].trim();
      if (value.isEmpty || value.startsWith('--')) {
        throw FormatException('Invalid $name.');
      }
      return value;
    }

    final parsedPid = int.tryParse(requiredValue('--pid'));
    if (parsedPid == null || parsedPid <= 0) {
      throw const FormatException('Invalid process id.');
    }

    final expectedHash = requiredValue('--sha256').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedHash)) {
      throw const FormatException('Invalid SHA-256 value.');
    }

    final installer = File(requiredValue('--installer'));
    final app = File(requiredValue('--app'));
    if (!RegExp(r'^AulaRaiz-Setup-\d+\.\d+\.\d+\.exe$')
        .hasMatch(installer.uri.pathSegments.last)) {
      throw const FormatException('Unexpected installer filename.');
    }
    if (app.uri.pathSegments.last.toLowerCase() != 'aularaiz.exe') {
      throw const FormatException('Unexpected application executable.');
    }

    return _UpdateRequest(
      pid: parsedPid,
      installer: installer,
      sha256: expectedHash,
      app: app,
    );
  }

  final int pid;
  final File installer;
  final String sha256;
  final File app;
}

Future<void> _verifyInstaller(File installer, String expectedSha256) async {
  if (!await installer.exists()) {
    throw StateError('Installer is missing.');
  }
  final actual = (await sha256.bind(installer.openRead()).first)
      .toString()
      .toLowerCase();
  if (actual != expectedSha256) {
    throw const FormatException('Installer checksum mismatch.');
  }
}

Future<void> _verifyAuthenticodeSignature(File installer) async {
  if (!Platform.isWindows) {
    throw UnsupportedError('The update coordinator only runs on Windows.');
  }

  const verificationScript = r'''
$signature = Get-AuthenticodeSignature -LiteralPath $env:AULARAIZ_UPDATE_INSTALLER
[Console]::Out.Write($signature.Status.ToString())
''';
  final result = await Process.run(
    'powershell.exe',
    <String>['-NoProfile', '-NonInteractive', '-Command', verificationScript],
    environment: <String, String>{
      ...Platform.environment,
      'AULARAIZ_UPDATE_INSTALLER': installer.path,
    },
  );
  if (result.exitCode != 0) {
    throw const FormatException('Could not verify Authenticode signature.');
  }

  final status = result.stdout.toString().trim();
  if (status == 'Valid') return;
  if (mayLaunchUnsignedBetaInstaller(
    installerFileName: installer.uri.pathSegments.last,
    signatureStatus: status,
  )) {
    return;
  }
  throw FormatException('Unexpected Authenticode status: $status.');
}

Future<void> _waitForProcessExit(int processId) async {
  if (!Platform.isWindows) return;

  final script = '''
\$process = Get-Process -Id $processId -ErrorAction SilentlyContinue
if (\$null -ne \$process) {
  \$process | Wait-Process -Timeout 120 -ErrorAction Stop
}
''';
  final result = await Process.run(
    'powershell.exe',
    <String>['-NoProfile', '-NonInteractive', '-Command', script],
  );
  if (result.exitCode != 0) {
    throw const StateError('AulaRaíz did not close before the update timeout.');
  }
}
