import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignaturePad extends StatefulWidget {
  final String title;
  final Uint8List? initialBytes;
  final Function(Uint8List?) onSave;
  final bool requireTapToDraw;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;

  const SignaturePad({
    super.key,
    required this.title,
    this.initialBytes,
    required this.onSave,
    this.requireTapToDraw = false,
    this.onDragStart,
    this.onDragEnd,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  late SignatureController _controller;
  Uint8List? _localBytes;
  bool _hasContent = false;
  /// true = canvas bloqueado como imagen estática (no editable)
  bool _isLocked = false;
  bool _isDrawingEnabled = false;

  @override
  void initState() {
    super.initState();
    _localBytes = widget.initialBytes;
    _isLocked = widget.initialBytes != null;
    _hasContent = widget.initialBytes != null;
    _isDrawingEnabled = !widget.requireTapToDraw && widget.initialBytes == null;

    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
      // Auto-guarda bytes en cada trazo para que el padre siempre tenga la
      // versión más reciente, pero el canvas permanece editable hasta ACEPTAR.
      onDrawEnd: _autoSaveBytes,
    );
  }

  @override
  void didUpdateWidget(SignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialBytes != oldWidget.initialBytes) {
      setState(() {
        _localBytes = widget.initialBytes;
        if (widget.initialBytes == null) {
          _controller.clear();
          _hasContent = false;
          _isLocked = false;
          _isDrawingEnabled = !widget.requireTapToDraw;
        } else {
          _isLocked = true;
          _hasContent = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _autoSaveBytes() async {
    if (!_hasContent) {
      setState(() => _hasContent = true);
    }
    final bytes = await _controller.toPngBytes(width: 1000, height: 500);
    _localBytes = bytes;
    widget.onSave(bytes);
  }

  Future<void> _acceptar() async {
    final bytes = await _controller.toPngBytes(width: 1000, height: 500);
    if (bytes == null) return;
    setState(() {
      _localBytes = bytes;
      _isLocked = true;
      _isDrawingEnabled = false;
    });
    widget.onSave(bytes);
  }

  void _resetAll() {
    _controller.clear();
    setState(() {
      _localBytes = null;
      _hasContent = false;
      _isLocked = false;
      _isDrawingEnabled = !widget.requireTapToDraw;
    });
    widget.onSave(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Encabezado ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (_isLocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'GUARDADA',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Contenedor principal ─────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _isLocked ? Colors.green : Colors.grey.shade400,
              width: _isLocked ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: _isDrawingEnabled ? Colors.white : (_hasContent ? Colors.green.withValues(alpha: 0.02) : Colors.grey.shade50),
          ),
          child: Column(
            children: [
              // ── Área de dibujo / imagen ──────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_isLocked && _localBytes != null)
                    // Firma bloqueada: se muestra como imagen, no editable
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.memory(
                        _localBytes!,
                        height: 150,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    )
                  else if (!_isDrawingEnabled)
                    // Estado inicial: toca para activar el canvas
                    InkWell(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      onTap: () => setState(() => _isDrawingEnabled = true),
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.gesture, size: 36, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'TOCA PARA FIRMAR',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // Canvas activo y editable
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Listener(
                        onPointerDown: (_) => widget.onDragStart?.call(),
                        onPointerUp: (_) => widget.onDragEnd?.call(),
                        onPointerCancel: (_) => widget.onDragEnd?.call(),
                        child: Signature(
                          controller: _controller,
                          height: 150,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),

                  // Marca de agua "FIRME AQUÍ"
                  if (_isDrawingEnabled && !_hasContent)
                    const IgnorePointer(
                      child: Text(
                        'FIRME AQUÍ',
                        style: TextStyle(
                          color: Color(0xFFCCCCCC),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                ],
              ),

              // ── Barra de acciones ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botón limpiar (siempre visible cuando hay algo)
                    if (_hasContent || _isDrawingEnabled || _isLocked)
                      TextButton.icon(
                        onPressed: _resetAll,
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        label: const Text(
                          'Limpiar',
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Botón ACEPTAR: aparece cuando hay contenido pero NO está bloqueado
                    if (_hasContent && !_isLocked)
                      ElevatedButton.icon(
                        onPressed: _acceptar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text(
                          'ACEPTAR',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Aviso debajo del pad cuando hay contenido sin aceptar
        if (_isDrawingEnabled && _hasContent && !_isLocked)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 13, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  'Presiona ACEPTAR para guardar y bloquear la firma',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
