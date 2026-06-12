import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image_picker/image_picker.dart';
import 'firma_canvas.dart';
import '../../../core/supabase/supabase_client.dart';

class RegistrarMovimientoScreen extends StatefulWidget {
  final Map<String, dynamic> herramienta;

  const RegistrarMovimientoScreen({super.key, required this.herramienta});

  @override
  State<RegistrarMovimientoScreen> createState() => _RegistrarMovimientoScreenState();
}

class _RegistrarMovimientoScreenState extends State<RegistrarMovimientoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController(text: '0.00');
  final _responsableController = TextEditingController();
  final _matriculaController = TextEditingController();
  final _picker = ImagePicker();
  
  String _tipo = 'SALIDA';
  String _motivo = 'PRESTAMO_ALUMNO_PROFESOR';
  Uint8List? _firmaBytes;
  Uint8List? _ineBytes;
  bool _isSaving = false;

  Future<void> _capturarFirma() async {
    final bytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (context) => const FirmaCanvasScreen()),
    );
    if (bytes != null) {
      setState(() => _firmaBytes = bytes);
    }
  }

  Future<void> _capturarIne(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _ineBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar identificación: $e')),
        );
      }
    }
  }

  void _mostrarOpcionesIne() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Tomar Foto con Cámara'),
              onTap: () {
                Navigator.pop(context);
                _capturarIne(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Seleccionar de Galería'),
              onTap: () {
                Navigator.pop(context);
                _capturarIne(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarTransaccion() async {
    if (!_formKey.currentState!.validate() || _firmaBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formulario incompleto o firma faltante')),
      );
      return;
    }
    setState(() => _isSaving = true);

    try {
      final client = SupabaseClientHelper.client;
      final filePrefix = DateTime.now().millisecondsSinceEpoch;

      // 1. Subir firma digital
      final pathFirma = 'firmas/$filePrefix.png';
      await client.storage.from('vales_pdf').uploadBinary(pathFirma, _firmaBytes!);
      final firmaUrl = client.storage.from('vales_pdf').getPublicUrl(pathFirma);

      // 2. Registrar Movimiento en Base de Datos primero (para obtener el folio generado automáticamente)
      final insertRes = await client.from('movimientos').insert({
        'herramienta_id': widget.herramienta['id'],
        'tipo': _tipo,
        'motivo': _motivo,
        'cantidad': int.parse(_qtyController.text),
        'precio_unitario': double.tryParse(_priceController.text) ?? 0.00,
        'responsable_nombre': _responsableController.text.trim(),
        'matricula': _matriculaController.text.trim(),
        'firma_url': firmaUrl,
        'vale_pdf_url': null, // No se aloja en Supabase Storage
      }).select('folio, fecha').single();

      final int folio = insertRes['folio'] ?? 0;
      final String fechaDb = insertRes['fecha'] ?? DateTime.now().toIso8601String();
      final dateStr = DateTime.parse(fechaDb).toLocal().toString().split('.')[0];

      // 4. Generar PDF del Vale Digital con el Folio obtenido y la INE (si existe)
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, text: 'UNIVERSIDAD - VALE DE CONTROL DE HERRAMIENTAS'),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('FOLIO: VALE-${folio.toString().padLeft(6, '0')}', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text('Fecha/Hora: $dateStr'),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text('Tipo de movimiento: $_tipo'),
                pw.Text('Motivo: $_motivo'),
                pw.Text('Cantidad: ${_qtyController.text}'),
                pw.Text('Herramienta: ${widget.herramienta['nombre']}'),
                pw.Text('Responsable: ${_responsableController.text}'),
                pw.Text('Matrícula/ID: ${_matriculaController.text}'),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Firma del Responsable:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 10),
                        pw.Image(pw.MemoryImage(_firmaBytes!), width: 150, height: 80),
                      ],
                    ),
                    if (_ineBytes != null)
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Identificación (INE/Credencial):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Image(pw.MemoryImage(_ineBytes!), width: 150, height: 80),
                        ],
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();

      if (mounted) {
        _mostrarDialogoValeGenerado(pdfBytes, folio);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _mostrarDialogoValeGenerado(Uint8List pdfBytes, int folio) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text('Vale Foliado: VALE-${folio.toString().padLeft(6, '0')}'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La transacción ha sido guardada y foliada exitosamente.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Puedes imprimir o descargar el vale directamente en este dispositivo, o compartirlo con el responsable sin consumir espacio en la nube.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Printing.layoutPdf(
                      name: 'Vale_${folio.toString().padLeft(6, '0')}',
                      onLayout: (format) async => pdfBytes,
                    );
                  },
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Imprimir'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Printing.sharePdf(
                      bytes: pdfBytes,
                      filename: 'Vale_${folio.toString().padLeft(6, '0')}.pdf',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Compartir'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context); // cerrar diálogo
                Navigator.pop(context, true); // regresar al listado
              },
              child: const Text('Finalizar'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: Text('Transacción: ${widget.herramienta['nombre']}')),
        body: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _tipo,
                        decoration: const InputDecoration(labelText: 'Tipo de Transacción'),
                        items: const [
                          DropdownMenuItem(value: 'ENTRADA', child: Text('ENTRADA')),
                          DropdownMenuItem(value: 'SALIDA', child: Text('SALIDA')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _tipo = v!;
                            _motivo = _tipo == 'ENTRADA' ? 'DEVOLUCION_PRESTAMO' : 'PRESTAMO_ALUMNO_PROFESOR';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _motivo,
                        decoration: const InputDecoration(labelText: 'Motivo del Movimiento'),
                        items: _tipo == 'ENTRADA'
                            ? const [
                                DropdownMenuItem(value: 'COMPRA_NUEVA', child: Text('COMPRA NUEVA')),
                                DropdownMenuItem(value: 'DEVOLUCION_PRESTAMO', child: Text('DEVOLUCIÓN DE PRÉSTAMO')),
                              ]
                            : const [
                                DropdownMenuItem(value: 'PRESTAMO_ALUMNO_PROFESOR', child: Text('PRÉSTAMO A ALUMNO/PROFESOR')),
                                DropdownMenuItem(value: 'BAJA_DESCOMPOSTURA', child: Text('BAJA POR DESCOMPOSTURA')),
                                DropdownMenuItem(value: 'BAJA_PERDIDA', child: Text('BAJA POR PÉRDIDA')),
                              ],
                        onChanged: (v) => setState(() => _motivo = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cantidad'),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Cantidad inválida' : null,
                      ),
                      if (_motivo == 'COMPRA_NUEVA') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: r'Precio Unitario de Compra ($)'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _responsableController,
                        decoration: const InputDecoration(labelText: 'Nombre del Responsable'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _matriculaController,
                        decoration: const InputDecoration(labelText: 'Matrícula / ID'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 24),
                      
                      // Firma Box
                      const Text(
                        'Firma del Responsable',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _firmaBytes != null
                            ? Image.memory(_firmaBytes!, fit: BoxFit.contain)
                            : Center(
                                child: TextButton.icon(
                                  onPressed: _capturarFirma,
                                  icon: const Icon(Icons.gesture_rounded),
                                  label: const Text('Capturar Firma del Alumno/Profesor'),
                                ),
                              ),
                      ),
                      
                      // Identificación / INE Box
                      const SizedBox(height: 24),
                      const Text(
                        'Identificación del Responsable (INE / Credencial) - Opcional',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _ineBytes != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Image.memory(_ineBytes!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.redAccent,
                                      radius: 18,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
                                        onPressed: () => setState(() => _ineBytes = null),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: TextButton.icon(
                                  onPressed: _mostrarOpcionesIne,
                                  icon: const Icon(Icons.camera_alt_rounded),
                                  label: const Text('Capturar Foto / Cargar INE o Credencial'),
                                ),
                              ),
                      ),
                      
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _procesarTransaccion,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Registrar Transacción y Generar Vale'),
                      )
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
