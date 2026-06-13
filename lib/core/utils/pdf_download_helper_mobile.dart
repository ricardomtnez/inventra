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
}
