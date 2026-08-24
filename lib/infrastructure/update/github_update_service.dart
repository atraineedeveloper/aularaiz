import 'dart:convert';
import 'dart:io';

import 'package:aularaiz/infrastructure/update/app_update.dart';
import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _releasesUri =
    'https://api.github.com/repos/atraineedeveloper/aularaiz/releases?per_page=20';
const _maxMetadataBytes = 1024 * 1024;
const _maxChecksumBytes = 16 * 1024;
const _maxInstallerBytes = 300 * 1024 * 1024;

typedef PackageVersionProvider = Future<String> Function();
typedef UpdateHttpClientFactory = HttpClient Function();

final class VerifiedUpdateInstaller {
  const VerifiedUpdateInstaller({
    required this.file,
    required this.sha256,
    required this.update,
  });

  final File file;
  final String sha256;
  final AppUpdate update;
}

final class GithubUpdateService {
  GithubUpdateService({
    PackageVersionProvider? packageVersionProvider,
    UpdateHttpClientFactory? httpClientFactory,
  }) : _packageVersionProvider =
           packageVersionProvider ?? _readInstalledVersion,
       _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final PackageVersionProvider _packageVersionProvider;
  final UpdateHttpClientFactory _httpClientFactory;

  Future<String> currentVersion() => _packageVersionProvider();

  Future<AppUpdate?> checkForUpdate() async {
    if (!Platform.isWindows) return null;

    final installedVersion = await currentVersion();
    final metadata = await _getText(
      Uri.parse(_releasesUri),
      maxBytes: _maxMetadataBytes,
      acceptGithubJson: true,
    );
    return parseLatestGithubReleases(
      metadata,
      currentVersion: installedVersion,
    );
  }

  Future<VerifiedUpdateInstaller> downloadAndVerify(AppUpdate update) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows updates are only available on Windows.');
    }

    final checksumText = await _getText(
      update.checksumUri,
      maxBytes: _maxChecksumBytes,
    );
    final expectedChecksum = parseSha256Checksum(
      checksumText,
      fileName: update.installerFileName,
    );

    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'aularaiz-update-',
    );
    final installer = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}'
      '${update.installerFileName}',
    );

    try {
      await _downloadFile(
        update.installerUri,
        installer,
        maxBytes: _maxInstallerBytes,
      );
      final actualChecksum = (await sha256.bind(installer.openRead()).first)
          .toString()
          .toLowerCase();
      if (actualChecksum != expectedChecksum) {
        throw const FormatException(
          'Downloaded installer failed SHA-256 verification.',
        );
      }
      await _verifyAuthenticodeSignature(installer);
      return VerifiedUpdateInstaller(
        file: installer,
        sha256: expectedChecksum,
        update: update,
      );
    } catch (_) {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> launchUpdateCoordinator(VerifiedUpdateInstaller verified) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows updates are only available on Windows.');
    }
    if (!await verified.file.exists()) {
      throw StateError('The verified update installer no longer exists.');
    }

    final appExecutable = File(Platform.resolvedExecutable);
    final installedUpdater = File(
      '${appExecutable.parent.path}${Platform.pathSeparator}'
      'aularaiz-updater.exe',
    );
    if (!await installedUpdater.exists()) {
      throw StateError('The AulaRaíz update coordinator is not installed.');
    }

    final coordinatorCopy = File(
      '${verified.file.parent.path}${Platform.pathSeparator}'
      'aularaiz-updater.exe',
    );
    await installedUpdater.copy(coordinatorCopy.path);

    await Process.start(
      coordinatorCopy.path,
      <String>[
        '--pid',
        pid.toString(),
        '--installer',
        verified.file.path,
        '--sha256',
        verified.sha256,
        '--app',
        appExecutable.path,
      ],
      mode: ProcessStartMode.detached,
    );
  }

  Future<void> _verifyAuthenticodeSignature(File installer) async {
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
      throw const FormatException(
        'Could not verify the downloaded installer signature.',
      );
    }

    final signatureStatus = result.stdout.toString().trim();
    if (signatureStatus == 'Valid') return;

    final installerFileName = installer.uri.pathSegments.last;
    if (mayLaunchUnsignedBetaInstaller(
      installerFileName: installerFileName,
      signatureStatus: signatureStatus,
    )) {
      return;
    }

    throw FormatException(
      'Downloaded installer Authenticode status was $signatureStatus.',
    );
  }

  Future<String> _getText(
    Uri uri, {
    required int maxBytes,
    bool acceptGithubJson = false,
  }) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      _configureRequest(request, acceptGithubJson: acceptGithubJson);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Update server returned HTTP ${response.statusCode}.',
          uri: uri,
        );
      }

      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('Update metadata exceeded size limit.');
        }
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _downloadFile(
    Uri uri,
    File destination, {
    required int maxBytes,
  }) async {
    final client = _httpClientFactory()
      ..connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;
    try {
      final request = await client.getUrl(uri);
      _configureRequest(request);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Update download returned HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      if (response.contentLength > maxBytes) {
        throw const FormatException('Update installer exceeded size limit.');
      }

      sink = destination.openWrite();
      var receivedBytes = 0;
      await for (final chunk in response) {
        receivedBytes += chunk.length;
        if (receivedBytes > maxBytes) {
          throw const FormatException('Update installer exceeded size limit.');
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }

  void _configureRequest(
    HttpClientRequest request, {
    bool acceptGithubJson = false,
  }) {
    request.headers.set(HttpHeaders.userAgentHeader, 'AulaRaiz-Update-Client');
    if (acceptGithubJson) {
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set('X-GitHub-Api-Version', '2022-11-28');
    }
  }
}

Future<String> _readInstalledVersion() async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
}
