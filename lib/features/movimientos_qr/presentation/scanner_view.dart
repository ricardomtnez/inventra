import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../herramientas_catalogo/data/herramientas_repository.dart';
import 'registrar_movimiento_screen.dart';

class ScannerView extends StatefulWidget {
  final String? defaultTipo;

  const ScannerView({super.key, this.defaultTipo});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawUrl = barcodes.first.rawValue;
    if (rawUrl == null || rawUrl.isEmpty) return;

    setState(() => _isProcessing = true);
    _scannerController.stop();

    try {
      final client = SupabaseClientHelper.client;

      if (rawUrl.startsWith('INVENTRA_PRESTAMO:')) {
        final prestamoId = rawUrl.substring('INVENTRA_PRESTAMO:'.length).trim();
        if (prestamoId.isEmpty) {
          throw Exception('Código de préstamo no válido.');
        }

        final loan = await client
            .from('prestamos')
            .select('*, herramientas(*, ubicaciones(nombre), unidades_medida(nombre, abreviatura))')
            .eq('id', prestamoId)
            .single();

        if (loan['estado'] == 'DEVUELTO') {
          final String fechaDev = loan['fecha_devolucion'] != null
              ? _formatFechaDev(loan['fecha_devolucion'])
              : 'recientemente';
          if (mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade700, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Préstamo Finalizado'),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Este vale de préstamo (VALE-${loan['folio'].toString().padLeft(6, '0')}) ya ha sido devuelto por completo.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text('Responsable: ${loan['responsable_nombre']}'),
                    Text('Herramienta: ${loan['herramientas']?['nombre'] ?? ''}'),
                    Text('Fecha de devolución: $fechaDev'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            );
          }
          _reactivarEscaner();
          return;
        }

        final tool = loan['herramientas'];
        if (tool == null) {
          throw Exception('No se encontró la herramienta vinculada a este préstamo.');
        }

        if (!mounted) return;

        final res = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RegistrarMovimientoScreen(
              herramienta: tool,
              tipoInicial: 'ENTRADA',
              prestamoInicial: loan,
            ),
          ),
        );

        if (!mounted) return;

