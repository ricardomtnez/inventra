import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class FirmaCanvasScreen extends StatefulWidget {
  const FirmaCanvasScreen({super.key});

  @override
  State<FirmaCanvasScreen> createState() => _FirmaCanvasScreenState();
}

class _FirmaCanvasScreenState extends State<FirmaCanvasScreen> {
  late SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 4,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firma Digital del Responsable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: () => _controller.clear(),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Signature(
              controller: _controller,
              backgroundColor: Colors.grey.shade50,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                if (_controller.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor, firme el lienzo táctil antes de continuar')),
                  );
                  return;
                }
                final navigator = Navigator.of(context);
                final pngBytes = await _controller.toPngBytes();
                if (pngBytes != null) {
                  navigator.pop(pngBytes);
                }
              },
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Confirmar Firma y Estampar'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          )
        ],
      ),
    );
  }
}
