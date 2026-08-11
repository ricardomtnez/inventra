import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' show pi;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../auth/data/auth_repository.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../herramientas_catalogo/data/herramientas_repository.dart';
import '../../../core/presentation/pdf_viewer_screen.dart';
import '../../../core/utils/pdf_download_helper.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class HistorialMovimientosScreen extends StatefulWidget {
  const HistorialMovimientosScreen({super.key});

  @override
  State<HistorialMovimientosScreen> createState() =>
      _HistorialMovimientosScreenState();
}

class _HistorialMovimientosScreenState
    extends State<HistorialMovimientosScreen> {
  final _repository = HerramientasRepository();
  final _authRepository = AuthRepository();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _movimientos = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _timeFilter = 'semana'; // 'semana' (default), 'hoy', 'mes', 'todos'
  String _typeFilter = 'todos'; // 'todos', 'entrada', 'salida', 'devuelto'

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _movimientosFiltrados {
    final now = DateTime.now();

    DateTime? inicioFiltro;
    if (_timeFilter == 'hoy') {
      inicioFiltro = DateTime(now.year, now.month, now.day);
    } else if (_timeFilter == 'semana') {
      final weekday = now.weekday; // 1 = Lunes, 7 = Domingo
      final lunes = now.subtract(Duration(days: weekday - 1));
      inicioFiltro = DateTime(lunes.year, lunes.month, lunes.day);
    } else if (_timeFilter == 'mes') {
      inicioFiltro = DateTime(now.year, now.month, 1);
    }

    return _movimientos.where((m) {
      // 1. Filtro por Fecha
      if (inicioFiltro != null) {
        final fechaStr = m['fecha'] as String?;
        if (fechaStr != null) {
          final dt = DateTime.tryParse(fechaStr)?.toLocal();
          if (dt != null && dt.isBefore(inicioFiltro)) {
            return false;
          }
        }
      }

      // 2. Filtro por Tipo / Estado
      final tipo = m['tipo'] as String? ?? '';
      final isDevuelto =
          m['prestamos'] != null && m['prestamos']['estado'] == 'DEVUELTO';

      if (_typeFilter == 'entrada' && tipo != 'ENTRADA') return false;
      if (_typeFilter == 'salida' && tipo != 'SALIDA') return false;
      if (_typeFilter == 'devuelto' && !isDevuelto) return false;

      // 3. Filtro por Búsqueda
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final folio = (m['folio'] ?? 0).toString();
        final folioStr = tipo == 'ENTRADA' ? 'e-$folio' : 'vale-$folio';
        final toolName =
            (m['herramientas']?['nombre'] as String? ?? '').toLowerCase();
        final responsable =
            (m['responsable_nombre'] as String? ?? '').toLowerCase();
        final matricula = (m['matricula'] as String? ?? '').toLowerCase();
        final motivo = (m['motivo'] as String? ?? '').toLowerCase();

        final match = folioStr.contains(query) ||
            toolName.contains(query) ||
            responsable.contains(query) ||
            matricula.contains(query) ||
            motivo.contains(query);

        if (!match) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _cargarHistorial() async {
    if (_movimientos.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final list = await _repository.obtenerMovimientos();
      setState(() {
        _movimientos = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar historial: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _reconstruirVale(Map<String, dynamic> m) async {
    final prestamo = m['prestamos'];
    if (prestamo == null) return;

    final firmaBase64 = prestamo['firma_base64'] as String?;
    if (firmaBase64 == null || firmaBase64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay firma digital registrada en este préstamo para reconstruir el vale.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Uint8List firmaBytes = base64Decode(firmaBase64);
      final client = SupabaseClientHelper.client;
      Uint8List? ineBytes;
      bool isIneVertical = false;

      final estado = prestamo['estado'] as String? ?? 'ACTIVO';

      String? observacionesDevolucion;
      if (estado == 'DEVUELTO') {
        final localReturnMovs = _movimientos.where(
          (mov) =>
              mov['prestamo_id'] == prestamo['id'] && mov['tipo'] == 'ENTRADA',
        );
        if (localReturnMovs.isNotEmpty) {
          observacionesDevolucion = localReturnMovs
              .map((mov) => mov['observaciones'] as String?)
              .where((obs) => obs != null && obs.isNotEmpty)
              .join(', ');
        }
      }

      // Buscar si existen más préstamos asociados a este mismo grupo_id
      final String? grupoId = prestamo['grupo_id'] as String?;
      List<Map<String, dynamic>> groupLoans = [];
      if (grupoId != null && grupoId.isNotEmpty) {
        try {
          final groupRes = await client
              .from('prestamos')
              .select('*, herramientas(*, unidades_medida(abreviatura))')
              .eq('grupo_id', grupoId);
          groupLoans = List<Map<String, dynamic>>.from(groupRes);
        } catch (e) {
          debugPrint('Error fetching group loans for PDF: $e');
        }
      }

      // Si el préstamo no está devuelto (por tanto, su INE sigue existiendo en Storage)
      // intentamos descargarla para pintarla en el vale reconstruido.
      if (estado != 'DEVUELTO') {
        try {
          final String path = 'identificaciones/ine_${prestamo['id']}.jpg';
          final responseBytes = await client.storage
              .from('fotos_herramientas')
              .download(path);
          ineBytes = responseBytes;

          final codec = await ui.instantiateImageCodec(ineBytes);
          final frame = await codec.getNextFrame();
          isIneVertical = frame.image.height > frame.image.width;
        } catch (_) {
          // Si el archivo ya no está o falla la red, simplemente ignoramos
          // y el PDF se generará sin la sección de la INE.
        }
      }

      final pdf = pw.Document();

      final folio = prestamo['folio'] ?? 0;
      final folioStr = (grupoId != null && grupoId.length >= 8)
          ? grupoId.substring(0, 8).toUpperCase()
          : folio.toString().padLeft(6, '0');

      final String dateStr;
      if (prestamo['fecha_prestamo'] != null) {
        final dt = DateTime.parse(prestamo['fecha_prestamo']).toLocal();
        dateStr = dt.toString().split('.')[0];
      } else {
        dateStr = DateTime.now().toString().split('.')[0];
      }

      final toolName =
          m['herramientas']?['nombre'] ?? 'Herramienta no identificada';
      final abrv =
          m['herramientas']?['unidades_medida']?['abreviatura'] ?? 'Pza';
      final responsable = prestamo['responsable_nombre'] ?? 'Sin asignar';
      final matricula = prestamo['matricula'] ?? 'Sin matrícula';
      final entregadoPorNombre = m['entregado_por_nombre'] ?? 'Administrador';
      final cantidad = prestamo['cantidad'] ?? m['cantidad'] ?? 1;
      final observaciones = prestamo['observaciones'] ?? '';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            5.5 * PdfPageFormat.inch,
            8.5 * PdfPageFormat.inch,
          ),
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Text(
                        'INVENTRA',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 18,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ),
                    pw.Center(
                      child: pw.Text(
                        'VALE DE CONTROL DE HERRAMIENTAS',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                    if (estado == 'DEVUELTO') ...[
                      pw.SizedBox(height: 6),
                      pw.Center(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.green50,
                            border: pw.Border.all(
                              color: PdfColors.green700,
                              width: 1.2,
                            ),
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(4),
                            ),
                          ),
                          child: pw.Text(
                            'DEVUELTO / ENTREGADO',
                            style: pw.TextStyle(
                              color: PdfColors.green700,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 1, color: PdfColors.grey300),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'FOLIO: VALE-$folioStr',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                            color: PdfColors.red800,
                          ),
                        ),
                        pw.Text(
                          'Fecha: $dateStr',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'DETALLES DEL MOVIMIENTO:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Bullet(
                      text: 'Tipo: SALIDA',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Bullet(
                      text: 'Motivo: ${m['motivo'].toString().replaceAll('_', ' ')}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Bullet(
                      text: 'Responsable: $responsable',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Bullet(
                      text: 'Matrícula/ID: $matricula',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Bullet(
                      text: 'Entregado por: $entregadoPorNombre',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    if (observaciones.isNotEmpty)
                      pw.Bullet(
                        text: 'Observaciones de Préstamo: $observaciones',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    if (observacionesDevolucion != null &&
                        observacionesDevolucion.isNotEmpty)
                      pw.Bullet(
                        text:
                            'Observaciones de Devolución: $observacionesDevolucion',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    pw.SizedBox(height: 10),
                    if (groupLoans.length > 1) ...[
                      pw.Text('EQUIPOS EN VALE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue800)),
                      pw.SizedBox(height: 4),
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text('Herramienta', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text('Cant.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
                              ),
                            ],
                          ),
                          ...groupLoans.map((gl) {
                            final t = gl['herramientas'] ?? {};
                            final q = gl['cantidad'] ?? 1;
                            final ab = t['unidades_medida']?['abreviatura'] ?? 'Pza';
                            return pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(t['nombre'] ?? '', style: const pw.TextStyle(fontSize: 8)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text('$q $ab', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                    ] else ...[
                      pw.Bullet(
                        text: 'Herramienta: $toolName',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Bullet(
                        text: 'Cantidad: $cantidad $abrv',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.SizedBox(height: 10),
                    ],
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: (grupoId != null && grupoId.isNotEmpty)
                                ? 'INVENTRA_VALE:$grupoId'
                                : 'INVENTRA_PRESTAMO:${prestamo['id']}',
                            width: 85,
                            height: 85,
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'ESCANEAR PARA DEVOLUCIÓN',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 7,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                            pw.Text(
                              'Firma del Responsable (Digital):',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              width: 160,
                              height: 80,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: PdfColors.grey300,
                                  width: 0.5,
                                ),
                                borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(4),
                                ),
                              ),
                              child: pw.Center(
                                child: pw.Image(
                                  pw.MemoryImage(firmaBytes),
                                  fit: pw.BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (ineBytes != null)
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Identificación (INE/Credencial):',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 8,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Container(
                                width: 160,
                                height: 100,
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                    color: PdfColors.grey300,
                                    width: 0.5,
                                  ),
                                  borderRadius: const pw.BorderRadius.all(
                                    pw.Radius.circular(4),
                                  ),
                                ),
                                child: pw.Center(
                                  child: isIneVertical
                                      ? pw.Transform.rotate(
                                          angle: pi / 2,
                                          child: pw.Image(
                                            pw.MemoryImage(ineBytes),
                                            fit: pw.BoxFit.contain,
                                          ),
                                        )
                                      : pw.Image(
                                          pw.MemoryImage(ineBytes),
                                          fit: pw.BoxFit.contain,
                                        ),
                                ),
                              ),
                            ],
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
        setState(() => _isLoading = false);
        if (kIsWeb) {
          await PdfDownloadHelper.downloadPdf(
            bytes: pdfBytes,
            filename: 'Vale_Digital_VALE_$folioStr.pdf',
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerScreen(
                title: 'Vale Digital VALE-$folioStr',
                pdfBytes: pdfBytes,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reconstruir el vale: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _mostrarDetalleMovimiento(Map<String, dynamic> m) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tipo = m['tipo'] as String;
    final folio = m['folio'] ?? 0;
    final folioStr = tipo == 'ENTRADA'
        ? 'E-${folio.toString().padLeft(6, '0')}'
        : 'VALE-${folio.toString().padLeft(6, '0')}';
    final fecha = DateTime.parse(m['fecha']).toLocal().toString().split('.')[0];
    final toolName =
        m['herramientas']?['nombre'] ?? 'Herramienta no identificada';
    final hasBeenEdited = m['observacion_edicion'] != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  folioStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tipo == 'ENTRADA'
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tipo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: tipo == 'ENTRADA'
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            _buildDetailRow('Herramienta:', toolName),
            _buildDetailRow('Cantidad:', '${m['cantidad']} uds'),
            _buildDetailRow(
              'Motivo:',
              m['motivo'].toString().replaceAll('_', ' '),
            ),
            if (m['precio_unitario'] != null &&
                (double.tryParse(m['precio_unitario'].toString()) ?? 0.0) > 0.0)
              _buildDetailRow(
                'Precio Unitario:',
                '\$${double.parse(m['precio_unitario'].toString()).toStringAsFixed(2)}',
              ),
            _buildDetailRow(
              'Responsable:',
              m['responsable_nombre'] ?? 'Sin asignar',
            ),
            _buildDetailRow(
              'Matrícula / ID:',
              m['matricula'] ?? 'Sin matrícula',
            ),
            if (m['prestamos'] != null)
              _buildDetailRow(
                'Estado Préstamo:',
                m['prestamos']['estado'] ?? 'ACTIVO',
              ),
            _buildDetailRow('Fecha / Hora:', fecha),

            if (m['observaciones'] != null &&
                m['observaciones'].toString().trim().isNotEmpty)
              _buildDetailRow(
                tipo == 'SALIDA' && (m['motivo'] == 'PRESTAMO_ALUMNO_PROFESOR' || m['motivo'] == 'PRESTAMO')
                    ? 'Observaciones Préstamo:'
                    : 'Observaciones:',
                m['observaciones'],
              ),

            if (m['prestamos'] != null &&
                m['prestamos']['estado'] == 'DEVUELTO') ...[
              (() {
                final localReturnMovs = _movimientos.where(
                  (mov) =>
                      mov['prestamo_id'] == m['prestamos']['id'] &&
                      mov['tipo'] == 'ENTRADA',
                );
                final returnObs = localReturnMovs
                    .map((mov) => mov['observaciones'] as String?)
                    .where((obs) => obs != null && obs.isNotEmpty)
                    .join(', ');
                if (returnObs.isNotEmpty) {
                  return _buildDetailRow(
                    'Observaciones Devolución:',
                    returnObs,
                  );
                }
                return const SizedBox.shrink();
              })(),
            ],

            if (hasBeenEdited) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Registro Editado (Auditoría)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Motivo: ${m['observacion_edicion']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (m['fecha_edicion'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Fecha de corrección: ${DateTime.parse(m['fecha_edicion']).toLocal().toString().split('.')[0]}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (m['prestamos'] != null) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // cerrar sheet
                  _reconstruirVale(m);
                },
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Ver Vale Digital (PDF)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Botón de Editar (sólo para administradores)
            if (_authRepository.isAdmin)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Cerrar bottom sheet
                  _mostrarDialogoEdicion(m);
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Corregir / Editar Registro'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEdicion(Map<String, dynamic> m) {
    final formKey = GlobalKey<FormState>();
    final qtyController = TextEditingController(text: m['cantidad'].toString());
    final obsController = TextEditingController();
    String motivo = m['motivo'] as String;
    if (motivo == 'PRESTAMO_ALUMNO_PROFESOR') {
      motivo = 'PRESTAMO';
    }
    final tipo = m['tipo'] as String;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text('Editar Movimiento'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Herramienta: ${m['herramientas']?['nombre'] ?? 'N/A'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                        ),
                        validator: (v) =>
                            (v == null ||
                                int.tryParse(v) == null ||
                                int.parse(v) <= 0)
                            ? 'Ingresa una cantidad mayor a 0'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: motivo,
                        decoration: const InputDecoration(labelText: 'Motivo'),
                        items: tipo == 'ENTRADA'
                            ? const [
                                DropdownMenuItem(
                                  value: 'COMPRA_NUEVA',
                                  child: Text('COMPRA NUEVA'),
                                ),
                                DropdownMenuItem(
                                  value: 'DEVOLUCION_PRESTAMO',
                                  child: Text('DEVOLUCIÓN DE PRÉSTAMO'),
                                ),
                              ]
                            : const [
                                DropdownMenuItem(
                                  value: 'PRESTAMO',
                                  child: Text('PRÉSTAMO'),
                                ),
                                DropdownMenuItem(
                                  value: 'BAJA_DESCOMPOSTURA',
                                  child: Text('BAJA POR DESCOMPOSTURA'),
                                ),
                                DropdownMenuItem(
                                  value: 'BAJA_PERDIDA',
                                  child: Text('BAJA POR PÉRDIDA'),
                                ),
                              ],
                        onChanged: (v) => setDialogState(() => motivo = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: obsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Motivo de Corrección (Auditoría)',
                          hintText: 'Explica el motivo de la corrección...',
                        ),
                        validator: (v) => (v == null || v.trim().length < 8)
                            ? 'Explica detalladamente (mínimo 8 caracteres)'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);

                    nav.pop(); // Cerrar diálogo

                    setState(() => _isLoading = true);
                    try {
                      await _repository.actualizarMovimiento(
                        id: m['id'],
                        cantidad: int.parse(qtyController.text),
                        motivo: motivo,
                        observacionEdicion: obsController.text.trim(),
                      );
                      _cargarHistorial();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Movimiento corregido y stock actualizado.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      _cargarHistorial();
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red,
                                size: 28,
                              ),
                              SizedBox(width: 12),
                              Text('Error de Inventario'),
                            ],
                          ),
                          content: Text(
                            e.toString().contains('Stock insuficiente')
                                ? 'No se puede guardar: la corrección causaría que el stock disponible de la herramienta sea menor a cero.'
                                : 'No se pudo aplicar la corrección: ${e.toString()}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.bgDarkSecondary,
        border: Border(
          bottom: BorderSide(color: AppColors.bgDarkBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de Búsqueda
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bgDarkBorder, width: 1),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: AppTextStyles.bodySm.copyWith(color: AppColors.textPrimaryDark),
              decoration: InputDecoration(
                hintText: 'Buscar por herramienta, responsable o folio...',
                hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textMutedDark),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMutedDark),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMutedDark),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Chips de Filtro por Fecha y Tipo
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Fecha:',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMutedDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                _buildTimeFilterChip('Esta Semana', 'semana'),
                const SizedBox(width: 6),
                _buildTimeFilterChip('Hoy', 'hoy'),
                const SizedBox(width: 6),
                _buildTimeFilterChip('Este Mes', 'mes'),
                const SizedBox(width: 6),
                _buildTimeFilterChip('Todos', 'todos'),

                const SizedBox(width: 16),
                Container(width: 1, height: 16, color: AppColors.bgDarkBorder),
                const SizedBox(width: 16),

                Text(
                  'Tipo:',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMutedDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                _buildTypeFilterChip('Todos', 'todos'),
                const SizedBox(width: 6),
                _buildTypeFilterChip('Entradas (+)', 'entrada'),
                const SizedBox(width: 6),
                _buildTypeFilterChip('Salidas (−)', 'salida'),
                const SizedBox(width: 6),
                _buildTypeFilterChip('Devueltos', 'devuelto'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterChip(String label, String value) {
    final isSelected = _timeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _timeFilter = value),
      selectedColor: AppColors.accentTealDim,
      backgroundColor: AppColors.bgDark,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accentTeal : AppColors.textSecondaryDark,
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.accentTeal.withValues(alpha: 0.4) : AppColors.bgDarkBorder,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildTypeFilterChip(String label, String value) {
    final isSelected = _typeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _typeFilter = value),
      selectedColor: AppColors.accentTealDim,
      backgroundColor: AppColors.bgDark,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accentTeal : AppColors.textSecondaryDark,
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.accentTeal.withValues(alpha: 0.4) : AppColors.bgDarkBorder,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _movimientosFiltrados;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/inventra_logo.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Historial',
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          _buildFilterHeader(),
          Expanded(
            child: _isLoading && _movimientos.isEmpty
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: AppColors.accentTeal,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.accentTeal,
                    backgroundColor: AppColors.bgDarkSecondary,
                    onRefresh: _cargarHistorial,
                    child: list.isEmpty
                        ? _buildEmptyState()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth > 650) {
                                return GridView.builder(
                                  padding: const EdgeInsets.all(20),
                                  itemCount: list.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 480,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 3.2,
                                  ),
                                  itemBuilder: (context, index) =>
                                      _buildMovimientoItem(list[index]),
                                );
                              } else {
                                return ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, index) =>
                                      _buildMovimientoItem(list[index]),
                                );
                              }
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.bgDarkSecondary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.bgDarkBorder),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 32,
                    color: AppColors.textMutedDark,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sin movimientos registrados',
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Las transacciones de inventario\naparecerán aquí.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textMutedDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMovimientoItem(Map<String, dynamic> m) {
    final tipo = m['tipo'] as String;
    final isEntrada = tipo == 'ENTRADA';
    final folio = m['folio'] ?? 0;
    final folioStr = isEntrada
        ? 'E-${folio.toString().padLeft(6, '0')}'
        : 'VALE-${folio.toString().padLeft(6, '0')}';

    // Parsear fecha
    final dateTime = DateTime.parse(m['fecha']).toLocal();
    final dateStr =
        '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    final toolName = m['herramientas']?['nombre'] ?? 'N/A';
    final wasEdited = m['observacion_edicion'] != null;
    final isDevuelto =
        m['prestamos'] != null && m['prestamos']['estado'] == 'DEVUELTO';
    final cantidad = m['cantidad'] as int? ?? 0;

    // Colores semánticos
    final Color typeColor = isEntrada ? AppColors.accentGreen : AppColors.accentAmber;
    final IconData typeIcon =
        isEntrada ? Icons.login_rounded : Icons.logout_rounded;
    final String cantPrefix = isEntrada ? '+' : '−';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _mostrarDetalleMovimiento(m),
        borderRadius: BorderRadius.circular(16),
        splashColor: typeColor.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgDarkSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.bgDarkBorder, width: 1),
          ),
          child: Row(
            children: [
              // Indicador de tipo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(typeIcon, color: typeColor, size: 22),
              ),
              const SizedBox(width: 14),

              // Info principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          folioStr,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMutedDark,
                            fontFamily: 'Inter',
                          ),
                        ),
                        if (wasEdited) ...[  
                          const SizedBox(width: 6),
                          _buildStatusChip(
                            'Corregido',
                            AppColors.accentAmber,
                            AppColors.accentAmberDim,
                          ),
                        ],
                        if (isDevuelto) ...[  
                          const SizedBox(width: 6),
                          _buildStatusChip(
                            'Devuelto',
                            AppColors.accentTeal,
                            AppColors.accentTealDim,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      toolName,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.textPrimaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      m['responsable_nombre'] ?? 'Sin asignar',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Cantidad + fecha
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$cantPrefix$cantidad',
                    style: AppTextStyles.dataLg.copyWith(
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMutedDark,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMutedDark,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: AppTextStyles.overline.copyWith(
          color: fg,
          letterSpacing: 0.5,
          fontSize: 9,
        ),
      ),
    );
  }
}
