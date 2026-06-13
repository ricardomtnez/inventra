import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image_picker/image_picker.dart';
import 'signature_pad.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/presentation/pdf_viewer_screen.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/utils/pdf_download_helper.dart';

class RegistrarMovimientoScreen extends StatefulWidget {
  final Map<String, dynamic> herramienta;
  final String? tipoInicial;

  const RegistrarMovimientoScreen({
    super.key,
    required this.herramienta,
    this.tipoInicial,
  });

  @override
  State<RegistrarMovimientoScreen> createState() => _RegistrarMovimientoScreenState();
}

class _RegistrarMovimientoScreenState extends State<RegistrarMovimientoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController(text: '0.00');
  final _responsableController = TextEditingController();
  final _matriculaController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _picker = ImagePicker();
  
  String _tipo = 'SALIDA';
  String _motivo = 'PRESTAMO_ALUMNO_PROFESOR';
  Uint8List? _firmaBytes;
  Uint8List? _ineBytes;
  bool _isSaving = false;
  Map<String, dynamic>? _currentProfile;

  bool _isScrollEnabled = true;
  bool _hasAttemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    if (widget.tipoInicial != null) {
      _tipo = widget.tipoInicial!;
      if (_tipo == 'ENTRADA') {
        _motivo = 'DEVOLUCION_PRESTAMO';
      } else {
        _motivo = 'PRESTAMO_ALUMNO_PROFESOR';
      }
    }
    _obtenerPerfilUsuario();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _responsableController.dispose();
    _matriculaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _obtenerPerfilUsuario() async {
    try {
      final user = SupabaseClientHelper.client.auth.currentUser;
      if (user != null) {
        final profile = await SupabaseClientHelper.client
            .from('perfiles')
            .select('nombre_completo, correo, matricula')
            .eq('id', user.id)
            .single();
        setState(() {
          _currentProfile = profile;
          if (_tipo == 'ENTRADA') {
            _responsableController.text = profile['nombre_completo'] ?? '';
            _matriculaController.text = profile['matricula'] ?? user.id;
          }
        });
      }
    } catch (e) {
      debugPrint('Error obteniendo perfil: $e');
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
    setState(() {
      _hasAttemptedSubmit = true;
    });

    if (_tipo == 'SALIDA') {
      if (_firmaBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firma obligatoria para registrar la salida (Recuerde presionar ACEPTAR para guardar la firma)')),
        );
        return;
      }
    }

    if (!_formKey.currentState!.validate()) return;
    
    if (_tipo == 'SALIDA') {
      if (_ineBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Identificación (INE/Credencial) obligatoria para registrar la salida')),
        );
        return;
      }
    }
    
    setState(() => _isSaving = true);

    try {
      final client = SupabaseClientHelper.client;
      final user = client.auth.currentUser;
      
      String? entregadoPorNombre;
      String? entregadoPorUid;
      if (_tipo == 'SALIDA' && user != null) {
        entregadoPorNombre = _currentProfile?['nombre_completo'] ?? user.email ?? 'Administrador';
        entregadoPorUid = user.id;
      }

      final isOffline = ConnectivityService().isOffline.value;
      int folio;
      String dateStr;

      if (isOffline) {
        final movData = {
          'herramienta_id': widget.herramienta['id'],
          'tipo': _tipo,
          'motivo': _motivo,
          'cantidad': int.parse(_qtyController.text),
          'precio_unitario': _motivo == 'COMPRA_NUEVA' ? (double.tryParse(_priceController.text) ?? 0.00) : 0.00,
          'responsable_nombre': _responsableController.text.trim(),
          'matricula': _matriculaController.text.trim(),
          'entregado_por_nombre': entregadoPorNombre,
          'entregado_por_uid': entregadoPorUid,
          'observaciones': _observacionesController.text.trim(),
        };
        await SyncService().encolarMovimiento(movData);
        folio = DateTime.now().millisecondsSinceEpoch % 100000;
        dateStr = DateTime.now().toString().split('.')[0];
      } else {
        // Registrar Movimiento en Base de Datos
        final insertRes = await client.from('movimientos').insert({
          'herramienta_id': widget.herramienta['id'],
          'tipo': _tipo,
          'motivo': _motivo,
          'cantidad': int.parse(_qtyController.text),
          'precio_unitario': _motivo == 'COMPRA_NUEVA' ? (double.tryParse(_priceController.text) ?? 0.00) : 0.00,
          'responsable_nombre': _responsableController.text.trim(),
          'matricula': _matriculaController.text.trim(),
          'entregado_por_nombre': entregadoPorNombre,
          'entregado_por_uid': entregadoPorUid,
          'observaciones': _observacionesController.text.trim(),
        }).select('folio, fecha').single();

        folio = insertRes['folio'] ?? 0;
        final String fechaDb = insertRes['fecha'] ?? DateTime.now().toIso8601String();
        dateStr = DateTime.parse(fechaDb).toLocal().toString().split('.')[0];
      }

      if (_tipo == 'ENTRADA') {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  Text(isOffline ? 'Entrada Guardada Local' : 'Entrada Registrada'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isOffline
                      ? 'Se registraron ${_qtyController.text} unidades de la herramienta localmente. Se sincronizarán al recuperar conexión.'
                      : 'Se registraron ${_qtyController.text} unidades de la herramienta exitosamente.'),
                  const SizedBox(height: 8),
                  Text(isOffline ? 'Folio temporal: E-${folio.toString().padLeft(6, '0')}' : 'Folio del movimiento: E-${folio.toString().padLeft(6, '0')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  Text('Responsable: ${_responsableController.text}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  Text('Fecha/Hora: $dateStr', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
              actions: [
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // cerrar diálogo
                      Navigator.pop(context, true); // regresar al catálogo
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Finalizar'),
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        // Generar PDF del Vale Digital para SALIDA
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
                  pw.Text('Responsable (Recibe): ${_responsableController.text}'),
                  pw.Text('Matrícula/ID: ${_matriculaController.text}'),
                  pw.Text('Entregado por (Operador): $entregadoPorNombre'),
                  if (_observacionesController.text.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 5),
                    pw.Text('Observaciones: ${_observacionesController.text.trim()}'),
                  ],
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
          _mostrarDialogoValeGenerado(pdfBytes, folio, isOffline);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _mostrarDialogoValeGenerado(Uint8List pdfBytes, int folio, bool isOffline) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text(isOffline ? 'Vale Offline: VALE-${folio.toString().padLeft(6, '0')}' : 'Vale Foliado: VALE-${folio.toString().padLeft(6, '0')}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOffline
                  ? 'Transacción guardada localmente de forma segura.'
                  : 'La transacción ha sido guardada y foliada exitosamente.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isOffline
                  ? 'El vale PDF se ha generado en tu dispositivo. Al recuperar señal, los datos de inventario se sincronizarán automáticamente con la nube.'
                  : 'Puedes imprimir o descargar el vale directamente en este dispositivo, o compartirlo con el responsable sin consumir espacio en la nube.',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context); // cerrar diálogo
              if (kIsWeb) {
                await PdfDownloadHelper.downloadPdf(
                  bytes: pdfBytes,
                  filename: 'Vale_Digital_VALE_${folio.toString().padLeft(6, '0')}.pdf',
                );
                if (context.mounted) {
                  Navigator.pop(context, true); // regresar al listado
                }
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfViewerScreen(
                      title: 'Vale Digital VALE-${folio.toString().padLeft(6, '0')}',
                      pdfBytes: pdfBytes,
                    ),
                  ),
                ).then((_) {
                  if (context.mounted) {
                    Navigator.pop(context, true); // regresar al listado
                  }
                });
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(kIsWeb ? Icons.download_rounded : Icons.picture_as_pdf_rounded),
            label: Text(
              kIsWeb ? 'DESCARGAR VALE DIGITAL (PDF)' : 'VER VALE DIGITAL (PDF)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
    final colors = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Transacción')),
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: _isScrollEnabled ? null : const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Tarjeta de detalles del material/herramienta (Estándar de la industria)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colors.outline.withValues(alpha: 0.15), width: 1),
                        ),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : Colors.grey.shade50,
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: widget.herramienta['foto_url'] != null
                                    ? CachedNetworkImage(
                                        imageUrl: widget.herramienta['foto_url'],
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey.shade200,
                                          child: const Center(
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28),
                                        ),
                                      )
                                    : Container(
                                        width: 70,
                                        height: 70,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.handyman_rounded, color: Colors.grey, size: 28),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.herramienta['nombre'] ?? 'Sin nombre',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            widget.herramienta['ubicaciones']?['nombre'] ?? 'Sin ubicación',
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (widget.herramienta['stock'] as int? ?? 0) > 0
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Stock actual: ${widget.herramienta['stock'] ?? 0} ${widget.herramienta['unidades_medida']?['abreviatura'] ?? 'Pza'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: (widget.herramienta['stock'] as int? ?? 0) > 0
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (widget.tipoInicial != null)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: _tipo == 'ENTRADA'
                                ? Colors.green.withValues(alpha: 0.1)
                                : colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _tipo == 'ENTRADA'
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : colors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _tipo == 'ENTRADA' ? Icons.login_rounded : Icons.logout_rounded,
                                color: _tipo == 'ENTRADA' ? Colors.green.shade700 : colors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _tipo == 'ENTRADA' ? 'REGISTRANDO ENTRADA / DEVOLUCIÓN' : 'REGISTRANDO SALIDA / PRÉSTAMO',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _tipo == 'ENTRADA' ? Colors.green.shade800 : colors.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // Botones de alternancia Entrada / Salida (Segmented premium)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _tipo = 'SALIDA';
                                      _motivo = 'PRESTAMO_ALUMNO_PROFESOR';
                                      _responsableController.clear();
                                      _matriculaController.clear();
                                      _hasAttemptedSubmit = false;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _tipo == 'SALIDA' ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _tipo == 'SALIDA'
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'REGISTRAR SALIDA',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _tipo == 'SALIDA' ? colors.primary : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _tipo = 'ENTRADA';
                                      _motivo = 'DEVOLUCION_PRESTAMO';
                                      _hasAttemptedSubmit = false;
                                      if (_currentProfile != null) {
                                        _responsableController.text = _currentProfile!['nombre_completo'] ?? '';
                                        _matriculaController.text = _currentProfile!['matricula'] ?? SupabaseClientHelper.client.auth.currentUser?.id ?? '';
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _tipo == 'ENTRADA' ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _tipo == 'ENTRADA'
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'REGISTRAR ENTRADA',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _tipo == 'ENTRADA' ? colors.primary : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

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
                        decoration: InputDecoration(
                          labelText: 'Cantidad',
                          suffixText: widget.herramienta['unidades_medida']?['abreviatura'] ?? 'Pza',
                        ),
                        validator: (v) => (v == null || int.tryParse(v) == null || int.parse(v) <= 0)
                            ? 'Por favor, ingrese una cantidad mayor a 0'
                            : null,
                      ),
                      if (_tipo == 'ENTRADA' && _motivo == 'COMPRA_NUEVA') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: r'Precio Unitario de Compra ($)'),
                          validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) < 0)
                              ? 'Por favor, ingrese un precio unitario válido'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _responsableController,
                        enabled: _tipo == 'SALIDA',
                        decoration: InputDecoration(
                          labelText: _tipo == 'ENTRADA' ? 'Responsable (Automático)' : 'Nombre del Responsable',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Por favor, ingrese el nombre del responsable'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _matriculaController,
                        enabled: _tipo == 'SALIDA',
                        decoration: InputDecoration(
                          labelText: _tipo == 'ENTRADA' ? 'Matrícula / ID (Automático)' : 'Matrícula / ID',
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Por favor, ingrese la matrícula o ID'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _observacionesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones (Opcional)',
                          prefixIcon: Icon(Icons.rate_review_outlined),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      if (_tipo == 'SALIDA') ...[
                        // Firma Box
                        SignaturePad(
                          title: 'Firma del Responsable',
                          initialBytes: _firmaBytes,
                          onSave: (bytes) {
                            setState(() => _firmaBytes = bytes);
                          },
                          onDragStart: () {
                            setState(() => _isScrollEnabled = false);
                          },
                          onDragEnd: () {
                            setState(() => _isScrollEnabled = true);
                          },
                        ),
                        if (_hasAttemptedSubmit && _firmaBytes == null) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              'Firma obligatoria para registrar la salida',
                              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                            ),
                          ),
                        ],
                        
                        // Identificación / INE Box
                        const SizedBox(height: 24),
                        const Text(
                          'Identificación del Responsable (INE / Credencial) - Obligatorio',
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
                      ],
                      
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _procesarTransaccion,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _tipo == 'ENTRADA' ? Colors.green.shade700 : null,
                          foregroundColor: _tipo == 'ENTRADA' ? Colors.white : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _tipo == 'ENTRADA' ? 'Registrar Entrada' : 'Registrar Salida y Generar Vale',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
