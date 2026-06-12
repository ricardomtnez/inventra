import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/config/app_config.dart';
import '../../../core/presentation/pdf_viewer_screen.dart';

class QrPrintSelectorScreen extends StatefulWidget {
  final List<Map<String, dynamic>> herramientas;

  const QrPrintSelectorScreen({super.key, required this.herramientas});

  @override
  State<QrPrintSelectorScreen> createState() => _QrPrintSelectorScreenState();
}

class _QrPrintSelectorScreenState extends State<QrPrintSelectorScreen> {
  double _qrSize = 90.0; // Dimensión dinámica en PDF
  int _columns = 4;      // Cantidad de columnas por fila en la planilla
  final Map<String, int> _cantidades = {};

  @override
  void initState() {
    super.initState();
    // Inicializar cada herramienta con 1 copia
    for (var h in widget.herramientas) {
      final id = h['id'] as String;
      _cantidades[id] = 1;
    }
  }

  int get _totalEstampas {
    return _cantidades.values.fold(0, (sum, val) => sum + val);
  }

  Future<void> _generarPlanillaPDF() async {
    final pdf = pw.Document();
    
    // Construir la lista plana de estampas con las copias solicitadas
    final List<Map<String, String>> listaEstampas = [];
    for (var h in widget.herramientas) {
      final id = h['id'] as String;
      final cantidad = _cantidades[id] ?? 0;
      if (cantidad > 0) {
        final qrUrl = '${AppConfig.publicWebUrl}?id=$id';
        for (int i = 0; i < cantidad; i++) {
          listaEstampas.add({
            'nombre': h['nombre'] as String,
            'url': qrUrl,
          });
        }
      }
    }

    if (listaEstampas.isEmpty) return;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return [
            pw.GridView(
              crossAxisCount: _columns,
              childAspectRatio: 1.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: listaEstampas.map((est) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // El QR ocupa la mayor parte de la estampa
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: est['url']!,
                            width: _qrSize - 16,
                            height: _qrSize - 16,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      // Nombre minimalista en letra muy pequeña abajo para ahorrar espacio
                      pw.Text(
                        est['nombre']!.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                        textAlign: pw.TextAlign.center,
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

    // Navegar al visor de PDF integrado
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            title: 'Planilla de Estampas QR',
            buildPdf: (format) async => pdf.save(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Impresión QR', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Configuración superior
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Parámetros de la Planilla',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  
                  // Slider de tamaño del QR
                  Row(
                    children: [
                      const Text('Dimensión: ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _qrSize,
                          min: 60.0,
                          max: 150.0,
                          onChanged: (v) => setState(() => _qrSize = v),
                        ),
                      ),
                      Text('${_qrSize.toInt()} px', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  
                  // Slider de columnas
                  Row(
                    children: [
                      const Text('Columnas: ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _columns.toDouble(),
                          min: 3.0,
                          max: 6.0,
                          divisions: 3,
                          onChanged: (v) => setState(() => _columns = v.toInt()),
                        ),
                      ),
                      Text('$_columns col', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Listado de herramientas
          Expanded(
            child: widget.herramientas.isEmpty
                ? const Center(child: Text('No hay herramientas para imprimir.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: widget.herramientas.length,
                    itemBuilder: (context, index) {
                      final h = widget.herramientas[index];
                      final id = h['id'] as String;
                      final cantidad = _cantidades[id] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Row(
                            children: [
                              // Miniatura / Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: h['foto_url'] != null
                                    ? CachedNetworkImage(
                                        imageUrl: h['foto_url'],
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 44,
                                        height: 44,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.handyman_rounded, color: Colors.grey, size: 20),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Detalles
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h['nombre'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Stock: ${h['stock']} ${h['unidades_medida']?['abreviatura'] ?? 'Pza'}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Selector numérico
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                                    color: cantidad > 0 ? colors.primary : Colors.grey,
                                    onPressed: cantidad > 0
                                        ? () => setState(() => _cantidades[id] = cantidad - 1)
                                        : null,
                                  ),
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 24),
                                    child: Text(
                                      '$cantidad',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                                    color: colors.primary,
                                    onPressed: () => setState(() => _cantidades[id] = cantidad + 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Botón inferior
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                )
              ],
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _totalEstampas > 0 ? _generarPlanillaPDF : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text(
                  'GENERAR PLANILLA DE ESTAMPAS ($_totalEstampas)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
