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
  bool _hasContent = false; // Keep this for watermark logic
  bool _isSaved = false;
  bool _isDrawingEnabled = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.initialBytes != null;
    _hasContent = widget.initialBytes != null;
    _isDrawingEnabled = !widget.requireTapToDraw || widget.initialBytes != null;

    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
      onDrawEnd: () {
        if (!_hasContent) {
          setState(() => _hasContent = true);
        }
      },
      points: widget.initialBytes != null
          ? []
          : null, // Not easily reconstructible from Bytes
    );
  }

  @override
  void didUpdateWidget(SignaturePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialBytes != oldWidget.initialBytes) {
      setState(() {
        _isSaved = widget.initialBytes != null;
        _hasContent = widget.initialBytes != null;
        if (widget.initialBytes != null) {
          _isDrawingEnabled = false;
        } else {
          _isDrawingEnabled = !widget.requireTapToDraw;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            if (_isSaved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
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
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _isSaved ? Colors.green : Colors.grey,
              width: _isSaved ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _isSaved ? Colors.green[50] : Colors.grey[50],
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_isSaved && widget.initialBytes != null)
                    Image.memory(
                      widget.initialBytes!,
                      height: 150,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    )
                  else if (!_isDrawingEnabled)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isDrawingEnabled = true;
                        });
                      },
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        color: Colors.grey[100],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.gesture, size: 36, color: Colors.grey[500]),
                            const SizedBox(height: 8),
                            Text(
                              'TOCA PARA FIRMAR',
                              style: TextStyle(
                                color: Colors.grey[600],
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
                    Listener(
                      onPointerDown: (_) => widget.onDragStart?.call(),
                      onPointerUp: (_) => widget.onDragEnd?.call(),
                      onPointerCancel: (_) => widget.onDragEnd?.call(),
                      child: Signature(
                        controller: _controller,
                        height: 150,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  if (_isDrawingEnabled && !_hasContent)
                    IgnorePointer(
                      child: Text(
                        'FIRME AQUÍ',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                ],
              ),
              if (_isSaved || _isDrawingEnabled)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _hasContent = false;
                              _isSaved = false;
                              _isDrawingEnabled = !widget.requireTapToDraw;
                            });
                            widget.onSave(null);
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text(
                            'Limpiar',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        if (_hasContent && !_isSaved)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final signature = await _controller.toPngBytes(
                                width: 1000,
                                height: 500,
                              );
                              if (signature != null) {
                                setState(() {
                                  _isSaved = true;
                                  _isDrawingEnabled = false;
                                });
                                widget.onSave(signature);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text(
                              'ACEPTAR',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_isDrawingEnabled && _hasContent && !_isSaved)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 4.0),
            child: Text(
              '↑ Recuerda presionar ACEPTAR para guardar',
              style: TextStyle(
                color: Colors.orange[800],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
