import 'dart:typed_data';

class PdfDownloadHelper {
  static Future<void> downloadPdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    throw UnsupportedError('Plataforma no soportada para descarga directa.');
  }
}