        if (res == true) {
          Navigator.pop(context, true);
        } else {
          _reactivarEscaner();
        }
      } else {
        String? toolId;
        final uuidRegExp = RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        
        if (uuidRegExp.hasMatch(rawUrl.trim())) {
          toolId = rawUrl.trim();
        } else {
          try {
            final uri = Uri.parse(rawUrl);
            toolId = uri.queryParameters['id'];
          } catch (_) {}
        }

        if (toolId == null || toolId.isEmpty) {
          throw Exception('El código QR no contiene un ID de herramienta o préstamo válido.');
        }

        final tool = await client
            .from('herramientas')
            .select('*, ubicaciones(nombre), unidades_medida(nombre, abreviatura)')
            .eq('id', toolId)
            .single();

        if (!mounted) return;

        final res = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RegistrarMovimientoScreen(
              herramienta: tool,
              tipoInicial: widget.defaultTipo,
            ),
          ),
        );

        if (!mounted) return;

        if (res == true) {
          Navigator.pop(context, true);
        } else {
          _reactivarEscaner();
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMsg = 'El código QR escaneado no es válido o no pertenece a ninguna herramienta de Inventra.';
      if (e.toString().contains('connection') || e.toString().contains('network')) {
        errorMsg = 'Error de conexión. Por favor, verifique su conexión a internet.';
      }
      
      await _mostrarDialogoQrInvalido(errorMsg);
      _reactivarEscaner();
    }
  }

  Future<void> _mostrarDialogoQrInvalido(String mensaje) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Código QR No Válido',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mensaje,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Asegúrate de escanear un vale de préstamo de Inventra o el código QR de una herramienta registrada en el sistema.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _reactivarEscaner() {
    setState(() => _isProcessing = false);
    _scannerController.start();
  }

  String _formatFechaDev(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      final day = dt.day.toString().padLeft(2, '0');
      final month = monthNames[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$min';
    } catch (e) {
      return dateStr.split('.')[0];
    }
  }

  Future<void> _mostrarSeleccionManual() async {
    // Pausar la cámara para ahorrar batería y recursos
    _scannerController.stop();

    final repository = HerramientasRepository();
    List<Map<String, dynamic>> allTools = [];
    List<Map<String, dynamic>> filteredTools = [];
    bool isLoadingTools = true;

    if (!mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            // Cargar herramientas solo una vez al abrir el modal
            if (isLoadingTools) {
              repository.obtenerHerramientas().then((tools) {
                if (context.mounted) {
                  setModalState(() {
                    allTools = tools;
                    filteredTools = tools;
                    isLoadingTools = false;
                  });
                }
              }).catchError((e) {
                if (context.mounted) {
                  setModalState(() {
                    isLoadingTools = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al cargar herramientas: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  // Indicador visual de arrastrar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Selección Manual de Herramienta',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Caja de búsqueda dinámica
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Buscar por nombre, marca o modelo',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        final query = value.toLowerCase().trim();
                        filteredTools = allTools.where((t) {
                          final nombre = (t['nombre'] ?? '').toString().toLowerCase();
                          final especificaciones = t['especificaciones'] as Map<String, dynamic>? ?? {};
                          final marca = (especificaciones['marca'] ?? '').toString().toLowerCase();
                          final modelo = (especificaciones['modelo'] ?? '').toString().toLowerCase();
                          return nombre.contains(query) || marca.contains(query) || modelo.contains(query);
                        }).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Listado
                  Expanded(
                    child: isLoadingTools
                        ? const Center(child: CircularProgressIndicator())
                        : filteredTools.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No se encontraron herramientas',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: filteredTools.length,
                                itemBuilder: (context, index) {
                                  final tool = filteredTools[index];
                                  final stock = tool['stock'] as int? ?? 0;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: tool['foto_url'] != null
                                            ? CachedNetworkImage(
                                                imageUrl: tool['foto_url'],
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => Container(
                                                  width: 48,
                                                  height: 48,
                                                  color: Colors.grey.shade200,
                                                  child: const Center(
                                                      child: CircularProgressIndicator(strokeWidth: 2)),
                                                ),
                                                errorWidget: (_, __, ___) => Container(
                                                  width: 48,
                                                  height: 48,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                                                ),
                                              )
                                            : Container(
                                                width: 48,
                                                height: 48,
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.handyman_rounded, color: Colors.grey),
                                              ),
                                      ),
                                      title: Text(
                                        tool['nombre'] ?? 'Sin nombre',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 2),
                                          Text(
                                            tool['ubicaciones']?['nombre'] ?? 'Sin ubicación',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Stock: $stock ${tool['unidades_medida']?['abreviatura'] ?? 'Pza'}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: const Icon(Icons.chevron_right_rounded),
                                      onTap: () {
                                        Navigator.pop(context, true);
                                        _abrirRegistroDesdeManual(tool);
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Si se cierra el modal sin seleccionar ninguna herramienta, reactivar escáner
    if (result != true) {
      _reactivarEscaner();
    }
  }

  Future<void> _abrirRegistroDesdeManual(Map<String, dynamic> tool) async {
    setState(() => _isProcessing = true);
    try {
      if (!mounted) return;
      final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegistrarMovimientoScreen(
            herramienta: tool,
            tipoInicial: widget.defaultTipo,
          ),
        ),
      );

      if (!mounted) return;

      if (res == true) {
        Navigator.pop(context, true);
      } else {
        _reactivarEscaner();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir registro de movimiento: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      _reactivarEscaner();
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Código QR'),
        actions: [
          // Botón de linterna — v6: escuchar al controlador directamente
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scannerController,
            builder: (context, state, child) {
              final isTorchOn = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                ),
                onPressed: () => _scannerController.toggleTorch(),
              );
            },
          ),
          // Botón de cámara frontal/trasera
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scannerController,
            builder: (context, state, child) {
              final isFront = state.cameraDirection == CameraFacing.front;
              return IconButton(
                icon: Icon(
                  isFront
                      ? Icons.camera_front_rounded
                      : Icons.camera_rear_rounded,
                ),
                onPressed: () => _scannerController.switchCamera(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          // Overlay de visor QR
          IgnorePointer(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.5),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(color: Colors.transparent),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Marco del visor
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade600, width: 4),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Botón de Selección Manual en la parte inferior
          Positioned(
            bottom: 36,
            left: 24,
            right: 24,
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _mostrarSeleccionManual,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                ),
                icon: const Icon(Icons.search_rounded, size: 22),
                label: const Text(
                  'BÚSQUEDA / SELECCIÓN MANUAL',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
          // Indicador de carga
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Buscando herramienta en sistema...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
