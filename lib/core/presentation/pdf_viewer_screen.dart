import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PdfViewerScreen extends StatelessWidget {
  final String title;
  final Uint8List? pdfBytes;
  final Future<Uint8List> Function(PdfPageFormat format)? buildPdf;

  const PdfViewerScreen({
    super.key,
    required this.title,
    this.pdfBytes,
    this.buildPdf,
  }) : assert(pdfBytes != null || buildPdf != null, 'Debe proporcionar pdfBytes o buildPdf');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: PdfPreview(
        build: pdfBytes != null ? (_) => pdfBytes! : buildPdf!,
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: '${title.replaceAll(' ', '_')}.pdf',
      ),
    );
  }
}
