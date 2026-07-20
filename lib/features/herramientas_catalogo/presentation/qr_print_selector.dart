import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/config/app_config.dart';
import '../../../core/presentation/pdf_viewer_screen.dart';
import '../../../core/utils/pdf_download_helper.dart';

class QrPrintSelectorScreen extends StatefulWidget {
  final List<Map<String, dynamic>> herramientas;

  const QrPrintSelectorScreen({super.key, required this.herramientas});

  @override
  State<QrPrintSelectorScreen> createState() => _QrPrintSelectorScreenState();
}

class _QrPrintSelectorScreenState extends State<QrPrintSelectorScreen> {
  double _qrSize = 90.0; // Dimensión dinámica en PDF
  int _columns = 4; // Cantidad de columnas por fila en la planilla
  String _selectedPreset = 'mediana';
  final Map<String, int> _cantidades = {};
  List<Map<String, dynamic>> _listParaImprimir = [];

  @override
  void initState() {
    super.initState();
    _listParaImprimir = List.from(widget.herramientas);
    // Inicializar cantidades
    for (var h in _listParaImprimir) {
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
    for (var h in _listParaImprimir) {
      final id = h['id'] as String;
      final cantidad = _cantidades[id] ?? 0;
      if (cantidad > 0) {
        final qrUrl = '${AppConfig.publicWebUrl}?id=$id';
        for (int i = 0; i < cantidad; i++) {
          listaEstampas.add({'nombre': h['nombre'] as String, 'url': qrUrl});
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
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // El QR ocupa la mayor parte de la estampa
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(
                              errorCorrectLevel: _qrSize <= 65
                                  ? pw.BarcodeQRCorrectionLevel.low
                                  : (_qrSize <= 100
                                        ? pw.BarcodeQRCorrectionLevel.medium
                                        : pw.BarcodeQRCorrectionLevel.high),
                            ),
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
                          fontSize: _qrSize <= 65 ? 5.0 : 6.5,
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
        title: const Text(
          'Configurar Impresión QR',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Configuración superior
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Parámetros de la Planilla',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Presets de Escala
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Escala para Herramientas:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'pequena',
                          label: Text(
                            'Peq.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          tooltip: 'Escala Pequeña (55px)',
                        ),
                        ButtonSegment<String>(
                          value: 'mediana',
                          label: Text(
                            'Med.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          tooltip: 'Escala Mediana (90px)',
                        ),
                        ButtonSegment<String>(
                          value: 'grande',
                          label: Text(
                            'Gde.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          tooltip: 'Escala Grande (135px)',
                        ),
                        ButtonSegment<String>(
                          value: 'personalizada',
                          label: Text(
                            'Ajuste',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          tooltip: 'Ajuste manual libre',
                        ),
                      ],
                      selected: {_selectedPreset},
                      onSelectionChanged: (newSelection) {
                        final val = newSelection.first;
                        setState(() {
                          _selectedPreset = val;
                          if (val == 'pequena') {
                            _qrSize = 55.0;
                            _columns = 6;
                          } else if (val == 'mediana') {
                            _qrSize = 90.0;
                            _columns = 4;
                          } else if (val == 'grande') {
                            _qrSize = 135.0;
                            _columns = 3;
                          }
                        });
                      },
                      showSelectedIcon: false,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nota explicativa pequeña
                  if (_selectedPreset == 'pequena')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Rejilla QR simplificada (baja densidad) para asegurar lectura fácil en áreas muy pequeñas.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Slider de tamaño del QR
                  Row(
                    children: [
                      const Text('Dimensión: ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: _qrSize,
                          min: 50.0,
                          max: 150.0,
                          onChanged: (v) => setState(() {
                            _qrSize = v;
                            _selectedPreset = 'personalizada';
                          }),
                        ),
                      ),
                      Text(
                        '${_qrSize.toInt()} px',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                          max: 7.0,
                          divisions: 4,
                          onChanged: (v) => setState(() {
                            _columns = v.toInt();
                            _selectedPreset = 'personalizada';
                          }),
                        ),
                      ),
                      Text(
                        '$_columns col',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Selector general tipo carrito de compras (Mercado Libre)
          if (_listParaImprimir.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value:
                          _listParaImprimir.isNotEmpty &&
                          _listParaImprimir.every(
                            (h) => (_cantidades[h['id']] ?? 0) > 0,
                          ),
                      onChanged: (val) {
                        setState(() {
                          final selectAll = val == true;
                          for (var h in _listParaImprimir) {
                            _cantidades[h['id'] as String] = selectAll ? 1 : 0;
                          }
                        });
                      },
                      activeColor: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Artículos (${_listParaImprimir.where((h) => (_cantidades[h['id']] ?? 0) > 0).length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // Listado de herramientas
          Expanded(
            child: _listParaImprimir.isEmpty
                ? const Center(
                    child: Text('No hay herramientas para imprimir.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _listParaImprimir.length,
                    itemBuilder: (context, index) {
                      final h = _listParaImprimir[index];
                      final id = h['id'] as String;
                      final cantidad = _cantidades[id] ?? 0;

                      final isSelected = cantidad > 0;
                      final espec = h['especificaciones'] as Map?;
                      final marca = espec?['marca'] as String?;

                      return Opacity(
                        opacity: isSelected ? 1.0 : 0.55,
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 10.0,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Fila Superior: Datos de la herramienta
                                Row(
                                  children: [
                                    // Checkbox de selección (tipo carrito de compras)
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (val) {
                                        setState(() {
                                          _cantidades[id] = (val == true) ? 1 : 0;
                                        });
                                      },
                                      activeColor: colors.primary,
                                    ),
                                    const SizedBox(width: 4),

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
                                              child: const Icon(
                                                Icons.handyman_rounded,
                                                color: Colors.grey,
                                                size: 20,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Detalles
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            h['nombre'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (marca != null && marca.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              marca,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: (h['stock'] as int) > 0
                                                      ? Colors.green.withValues(
                                                          alpha: 0.08,
                                                        )
                                                      : Colors.red.withValues(
                                                          alpha: 0.08,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: (h['stock'] as int) > 0
                                                        ? Colors.green.withValues(
                                                            alpha: 0.3,
                                                          )
                                                        : Colors.red.withValues(
                                                            alpha: 0.3,
                                                          ),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 5,
                                                      height: 5,
                                                      decoration: BoxDecoration(
                                                        color: (h['stock'] as int) > 0
                                                            ? Colors.green
                                                            : Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      (h['stock'] as int) > 0
                                                          ? '${h['stock']} ${h['unidades_medida']?['abreviatura'] ?? 'Pza'} en stock'
                                                          : 'Sin stock',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: (h['stock'] as int) > 0
                                                            ? Colors.green.shade800
                                                            : Colors.red.shade800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Fila Inferior: Controles
                                Row(
                                  children: [
                                    const SizedBox(width: 52), // Sangría para alinearse con detalles
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.remove_circle_outline_rounded,
                                        size: 22,
                                      ),
                                      color: isSelected
                                          ? colors.primary
                                          : Colors.grey,
                                      onPressed: isSelected
                                          ? () => setState(
                                              () => _cantidades[id] =
                                                  cantidad - 1,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 20,
                                      ),
                                      child: Text(
                                        '$cantidad',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 22,
                                      ),
                                      color: colors.primary,
                                      onPressed: () => setState(
                                        () => _cantidades[id] = cantidad + 1,
                                      ),
                                    ),
                                    const Spacer(),

                                    // Botón para compartir QR como imagen individual (estilo whatsapp/instagram)
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.share_rounded,
                                        size: 20,
                                      ),
                                      color: colors.primary.withValues(alpha: 0.8),
                                      tooltip: 'Compartir QR individual',
                                      onPressed: () {
                                        _mostrarDialogoCompartir(context, h);
                                      },
                                    ),
                                    const SizedBox(width: 16),

                                    // Botoncito para eliminar del carrito
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                      ),
                                      color: Colors.redAccent,
                                      tooltip: 'Eliminar del listado',
                                      onPressed: () {
                                        setState(() {
                                          _listParaImprimir.removeAt(index);
                                          _cantidades.remove(id);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _totalEstampas > 0 ? _generarPlanillaPDF : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(
                      'GENERAR PLANILLA DE ESTAMPAS ($_totalEstampas)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (_listParaImprimir
                          .where((h) => (_cantidades[h['id']] ?? 0) > 0)
                          .length ==
                      1) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        final activeTool = _listParaImprimir.firstWhere(
                          (h) => (_cantidades[h['id']] ?? 0) > 0,
                        );
                        _mostrarDialogoCompartir(context, activeTool);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: BorderSide(color: colors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text(
                        'COMPARTIR QR COMO IMAGEN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCompartir(
    BuildContext context,
    Map<String, dynamic> herramienta,
  ) {
    final colors = Theme.of(context).colorScheme;
    final boundaryKey = GlobalKey();
    bool isSharing = false;

    final espec = herramienta['especificaciones'] as Map?;
    final marca = espec?['marca'] as String?;
    final ubic = herramienta['ubicaciones'] as Map?;
    final ubicacionNombre = ubic?['nombre'] as String?;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tarjeta a compartir
                  RepaintBoundary(
                    key: boundaryKey,
                    child: Container(
                      width: 310,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1E3A8A), // Azul marino real
                            const Color(0xFF2563EB), // Azul cobalto eléctrico
                            const Color(0xFF0D9488), // Verde azulado / Teal
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: 1,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 22,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Cabecera de la App
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.inventory_2_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'INVENTRA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Tarjeta blanca interna (Spotify/Instagram style)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Foto e información de la herramienta
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: herramienta['foto_url'] != null
                                            ? CachedNetworkImage(
                                                imageUrl:
                                                    herramienta['foto_url'],
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                width: 50,
                                                height: 50,
                                                color: Colors.grey.shade100,
                                                child: Icon(
                                                  Icons.handyman_rounded,
                                                  color: colors.primary
                                                      .withValues(alpha: 0.5),
                                                  size: 24,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            herramienta['nombre'],
                                            style: const TextStyle(
                                              color: Color(0xFF1E293B),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (marca != null && marca.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              marca,
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (ubicacionNombre != null &&
                                              ubicacionNombre.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              '📍 $ubicacionNombre',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w400,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Divisor punteado estilo cupón / ticket
                                Row(
                                  children: List.generate(
                                    15,
                                    (index) => Expanded(
                                      child: Container(
                                        color: index % 2 == 0
                                            ? Colors.transparent
                                            : Colors.grey.shade300,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Código QR con marco limpio
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey.shade100,
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: QrImageView(
                                    data:
                                        '${AppConfig.publicWebUrl}?id=${herramienta['id']}',
                                    version: QrVersions.auto,
                                    size: 165.0,
                                    gapless: false,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF1E293B),
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Texto e ícono de escaneo inferior
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code_scanner_rounded,
                                      size: 14,
                                      color: colors.primary
                                          .withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Escanea para consultar o transaccionar',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Sello o marca de agua inferior de la tarjeta
                          Text(
                            'Generado con Inventra App',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botones de acción abajo (no en la captura)
                  if (isSharing)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            setDialogState(() => isSharing = true);
                            try {
                              RenderRepaintBoundary boundary =
                                  boundaryKey.currentContext!
                                      .findRenderObject()
                                      as RenderRepaintBoundary;
                              ui.Image image = await boundary.toImage(
                                pixelRatio: 3.0,
                              );
                              ByteData? byteData = await image.toByteData(
                                format: ui.ImageByteFormat.png,
                              );
                              Uint8List pngBytes =
                                  byteData!.buffer.asUint8List();

                              if (kIsWeb) {
                                await PdfDownloadHelper.downloadBytes(
                                  bytes: pngBytes,
                                  filename: 'qr_${herramienta['nombre'].toString().replaceAll(' ', '_')}.png',
                                  mimeType: 'image/png',
                                );
                              } else {
                                final params = ShareParams(
                                  text: 'Código QR de ${herramienta['nombre']}',
                                  files: [
                                    XFile.fromData(
                                      pngBytes,
                                      name: 'qr_${herramienta['nombre'].toString().replaceAll(' ', '_')}.png',
                                      mimeType: 'image/png',
                                    ),
                                  ],
                                );
                                await SharePlus.instance.share(params);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(kIsWeb ? 'Error al descargar: $e' : 'Error al compartir: $e'),
                                  ),
                                );
                              }
                            } finally {
                              setDialogState(() => isSharing = false);
                            }
                          },
                          icon: Icon(kIsWeb ? Icons.download_rounded : Icons.share_rounded),
                          label: Text(kIsWeb ? 'Descargar Tarjeta' : 'Compartir Tarjeta'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
