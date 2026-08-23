import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

final class ReportPublicationService {
  const ReportPublicationService();

  Future<bool> publishPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (_usesDesktopSaveDialog) {
      return _saveWithDialog(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/pdf',
        extension: 'pdf',
        typeLabel: 'PDF',
      );
    }

    await Printing.sharePdf(bytes: bytes, filename: fileName);
    return true;
  }

  Future<bool> publishFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String extension,
    required String typeLabel,
  }) async {
    if (_usesDesktopSaveDialog) {
      return _saveWithDialog(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        extension: extension,
        typeLabel: typeLabel,
      );
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('File publication is not supported here.');
    }

    return _shareTemporaryFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  bool get _usesDesktopSaveDialog =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<bool> _saveWithDialog({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String extension,
    required String typeLabel,
  }) async {
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [
        XTypeGroup(label: typeLabel, extensions: [extension]),
      ],
    );
    if (location == null) return false;

    final file = XFile.fromData(bytes, mimeType: mimeType, name: fileName);
    await file.saveTo(location.path);
    return true;
  }

  Future<bool> _shareTemporaryFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final temporaryRoot = await getTemporaryDirectory();
    final shareDirectory = Directory(
      '${temporaryRoot.path}${Platform.pathSeparator}aularaiz-share',
    );

    if (await shareDirectory.exists()) {
      await shareDirectory.delete(recursive: true);
    }
    await shareDirectory.create(recursive: true);

    final temporaryFile = File(
      '${shareDirectory.path}${Platform.pathSeparator}$fileName',
    );
    await temporaryFile.writeAsBytes(bytes, flush: true);

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'AulaRaíz',
          files: [XFile(temporaryFile.path, mimeType: mimeType)],
          fileNameOverrides: [fileName],
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    } finally {
      if (await shareDirectory.exists()) {
        await shareDirectory.delete(recursive: true);
      }
    }
  }
}
