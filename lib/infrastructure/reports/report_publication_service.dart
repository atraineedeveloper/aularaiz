import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:printing/printing.dart';

final class ReportPublicationService {
  const ReportPublicationService();

  Future<bool> publishPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null) return false;

      final file = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: fileName,
      );
      await file.saveTo(location.path);
      return true;
    }

    await Printing.sharePdf(bytes: bytes, filename: fileName);
    return true;
  }
}
