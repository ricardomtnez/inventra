import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
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
  
  String _tipo = 'SALIDA';
  String _motivo = 'PRESTAMO_ALUMNO_PROFESOR';
  Uint8List? _firmaBytes;
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

      // 2. Generar PDF del Vale Digital
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, text: 'UNIVERSIDAD - VALE DE CONTROL DE HERRAMIENTAS'),
                pw.SizedBox(height: 20),
                pw.Text('Tipo: $_tipo'),
                pw.Text('Motivo: $_motivo'),
                pw.Text('Cantidad: ${_qtyController.text}'),
                pw.Text('Herramienta: ${widget.herramienta['nombre']}'),
                pw.Text('Responsable: ${_responsableController.text}'),
                pw.Text('Matrícula/ID: ${_matriculaController.text}'),
                pw.Text('Fecha: ${DateTime.now().toLocal()}'),
                pw.SizedBox(height: 40),
                pw.Text('Firma del Responsable:'),
                pw.SizedBox(height: 10),
                pw.Image(pw.MemoryImage(_firmaBytes!), width: 150, height: 80),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final pathPdf = 'vales/$filePrefix.pdf';
      
      // 3. Subir Vale Digital PDF
      await client.storage.from('vales_pdf').uploadBinary(pathPdf, pdfBytes);
      final pdfUrl = client.storage.from('vales_pdf').getPublicUrl(pathPdf);

      // 4. Registrar Movimiento en Base de Datos (Esto dispara el Trigger contable)
      await client.from('movimientos').insert({
        'herramienta_id': widget.herramienta['id'],
        'tipo': _tipo,
        'motivo': _motivo,
        'cantidad': int.parse(_qtyController.text),
        'precio_unitario': double.tryParse(_priceController.text) ?? 0.00,
        'responsable_nombre': _responsableController.text.trim(),
        'matricula': _matriculaController.text.trim(),
        'firma_url': firmaUrl,
        'vale_pdf_url': pdfUrl,
      });

      if (mounted) {
        _mostrarLinkPdf(pdfUrl);
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

  void _mostrarLinkPdf(String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('¡Movimiento Registrado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Se ha generado el vale digital en PDF con la firma integrada.'),
            const SizedBox(height: 16),
            SelectableText(
              url,
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Abrir PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final whatsappUrl = 'https://wa.me/?text=Vale%20de%20herramienta:%20$url';
                      launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Compartir'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // cerrar diálogo
              Navigator.pop(context, true); // regresar al listado
            },
            child: const Text('Finalizar'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
