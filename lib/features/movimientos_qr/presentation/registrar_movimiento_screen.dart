import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final Map<String, dynamic>? prestamoInicial;

  const RegistrarMovimientoScreen({
    super.key,
    required this.herramienta,
    this.tipoInicial,
    this.prestamoInicial,
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
  final _folioController = TextEditingController();
  final _picker = ImagePicker();
  
  final _qtyFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _responsableFocus = FocusNode();
  final _matriculaFocus = FocusNode();
  final _observacionesFocus = FocusNode();
  final _folioFocus = FocusNode();
  
  bool _isFolioValidating = false;
  String? _folioValidationResult;
  
  String _tipo = 'SALIDA';
  String _motivo = 'PRESTAMO_ALUMNO_PROFESOR';
  Uint8List? _firmaBytes;
  Uint8List? _ineBytes;
  bool _isIneVertical = false;
  bool _isSaving = false;
  Map<String, dynamic>? _currentProfile;
  String? _prestamoId;

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
    if (widget.prestamoInicial != null) {
      _tipo = 'ENTRADA';
      _motivo = 'DEVOLUCION_PRESTAMO';
      _responsableController.text = widget.prestamoInicial!['responsable_nombre'] ?? '';
      _matriculaController.text = widget.prestamoInicial!['matricula'] ?? '';
      final pendingQty = (widget.prestamoInicial!['cantidad'] as int) - (widget.prestamoInicial!['cantidad_devuelta'] as int);
      _qtyController.text = pendingQty.toString();
      _prestamoId = widget.prestamoInicial!['id'];
      _folioController.text = 'VALE-${widget.prestamoInicial!['folio'].toString().padLeft(6, '0')}';
      _folioValidationResult = 'VÁLIDO: Préstamo cargado.';
    } else {
      _obtenerPerfilUsuario();
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _responsableController.dispose();
    _matriculaController.dispose();
    _observacionesController.dispose();
    _folioController.dispose();
    
    _qtyFocus.dispose();
    _priceFocus.dispose();
    _responsableFocus.dispose();
    _matriculaFocus.dispose();
    _observacionesFocus.dispose();
    _folioFocus.dispose();
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
      debugPrint('Error obtaining profile: $e');
    }
  }

  Future<void> _validarFolio() async {
    final folioText = _folioController.text.trim();
    if (folioText.isEmpty) return;

    final regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(folioText);
    if (match == null) {
      setState(() {
        _folioValidationResult = 'El formato del folio no es válido.';
      });
      return;
    }
    final int? folioVal = int.tryParse(match.group(0)!);
    if (folioVal == null) {
      setState(() {
        _folioValidationResult = 'Folio no válido.';
      });
      return;
    }

    setState(() {
      _isFolioValidating = true;
      _folioValidationResult = null;
    });

    try {
      final client = SupabaseClientHelper.client;
      final queryRes = await client
          .from('prestamos')
          .select('*, herramientas(*)')
          .eq('folio', folioVal)
          .eq('herramienta_id', widget.herramienta['id'])
          .single();
      
      if (queryRes['estado'] == 'DEVUELTO') {
        setState(() {
          _folioValidationResult = 'Este préstamo ya ha sido devuelto por completo.';
          _prestamoId = null;
        });
        return;
      }

      setState(() {
        _prestamoId = queryRes['id'];
        _responsableController.text = queryRes['responsable_nombre'] ?? '';
        _matriculaController.text = queryRes['matricula'] ?? '';
        final pendingQty = (queryRes['cantidad'] as int) - (queryRes['cantidad_devuelta'] as int);
        _qtyController.text = pendingQty.toString();
        _folioValidationResult = 'VÁLIDO: Préstamo de ${queryRes['responsable_nombre']} encontrado.';
      });
    } catch (e) {
      setState(() {
        _folioValidationResult = 'No se encontró un préstamo activo para esta herramienta con ese folio.';
        _prestamoId = null;
      });
    } finally {
      setState(() {
        _isFolioValidating = false;
      });
    }
  }



  void _unfocusAll() {
    _qtyFocus.unfocus();
    _priceFocus.unfocus();
    _responsableFocus.unfocus();
    _matriculaFocus.unfocus();
    _observacionesFocus.unfocus();
    _folioFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _capturarIne(ImageSource source) async {
    _unfocusAll();
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final width = frame.image.width;
        final height = frame.image.height;
        
        setState(() {
          _ineBytes = bytes;
          _isIneVertical = height > width;
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
    _unfocusAll();
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 600),
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

  void _verIdentificacionCompleta() {
    if (_ineBytes == null) return;
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: const SizedBox(),
                title: const Text(
                  'Vista de Identificación',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _ineBytes!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Pellizca la imagen para hacer zoom',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // set version 4
    values[8] = (values[8] & 0x3f) | 0x80; // set variant 10
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<void> _procesarTransaccion() async {
    setState(() {
      _hasAttemptedSubmit = true;
    });

    if (_tipo == 'SALIDA') {
      if (_firmaBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La firma del responsable es obligatoria para registrar la salida')),
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
      int folio = 0;
      String dateStr = '';
      String? prestamoId = _prestamoId;
      int? prestamoFolio;

      final currentQty = int.parse(_qtyController.text);
      final responsable = _responsableController.text.trim();
      final matricula = _matriculaController.text.trim();
      final observaciones = _observacionesController.text.trim();

      if (_tipo == 'SALIDA') {
        if (_motivo == 'PRESTAMO_ALUMNO_PROFESOR') {
          final String signatureBase64 = base64Encode(_firmaBytes!);
          if (isOffline) {
            prestamoId = _generateUuid();
            prestamoFolio = DateTime.now().millisecondsSinceEpoch % 100000;
            
            final prestamoData = {
              'id': prestamoId,
              'herramienta_id': widget.herramienta['id'],
              'cantidad': currentQty,
              'responsable_nombre': responsable,
              'matricula': matricula,
              'firma_base64': signatureBase64,
              'observaciones': observaciones,
              'estado': 'ACTIVO',
              if (_ineBytes != null) 'offline_ine_base64': base64Encode(_ineBytes!),
            };
            await SyncService().encolarOperacion('prestamos', prestamoData);
            
            final movData = {
              'herramienta_id': widget.herramienta['id'],
              'tipo': _tipo,
              'motivo': _motivo,
              'cantidad': currentQty,
              'precio_unitario': 0.0,
              'responsable_nombre': responsable,
              'matricula': matricula,
              'entregado_por_nombre': entregadoPorNombre,
              'entregado_por_uid': entregadoPorUid,
              'observaciones': observaciones,
              'prestamo_id': prestamoId,
            };
            await SyncService().encolarOperacion('movimientos', movData);
            
            folio = DateTime.now().millisecondsSinceEpoch % 100000;
            dateStr = DateTime.now().toString().split('.')[0];
          } else {
            // Online
            final prestamoRes = await client.from('prestamos').insert({
              'herramienta_id': widget.herramienta['id'],
              'cantidad': currentQty,
              'responsable_nombre': responsable,
              'matricula': matricula,
              'firma_base64': signatureBase64,
              'observaciones': observaciones,
              'estado': 'ACTIVO',
            }).select('id, folio').single();
            
            prestamoId = prestamoRes['id'];
            prestamoFolio = prestamoRes['folio'];

            // Subir INE a Supabase Storage
            if (_ineBytes != null && prestamoId != null) {
              try {
                await client.storage.from('fotos_herramientas').uploadBinary(
                  'identificaciones/ine_$prestamoId.jpg',
                  _ineBytes!,
                  fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
                );
              } catch (e) {
                debugPrint('Error al subir INE al Storage: $e');
              }
            }

            final insertRes = await client.from('movimientos').insert({
              'herramienta_id': widget.herramienta['id'],
              'tipo': _tipo,
              'motivo': _motivo,
              'cantidad': currentQty,
              'precio_unitario': 0.0,
              'responsable_nombre': responsable,
              'matricula': matricula,
              'entregado_por_nombre': entregadoPorNombre,
              'entregado_por_uid': entregadoPorUid,
              'observaciones': observaciones,
              'prestamo_id': prestamoId,
            }).select('folio, fecha').single();

            folio = insertRes['folio'] ?? 0;
            final String fechaDb = insertRes['fecha'] ?? DateTime.now().toIso8601String();
            dateStr = DateTime.parse(fechaDb).toLocal().toString().split('.')[0];
          }
        } else {
          // Salida por otros motivos (Baja descompostura, Baja perdida)
          if (isOffline) {
            final movData = {
              'herramienta_id': widget.herramienta['id'],
              'tipo': _tipo,
              'motivo': _motivo,
              'cantidad': currentQty,
              'precio_unitario': 0.0,
              'responsable_nombre': responsable,
              'matricula': matricula,
              'entregado_por_nombre': entregadoPorNombre,
              'entregado_por_uid': entregadoPorUid,
              'observaciones': observaciones,
            };
            await SyncService().encolarOperacion('movimientos', movData);
            folio = DateTime.now().millisecondsSinceEpoch % 100000;
            dateStr = DateTime.now().toString().split('.')[0];
          } else {
            final insertRes = await client.from('movimientos').insert({
              'herramienta_id': widget.herramienta['id'],
              'tipo': _tipo,
              'motivo': _motivo,
              'cantidad': currentQty,
              'precio_unitario': 0.0,
              'responsable_nombre': responsable,
              'matricula': matricula,
              'entregado_por_nombre': entregadoPorNombre,
              'entregado_por_uid': entregadoPorUid,
              'observaciones': observaciones,
            }).select('folio, fecha').single();

            folio = insertRes['folio'] ?? 0;
            final String fechaDb = insertRes['fecha'] ?? DateTime.now().toIso8601String();
            dateStr = DateTime.parse(fechaDb).toLocal().toString().split('.')[0];
          }
        }
      } else {
        // ENTRADA
        if (_motivo == 'DEVOLUCION_PRESTAMO') {
          if (isOffline) {
            final movData = {
              'herramienta_id': widget.herramienta['id'],
              'tipo': _tipo,
              'motivo': _motivo,
              'cantidad': currentQty,
              'precio_unitario': 0.0,
              'responsable_nombre': responsable,
              'matricula': matricula,
              'entregado_por_nombre': entregadoPorNombre,
              'entregado_por_uid': entregadoPorUid,
              'observaciones': observaciones,
              'prestamo_id': prestamoId,
            };
            await SyncService().encolarOperacion('movimientos', movData);
            if (prestamoId != null) {
              await SyncService().encolarOperacion(
                'prestamos',
                {'cantidad_devuelta_increment': currentQty},
                op: 'update',
                id: prestamoId,
              );
            }
            folio = DateTime.now().millisecondsSinceEpoch % 100000;
            dateStr = DateTime.now().toString().split('.')[0];
          } else {
            // Online
            if (prestamoId != null) {
              final loan = await client.from('prestamos').select('cantidad, cantidad_devuelta').eq('id', prestamoId).single();
              final int cantTotal = loan['cantidad'] as int;
              final int cantDevueltaAnterior = loan['cantidad_devuelta'] as int;
              final int nuevaCantDevuelta = cantDevueltaAnterior + currentQty;
              final int capDevuelta = nuevaCantDevuelta > cantTotal ? cantTotal : nuevaCantDevuelta;
              
              String nuevoEstado = 'PARCIAL';
              if (capDevuelta >= cantTotal) {
                nuevoEstado = 'DEVUELTO';
              }
              
              await client.from('prestamos').update({
                'cantidad_devuelta': capDevuelta,
                'estado': nuevoEstado,
                'fecha_devolucion': nuevoEstado == 'DEVUELTO' ? DateTime.now().toIso8601String() : null,
              }).eq('id', prestamoId);

              // Eliminar INE del storage al devolverse
              if (nuevoEstado == 'DEVUELTO') {
                try {
                  await client.storage.from('fotos_herramientas').remove(['identificaciones/ine_$prestamoId.jpg']);
                } catch (e) {
                  debugPrint('Error al eliminar INE del Storage: $e');
                }
              }

              final insertRes = await client.from('movimientos').insert({
                'herramienta_id': widget.herramienta['id'],
                'tipo': _tipo,
                'motivo': _motivo,
                'cantidad': currentQty,
                'precio_unitario': 0.0,
                'responsable_nombre': responsable,
                'matricula': matricula,
                'entregado_por_nombre': entregadoPorNombre,
                'entregado_por_uid': entregadoPorUid,
                'observaciones': observaciones,
                'prestamo_id': prestamoId,
              }).select('folio, fecha').single();
              
              folio = insertRes['folio'] ?? 0;
              final String fechaDb = insertRes['fecha'] ?? DateTime.now().toIso8601String();
              dateStr = DateTime.parse(fechaDb).toLocal().toString().split('.')[0];
            } else {
              // Buscar préstamos activos más antiguos
              final activeLoans = await client
                  .from('prestamos')
                  .select('id, cantidad, cantidad_devuelta')
                  .eq('herramienta_id', widget.herramienta['id'])
                  .eq('matricula', matricula)
                  .neq('estado', 'DEVUELTO')
                  .order('fecha_prestamo', ascending: true);
                  
              if (activeLoans.isNotEmpty) {
                int remainingToDevolver = currentQty;
                String? lastUpdatedPrestamoId;
                
                for (final loan in activeLoans) {
                  if (remainingToDevolver <= 0) break;
                  
                  final String loanId = loan['id'];
                  final int cantTotal = loan['cantidad'] as int;
                  final int cantDevueltaAnterior = loan['cantidad_devuelta'] as int;
                  final int pending = cantTotal - cantDevueltaAnterior;
                  
                  int devolverAEsta = remainingToDevolver;
                  if (devolverAEsta > pending) {
                    devolverAEsta = pending;
                  }
                  
                  final int nuevaCantDevuelta = cantDevueltaAnterior + devolverAEsta;
                  String nuevoEstado = 'PARCIAL';
                  if (nuevaCantDevuelta >= cantTotal) {
                    nuevoEstado = 'DEVUELTO';
                  }
                  
                  await client.from('prestamos').update({
                    'cantidad_devuelta': nuevaCantDevuelta,
                    'estado': nuevoEstado,
                    'fecha_devolucion': nuevoEstado == 'DEVUELTO' ? DateTime.now().toIso8601String() : null,
                  }).eq('id', loanId);
                  
                  // Eliminar la INE del Storage para este préstamo
                  if (nuevoEstado == 'DEVUELTO') {
                    try {
                      await client.storage.from('fotos_herramientas').remove(['identificaciones/ine_$loanId.jpg']);
                    } catch (e) {
                      debugPrint('Error al eliminar INE del Storage para préstamo $loanId: $e');
                    }
                  }
                  
                  remainingToDevolver -= devolverAEsta;
                  lastUpdatedPrestamoId = loanId;
                }
                
                final insertRes = await client.from('movimientos').insert({
                  'herramienta_id': widget.herramienta['id'],
                  'tipo': _tipo,
                  'motivo': _motivo,
                  'cantidad': currentQty,
                  'precio_unitario': 0.0,
                  'responsable_nombre': responsable,
                  'matricula': matricula,
                  'entregado_por_nombre': entregadoPorNombre,
                  'entregado_por_uid': entregadoPorUid,
                  'observaciones': observaciones,
                  'prestamo_id': lastUpdatedPrestamoId,
                }).select('folio, fecha').single();
                
                folio = insertRes['folio'] ?? 0;
                final String fechaDb = insertRes['fecha'] ?? DateTime.now().toIso8601String();
                dateStr = DateTime.parse(fechaDb).toLocal().toString().split('.')[0];
              } else {
                // No se encontró préstamo, guardar como movimiento huérfano
                final insertRes = await client.from('movimientos').insert({
                  'herramienta_id': widget.herramienta['id'],
                  'tipo': _tipo,
                  'motivo': _motivo,
                  'cantidad': currentQty,
                  'precio_unitario': 0.0,
                  'responsable_nombre': responsable,
                  'matricula': matricula,
                  'entregado_por_nombre': entregadoPorNombre,
                  'entregado_por_uid': entregadoPorUid,
                  'observaciones': observaciones,
                }).select('folio, fecha').single();
                
                folio = insertRes['folio'] ?? 0;
                final String fechaDb = insertRes['fecha'] ?? DateTime.now().toIso8601String();
                dateStr = DateTime.parse(fechaDb).toLocal().toString().split('.')[0];
              }
            }
          }
        } else {
          // COMPRA_NUEVA
          if (isOffline) {
            final movData = {
              'herramienta_id': widget.herramienta['id'],
              'tipo': _tipo,
              'motivo': _motivo,
              'cantidad': currentQty,
              'precio_unitario': double.tryParse(_priceController.text) ?? 0.00,
              'responsable_nombre': responsable,
              'matricula': matricula,
              'entregado_por_nombre': entregadoPorNombre,
              'entregado_por_uid': entregadoPorUid,
              'observaciones': observaciones,
            };
            await SyncService().encolarOperacion('movimientos', movData);
            folio = DateTime.now().millisecondsSinceEpoch % 100000;
            dateStr = DateTime.now().toString().split('.')[0];
          } else {
            final insertRes = await client.from('movimientos').insert({
              'herramienta_id': widget.herramienta['id'],
              'tipo': _tipo,
              'motivo': _motivo,
              'cantidad': currentQty,
              'precio_unitario': double.tryParse(_priceController.text) ?? 0.00,
              'responsable_nombre': responsable,
              'matricula': matricula,
              'entregado_por_nombre': entregadoPorNombre,
              'entregado_por_uid': entregadoPorUid,
              'observaciones': observaciones,
            }).select('folio, fecha').single();

            folio = insertRes['folio'] ?? 0;
            final String fechaDb = insertRes['fecha'] ?? DateTime.now().toIso8601String();
            dateStr = DateTime.parse(fechaDb).toLocal().toString().split('.')[0];
          }
        }
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
                  Expanded(
                    child: Text(isOffline ? 'Entrada Guardada Local' : 'Entrada Registrada'),
                  ),
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
            pageFormat: PdfPageFormat(5.5 * PdfPageFormat.inch, 8.5 * PdfPageFormat.inch),
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'INVENTRA',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.blue800),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'VALE DE CONTROL DE HERRAMIENTAS',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 1, color: PdfColors.grey300),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'FOLIO: VALE-${prestamoFolio != null ? prestamoFolio.toString().padLeft(6, '0') : folio.toString().padLeft(6, '0')}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.red800),
                      ),
                      pw.Text(
                        'Fecha: $dateStr',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text('DETALLES DEL MOVIMIENTO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue800)),
                  pw.SizedBox(height: 4),
                  pw.Bullet(text: 'Tipo: $_tipo', style: const pw.TextStyle(fontSize: 8)),
                  pw.Bullet(text: 'Motivo: $_motivo', style: const pw.TextStyle(fontSize: 8)),
                  pw.Bullet(text: 'Herramienta: ${widget.herramienta['nombre']}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Bullet(text: 'Cantidad: ${_qtyController.text} ${widget.herramienta['unidades_medida']?['abreviatura'] ?? 'Pza'}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Bullet(text: 'Responsable: $responsable', style: const pw.TextStyle(fontSize: 8)),
                  pw.Bullet(text: 'Matrícula/ID: $matricula', style: const pw.TextStyle(fontSize: 8)),
                  pw.Bullet(text: 'Entregado por: $entregadoPorNombre', style: const pw.TextStyle(fontSize: 8)),
                  if (observaciones.isNotEmpty)
                    pw.Bullet(text: 'Observaciones: $observaciones', style: const pw.TextStyle(fontSize: 8)),
                  if (prestamoId != null) ...[
                    pw.SizedBox(height: 10),
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: 'INVENTRA_PRESTAMO:$prestamoId',
                            width: 85,
                            height: 85,
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'ESCANEAR PARA DEVOLUCIÓN',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  ],
                  pw.Spacer(),
                  pw.Divider(thickness: 1, color: PdfColors.grey300),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Firma del Responsable:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            width: 160,
                            height: 80,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Center(
                              child: pw.Image(pw.MemoryImage(_firmaBytes!), fit: pw.BoxFit.contain),
                            ),
                          ),
                        ],
                      ),
                      if (_ineBytes != null)
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Identificación (INE/Credencial):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              width: 160,
                              height: 100,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                              child: pw.Center(
                                child: _isIneVertical
                                    ? pw.Transform.rotate(
                                        angle: pi / 2,
                                        child: pw.Image(pw.MemoryImage(_ineBytes!), fit: pw.BoxFit.contain),
                                      )
                                    : pw.Image(pw.MemoryImage(_ineBytes!), fit: pw.BoxFit.contain),
                              ),
                            ),
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
          _mostrarDialogoValeGenerado(pdfBytes, folio, isOffline, prestamoFolio: prestamoFolio);
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

  void _mostrarDialogoValeGenerado(Uint8List pdfBytes, int folio, bool isOffline, {int? prestamoFolio}) {
    final displayFolio = prestamoFolio ?? folio;
    final folioStr = displayFolio.toString().padLeft(6, '0');

    // Capturamos el Navigator del State ANTES de abrir el diálogo para
    // evitar el problema de shadowing de contextos y garantizar que la
    // referencia sea válida después de que el diálogo se cierre.
    final rootNavigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(isOffline ? 'Vale Offline: VALE-$folioStr' : 'Vale Foliado: VALE-$folioStr'),
            ),
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
              // Cerramos el diálogo con su propio contexto
              Navigator.pop(dialogCtx);

              if (kIsWeb) {
                await PdfDownloadHelper.downloadPdf(
                  bytes: pdfBytes,
                  filename: 'Vale_Digital_VALE_$folioStr.pdf',
                );
                // rootNavigator es estable porque fue capturado antes del diálogo
                rootNavigator.popUntil((route) => route.isFirst);
              } else {
                // Usamos await para que la lógica posterior (popUntil) se ejecute
                // sin importar si el usuario presiona Atrás o cualquier otro método
                // para salir del visor del PDF.
                await rootNavigator.push(
                  MaterialPageRoute(
                    builder: (context) => PdfViewerScreen(
                      title: 'Vale Digital VALE-$folioStr',
                      pdfBytes: pdfBytes,
                    ),
                  ),
                );
                rootNavigator.popUntil((route) => route.isFirst);
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
                // Cerramos el diálogo y navegamos directo al Dashboard
                Navigator.pop(dialogCtx);
                rootNavigator.popUntil((route) => route.isFirst);
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final formWidget = Form(
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
                                    ? (kIsWeb
                                        ? Image.network(
                                            widget.herramienta['foto_url'],
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 70,
                                              height: 70,
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28),
                                            ),
                                          )
                                        : CachedNetworkImage(
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
                                          ))
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
                        onChanged: (v) => setState(() {
                          _motivo = v!;
                          if (_motivo != 'DEVOLUCION_PRESTAMO') {
                            _prestamoId = null;
                            _folioController.clear();
                            _folioValidationResult = null;
                            if (_currentProfile != null) {
                              _responsableController.text = _currentProfile!['nombre_completo'] ?? '';
                              _matriculaController.text = _currentProfile!['matricula'] ?? SupabaseClientHelper.client.auth.currentUser?.id ?? '';
                            }
                          }
                        }),
                      ),
                      const SizedBox(height: 16),

                      if (_tipo == 'ENTRADA' && _motivo == 'DEVOLUCION_PRESTAMO') ...[
                        TextFormField(
                          controller: _folioController,
                          focusNode: _folioFocus,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            labelText: 'Folio del Préstamo (VALE-XXXX)',
                            prefixIcon: const Icon(Icons.receipt_long_rounded),
                            suffixIcon: _isFolioValidating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : _folioValidationResult == null
                                    ? IconButton(
                                        icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.blue),
                                        onPressed: _validarFolio,
                                      )
                                    : _folioValidationResult!.startsWith('VÁLIDO')
                                        ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                                        : IconButton(
                                            icon: const Icon(Icons.error_outline_rounded, color: Colors.red),
                                            onPressed: _validarFolio,
                                          ),
                            helperText: _folioValidationResult,
                            helperStyle: TextStyle(
                              color: _folioValidationResult?.startsWith('VÁLIDO') == true ? Colors.green : Colors.red,
                              fontWeight: _folioValidationResult?.startsWith('VÁLIDO') == true ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _folioValidationResult = null;
                              _prestamoId = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _qtyController,
                        focusNode: _qtyFocus,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Cantidad',
                          suffixText: widget.herramienta['unidades_medida']?['abreviatura'] ?? 'Pza',
                        ),
                        validator: (v) {
                          if (v == null || int.tryParse(v) == null || int.parse(v) <= 0) {
                            return 'Por favor, ingrese una cantidad mayor a 0';
                          }
                          if (_tipo == 'SALIDA') {
                            final stock = widget.herramienta['stock'] as int? ?? 0;
                            final qty = int.parse(v);
                            if (qty > stock) {
                              return 'Stock insuficiente (Disponible: $stock)';
                            }
                          }
                          return null;
                        },
                      ),
                      if (_tipo == 'ENTRADA' && _motivo == 'COMPRA_NUEVA') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          focusNode: _priceFocus,
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
                        focusNode: _responsableFocus,
                        enabled: _prestamoId == null && (_tipo == 'SALIDA' || _motivo == 'DEVOLUCION_PRESTAMO'),
                        decoration: InputDecoration(
                          labelText: _prestamoId != null
                              ? 'Responsable (Préstamo original)'
                              : (_tipo == 'ENTRADA' && _motivo == 'COMPRA_NUEVA'
                                  ? 'Responsable (Automático)'
                                  : 'Nombre del Responsable'),
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Por favor, ingrese el nombre del responsable'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _matriculaController,
                        focusNode: _matriculaFocus,
                        enabled: _prestamoId == null && (_tipo == 'SALIDA' || _motivo == 'DEVOLUCION_PRESTAMO'),
                        decoration: InputDecoration(
                          labelText: _prestamoId != null
                              ? 'Matrícula / ID (Préstamo original)'
                              : (_tipo == 'ENTRADA' && _motivo == 'COMPRA_NUEVA'
                                  ? 'Matrícula / ID (Automático)'
                                  : 'Matrícula / ID'),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Por favor, ingrese la matrícula o ID'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _observacionesController,
                        focusNode: _observacionesFocus,
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
                                    GestureDetector(
                                      onTap: _verIdentificacionCompleta,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(11),
                                        child: Image.memory(_ineBytes!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                                      ),
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
                );

                if (constraints.maxWidth > 650) {
                  return SingleChildScrollView(
                    physics: _isScrollEnabled ? null : const NeverScrollableScrollPhysics(),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 700),
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: colors.outline.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: formWidget,
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  return SingleChildScrollView(
                    physics: _isScrollEnabled ? null : const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: formWidget,
                  );
                }
              },
            ),
          ),
          ],
        ),
      ),
    );
  }
}
