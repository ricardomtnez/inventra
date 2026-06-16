import 'dart:typed_data';
import 'package:printing/printing.dart';

class PdfDownloadHelper {
  static Future<void> downloadPdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }

  static Future<void> downloadBytes({
    required Uint8List bytes,
    required String filename,
    String mimeType = 'application/octet-stream',
  }) async {
    throw UnsupportedError('Descarga de bytes no soportada en móvil.');
  }
}
