import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/supabase/supabase_client.dart';
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
      final uri = Uri.parse(rawUrl);
      final toolId = uri.queryParameters['id'];

      if (toolId == null || toolId.isEmpty) {
        throw Exception('El código QR no contiene un ID de herramienta válido.');
      }

      final client = SupabaseClientHelper.client;
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar QR: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      _reactivarEscaner();
    }
  }

  void _reactivarEscaner() {
    setState(() => _isProcessing = false);
    _scannerController.start();
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
