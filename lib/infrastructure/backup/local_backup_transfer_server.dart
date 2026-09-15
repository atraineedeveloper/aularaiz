import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/create_backup.dart';
import 'package:aularaiz/application/contracts/database_snapshotter.dart';
import 'package:aularaiz/infrastructure/backup/portable_backup_protector.dart';
import 'package:aularaiz/infrastructure/sync/record_level_sync_service.dart';

typedef PortableBackupUploadHandler = Future<RecordLevelSyncSummary> Function({
  required Uint8List bytes,
  required String transferCode,
  String? sourceDeviceId,
  String? sourceDeviceName,
});

final class PortableBackupTransferSession {
  const PortableBackupTransferSession({
    required this.downloadUrl,
    this.uploadUrl,
    required this.transferCode,
    this.sourceDeviceId,
    this.sourceDeviceName,
    required Future<void> Function() stop,
  }) : _stop = stop;

  final String downloadUrl;
  final String? uploadUrl;
  final String transferCode;
  final String? sourceDeviceId;
  final String? sourceDeviceName;
  final Future<void> Function() _stop;

  Future<void> stop() => _stop();
}

final class PortableBackupTransferPayload {
  const PortableBackupTransferPayload({
    required this.downloadUrl,
    this.uploadUrl,
    required this.transferCode,
    this.sourceDeviceId,
    this.sourceDeviceName,
  });

  final String downloadUrl;
  final String? uploadUrl;
  final String transferCode;
  final String? sourceDeviceId;
  final String? sourceDeviceName;
}

final class LocalBackupTransferServer {
  const LocalBackupTransferServer({
    required DatabaseSnapshotter snapshotter,
    required int schemaVersion,
    required String storageProfile,
    PortableBackupUploadHandler? uploadHandler,
    String? sourceDeviceId,
    String? sourceDeviceName,
  }) : _snapshotter = snapshotter,
       _schemaVersion = schemaVersion,
       _storageProfile = storageProfile,
       _uploadHandler = uploadHandler,
       _sourceDeviceId = sourceDeviceId,
       _sourceDeviceName = sourceDeviceName;

  final DatabaseSnapshotter _snapshotter;
  final int _schemaVersion;
  final String _storageProfile;
  final PortableBackupUploadHandler? _uploadHandler;
  final String? _sourceDeviceId;
  final String? _sourceDeviceName;

  Future<PortableBackupTransferSession> start() async {
    final transferCode = generatePortableBackupTransferCode();
    final createdAtUtc = DateTime.now().toUtc();
    final bytes = await CreateBackup(
      snapshotter: _snapshotter,
      schemaVersion: _schemaVersion,
      storageProfile: _storageProfile,
      protector: PortableBackupProtector(transferCode: transferCode),
    )(createdAtUtc: createdAtUtc);
    final token = _randomToken();
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final host = await _localIPv4Address();
    final fileName = buildAulaRaizPortableTransferFileName(createdAtUtc);
    final downloadUrl = Uri(
      scheme: 'http',
      host: host.address,
      port: server.port,
      path: '/aularaiz-transfer',
      queryParameters: <String, String>{'token': token},
    ).toString();
    final uploadUrl = _uploadHandler == null
        ? null
        : Uri(
            scheme: 'http',
            host: host.address,
            port: server.port,
            path: '/aularaiz-transfer-sync',
            queryParameters: <String, String>{'token': token},
          ).toString();

    final subscription = server.listen(
      (request) => _handleRequest(
        request: request,
        expectedToken: token,
        transferCode: transferCode,
        bytes: bytes,
        fileName: fileName,
      ),
    );

    return PortableBackupTransferSession(
      downloadUrl: downloadUrl,
      uploadUrl: uploadUrl,
      transferCode: transferCode,
      sourceDeviceId: _sourceDeviceId,
      sourceDeviceName: _sourceDeviceName,
      stop: () async {
        await subscription.cancel();
        await server.close(force: true);
      },
    );
  }

