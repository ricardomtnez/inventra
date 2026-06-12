import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../../../core/supabase/supabase_client.dart';

class PublicToolDetailScreen extends StatefulWidget {
  final String herramientaId;

  const PublicToolDetailScreen({super.key, required this.herramientaId});

  @override
  State<PublicToolDetailScreen> createState() => _PublicToolDetailScreenState();
}

class _PublicToolDetailScreenState extends State<PublicToolDetailScreen> {
  Map<String, dynamic>? _herramienta;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDetalles();
  }

  Future<void> _cargarDetalles() async {
    try {
      final client = SupabaseClientHelper.client;
      final res = await client
          .from('herramientas')
          .select('*, ubicaciones(nombre)')
          .eq('id', widget.herramientaId)
          .single();

      setState(() {
        _herramienta = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se encontró la herramienta especificada o el código QR es inválido.';
        _isLoading = false;
      });
    }
  }

  Future<void> _imprimirFichaTecnica() async {
    if (_herramienta == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Generando Ficha Técnica...'),
          ],
        ),
      ),
    );

    try {
      final doc = pw.Document();
      final specs = _herramienta!['especificaciones'] as Map<String, dynamic>? ?? {};
      final String? fotoUrl = _herramienta!['foto_url'];
      
      Uint8List? imageBytes;
      if (fotoUrl != null && fotoUrl.isNotEmpty) {
        try {
          final res = await http.get(Uri.parse(fotoUrl));
          if (res.statusCode == 200) {
            imageBytes = res.bodyBytes;
          }
        } catch (e) {
          // Ignorar errores de descarga (por ejemplo, CORS en Web)
        }
      }

      final dateStr = DateTime.now().toLocal().toString().split(' ')[0];

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(35),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Banner superior de encabezado
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF0F172A), // Slate 900
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'FICHA TÉCNICA DE EQUIPO',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Control de Inventario - INVENTRA',
                            style: const pw.TextStyle(
                              color: PdfColors.grey300,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Generado: $dateStr',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Distribución de contenido
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Columna izquierda: Imagen y Disponibilidad
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        children: [
                          pw.Container(
                            height: 180,
                            width: double.infinity,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                            ),
                            child: imageBytes != null
                                ? pw.ClipRRect(
                                    horizontalRadius: 6,
                                    verticalRadius: 6,
                                    child: pw.Image(
                                      pw.MemoryImage(imageBytes),
                                      fit: pw.BoxFit.cover,
                                    ),
                                  )
                                : pw.Center(
                                    child: pw.Text(
                                      'Sin Imagen',
                                      style: const pw.TextStyle(color: PdfColors.grey500),
                                    ),
                                  ),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: pw.BoxDecoration(
                              color: _herramienta!['stock'] > 0
                                  ? const PdfColor.fromInt(0xFFECFDF5) // Emerald 50
                                  : const PdfColor.fromInt(0xFFFEF2F2), // Red 50
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              border: pw.Border.all(
                                color: _herramienta!['stock'] > 0
                                    ? const PdfColor.fromInt(0xFFA7F3D0) // Emerald 200
                                    : const PdfColor.fromInt(0xFFFCA5A5), // Red 200
                              ),
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                _herramienta!['stock'] > 0
                                    ? 'ESTADO: DISPONIBLE'
                                    : 'ESTADO: SIN STOCK',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                  color: _herramienta!['stock'] > 0
                                      ? const PdfColor.fromInt(0xFF047857) // Emerald 700
                                      : const PdfColor.fromInt(0xFFB91C1C), // Red 700
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),

                    // Columna derecha: Detalles técnicos
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            _herramienta!['nombre'].toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor.fromInt(0xFF0F172A),
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Divider(color: PdfColors.grey200),
                          pw.SizedBox(height: 8),
                          _buildPdfRow('Marca', specs['marca']?.toString() ?? 'No especificada'),
                          _buildPdfRow('Modelo', specs['modelo']?.toString() ?? 'No especificado'),
                          _buildPdfRow('N/S', specs['n_serie']?.toString() ?? 'No especificado'),
                          _buildPdfRow(
                            'Ubicación',
                            _herramienta!['ubicaciones']?['nombre']?.toString() ?? 'No especificada',
                          ),
                          _buildPdfRow('Disponibles', '${_herramienta!['stock']} unidades'),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 32),

                // Sección de descripción
                pw.Text(
                  'DESCRIPCIÓN DEL EQUIPO',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: const PdfColor.fromInt(0xFF0F172A),
                  ),
                ),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                pw.Text(
                  _herramienta!['descripcion'] ?? 'Sin descripción disponible.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                ),
                pw.Spacer(),

                // Pie de página
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Ficha técnica autorizada por el Departamento de Laboratorio.',
                      style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
                    ),
                    pw.Text(
                      'INVENTRA Web',
                      style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
      }

      await Printing.layoutPdf(
        name: 'Ficha_Tecnica_${_herramienta!['nombre']}',
        onLayout: (format) async => doc.save(),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar Ficha Técnica: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CustomPaint().child != null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final specs = _herramienta?['especificaciones'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta de Herramienta', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 550),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Imagen de la herramienta
                            if (_herramienta!['foto_url'] != null)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                child: CachedNetworkImage(
                                  imageUrl: _herramienta!['foto_url'],
                                  height: 250,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const SizedBox(
                                    height: 250,
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) => const SizedBox(
                                    height: 250,
                                    child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                child: const Icon(Icons.handyman_rounded, size: 64, color: Colors.grey),
                              ),
                            
                            // Detalles
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _herramienta!['nombre'].toUpperCase(),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Badge de disponibilidad
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _herramienta!['stock'] > 0 
                                            ? Colors.green.shade50 
                                            : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _herramienta!['stock'] > 0 
                                              ? Colors.green.shade200 
                                              : Colors.red.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        _herramienta!['stock'] > 0 
                                            ? 'Disponible (${_herramienta!['stock']} piezas)' 
                                            : 'Sin Existencias',
                                        style: TextStyle(
                                          color: _herramienta!['stock'] > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Especificaciones
                                  const Text(
                                    'ESPECIFICACIONES',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                                  ),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  
                                  _buildSpecItem(Icons.branding_watermark_outlined, 'Marca', specs['marca']?.toString().isNotEmpty == true ? specs['marca'] : 'No especificada'),
                                  _buildSpecItem(Icons.settings_outlined, 'Modelo', specs['modelo']?.toString().isNotEmpty == true ? specs['modelo'] : 'No especificado'),
                                  _buildSpecItem(Icons.tag_rounded, 'Número de Serie', specs['n_serie']?.toString().isNotEmpty == true ? specs['n_serie'] : 'No especificado'),
                                  _buildSpecItem(Icons.location_on_outlined, 'Ubicación Física', _herramienta!['ubicaciones']?['nombre'] ?? 'No especificada'),
                                  
                                  const SizedBox(height: 24),
                                  
                                  const Text(
                                    'DESCRIPCIÓN',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                                  ),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    _herramienta!['descripcion']?.toString().isNotEmpty == true 
                                        ? _herramienta!['descripcion'] 
                                        : 'Sin descripción disponible.',
                                    style: const TextStyle(fontSize: 15, height: 1.4),
                                  ),
                                  
                                  const SizedBox(height: 32),
                                  
                                  // Botón de Impresión
                                  ElevatedButton.icon(
                                    onPressed: _imprimirFichaTecnica,
                                    icon: const Icon(Icons.print_rounded),
                                    label: const Text('Descargar / Imprimir Ficha Técnica', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colors.primary,
                                      foregroundColor: colors.onPrimary,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
