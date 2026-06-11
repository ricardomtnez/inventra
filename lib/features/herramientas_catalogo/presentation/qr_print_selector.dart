import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/config/app_config.dart';

class QrPrintSelectorScreen extends StatefulWidget {
  final List<Map<String, dynamic>> herramientas;

  const QrPrintSelectorScreen({super.key, required this.herramientas});

  @override
  State<QrPrintSelectorScreen> createState() => _QrPrintSelectorScreenState();
}

class _QrPrintSelectorScreenState extends State<QrPrintSelectorScreen> {
  double _qrSize = 100.0; // Dimensión dinámica modificable (alto/ancho)
  int _columns = 3;      // Cantidad de columnas en el PDF por fila

  Future<void> _generarEImprimirPdf() async {
    final pdf = pw.Document();
    
    // Obtener los datos del QR como imagen para el PDF
    final qrDataList = <Map<String, dynamic>>[];
    for (var h in widget.herramientas) {
      final qrUrl = '${AppConfig.publicWebUrl}?id=${h['id']}';
      qrDataList.add({
        'nombre': h['nombre'],
        'url': qrUrl,
      });
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'Planilla de Códigos QR - Inventario'),
            pw.SizedBox(height: 20),
            pw.GridView(
              crossAxisCount: _columns,
              childAspectRatio: 1.0,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: qrDataList.map((qr) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(qr['nombre'], style: const pw.TextStyle(fontSize: 8), maxLines: 1),
                      pw.SizedBox(height: 5),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qr['url'],
                        width: _qrSize - 20,
                        height: _qrSize - 20,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impresión de QR')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('Configuración de Cuadrícula', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Slider de tamaño del QR
                  Row(
                    children: [
                      const Text('Dimensión: '),
                      Expanded(
                        child: Slider(
                          value: _qrSize,
                          min: 50.0,
                          max: 180.0,
                          onChanged: (v) => setState(() => _qrSize = v),
                        ),
                      ),
                      Text('${_qrSize.toInt()} px'),
                    ],
                  ),
                  
                  // Slider de columnas
                  Row(
                    children: [
                      const Text('Columnas: '),
                      Expanded(
                        child: Slider(
                          value: _columns.toDouble(),
                          min: 2.0,
                          max: 5.0,
                          divisions: 3,
                          onChanged: (v) => setState(() => _columns = v.toInt()),
                        ),
                      ),
                      Text('$_columns col'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: widget.herramientas.length,
              itemBuilder: (context, index) {
                final h = widget.herramientas[index];
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(h['nombre'], style: const TextStyle(fontSize: 10), maxLines: 1),
                      const SizedBox(height: 4),
                      QrImageView(
                        data: '${AppConfig.publicWebUrl}?id=${h['id']}',
                        size: _qrSize - 30 > 0 ? _qrSize - 30 : 20,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _generarEImprimirPdf,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.print_rounded),
              label: const Text('Imprimir Planilla optimizada'),
            ),
          )
        ],
      ),
    );
  }
}