  Future<void> _handleRequest({
    required HttpRequest request,
    required String expectedToken,
    required String transferCode,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final response = request.response;
    final validToken = request.uri.queryParameters['token'] == expectedToken;
    if (!validToken) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    if (request.method == 'POST' &&
        request.uri.path == '/aularaiz-transfer-sync') {
      await _handleUpload(request: request, transferCode: transferCode);
      return;
    }

    if (request.method != 'GET' || request.uri.path != '/aularaiz-transfer') {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    response.headers.contentType = ContentType.binary;
    response.headers.set(
      'content-disposition',
      'attachment; filename="$fileName"',
    );
    response.headers.contentLength = bytes.length;
    response.add(bytes);
    await response.close();
  }

  Future<void> _handleUpload({
    required HttpRequest request,
    required String transferCode,
  }) async {
    final response = request.response;
    final handler = _uploadHandler;
    if (handler == null) {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }

    try {
      const maxBytes = 250 * 1024 * 1024;
      final builder = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in request) {
        total += chunk.length;
        if (total > maxBytes) {
          response.statusCode = HttpStatus.requestEntityTooLarge;
          await response.close();
          return;
        }
        builder.add(chunk);
      }

      final summary = await handler(
        bytes: builder.takeBytes(),
        transferCode: transferCode,
        sourceDeviceId: request.uri.queryParameters['deviceId']?.trim(),
        sourceDeviceName: request.uri.queryParameters['deviceName']?.trim(),
      );
      response.headers.contentType = ContentType.json;
      response.write(
        jsonEncode(<String, Object>{
          'inserted': summary.inserted,
          'updated': summary.updated,
          'skipped': summary.skipped,
        }),
      );
      await response.close();
    } on Object {
      response.statusCode = HttpStatus.badRequest;
      await response.close();
    }
  }

  Future<InternetAddress> _localIPv4Address() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && !address.isLinkLocal) return address;
      }
    }
    throw const SocketException(
      'No local Wi-Fi or LAN IPv4 address was found.',
    );
  }

  String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

String buildAulaRaizPortableTransferFileName(DateTime createdAtUtc) {
  final value = createdAtUtc.toUtc();
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return 'aularaiz-transfer-$year$month$day-$hour$minute$second.aularaiz';
}

String buildPortableBackupTransferQrPayload({
  required String downloadUrl,
  String? uploadUrl,
  required String transferCode,
  String? sourceDeviceId,
  String? sourceDeviceName,
}) {
  return Uri(
    scheme: 'aularaiz-transfer',
    host: 'local',
    queryParameters: <String, String>{
      'url': downloadUrl,
      if (uploadUrl != null && uploadUrl.trim().isNotEmpty)
        'uploadUrl': uploadUrl,
      'code': transferCode,
      if (sourceDeviceId != null && sourceDeviceId.trim().isNotEmpty)
        'deviceId': sourceDeviceId,
      if (sourceDeviceName != null && sourceDeviceName.trim().isNotEmpty)
        'deviceName': sourceDeviceName,
    },
  ).toString();
}

PortableBackupTransferPayload? parsePortableBackupTransferQrPayload(
  String value,
) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'aularaiz-transfer' || uri.host != 'local') {
    return null;
  }
  final downloadUrl = uri.queryParameters['url']?.trim();
  final uploadUrl = uri.queryParameters['uploadUrl']?.trim();
  final transferCode = uri.queryParameters['code']?.trim();
  if (downloadUrl == null ||
      downloadUrl.isEmpty ||
      transferCode == null ||
      transferCode.isEmpty) {
    return null;
  }
  return PortableBackupTransferPayload(
    downloadUrl: downloadUrl,
    uploadUrl: uploadUrl == null || uploadUrl.isEmpty ? null : uploadUrl,
    transferCode: transferCode,
    sourceDeviceId: uri.queryParameters['deviceId']?.trim(),
    sourceDeviceName: uri.queryParameters['deviceName']?.trim(),
  );
}
