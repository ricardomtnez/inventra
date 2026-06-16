import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/herramientas_repository.dart';

class HerramientasFormScreen extends StatefulWidget {
  final Map<String, dynamic>? herramienta;
  const HerramientasFormScreen({super.key, this.herramienta});

  @override
  State<HerramientasFormScreen> createState() => _HerramientasFormScreenState();
}

class _HerramientasFormScreenState extends State<HerramientasFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _nSerieController = TextEditingController();
  final _stockController = TextEditingController();
  final _costoController = TextEditingController();

  final _repository = HerramientasRepository();
  final _picker = ImagePicker();

  File? _imageFile;
  bool _isSaving = false;

  String? _selectedUbicacion;
  List<Map<String, dynamic>> _ubicaciones = [];
  String? _selectedUnidadMedida;
  List<Map<String, dynamic>> _unidadesMedida = [];

  @override
  void initState() {
    super.initState();
    _cargarUbicaciones();
    _cargarUnidadesMedida();
    if (widget.herramienta != null) {
      _nombreController.text = widget.herramienta!['nombre'] ?? '';
      _descController.text = widget.herramienta!['descripcion'] ?? '';
      final specs =
          widget.herramienta!['especificaciones'] as Map<String, dynamic>? ??
          {};
      _marcaController.text = specs['marca'] ?? '';
      _modeloController.text = specs['modelo'] ?? '';
      _nSerieController.text = specs['n_serie'] ?? '';
      _selectedUbicacion = widget.herramienta!['ubicacion_id'];
      _selectedUnidadMedida = widget.herramienta!['unidad_medida_id'];
    }
  }

  Future<void> _cargarUbicaciones() async {
    final list = await _repository.obtenerUbicaciones();
    setState(() {
      _ubicaciones = list;
    });
  }

  Future<void> _cargarUnidadesMedida() async {
    final list = await _repository.obtenerUnidadesMedida();
    setState(() {
      _unidadesMedida = list;
    });
  }

  Future<void> _seleccionarImagen(ImageSource source) async {
    // Compresión activa en origen tanto para Cámara como para Galería
    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70, // Compresión de calidad al 70%
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _mostrarOpcionesImagen() {
    FocusScope.of(context).unfocus();
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
                _seleccionarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Seleccionar de Galería'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarHerramienta() async {
    if (!_formKey.currentState!.validate() ||
        _selectedUbicacion == null ||
        _selectedUnidadMedida == null) {
      return;
    }
    setState(() => _isSaving = true);

    try {
      String? fotoUrl = widget.herramienta?['foto_url'];
      if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        fotoUrl = await _repository.subirFoto(_imageFile!, fileName);
      }

      if (widget.herramienta != null) {
        await _repository.actualizarHerramienta(
          id: widget.herramienta!['id'],
          nombre: _nombreController.text.trim(),
          descripcion: _descController.text.trim(),
          fotoUrl: fotoUrl,
          ubicacionId: _selectedUbicacion!,
          unidadMedidaId: _selectedUnidadMedida!,
          especificaciones: {
            'marca': _marcaController.text.trim(),
            'modelo': _modeloController.text.trim(),
            'n_serie': _nSerieController.text.trim(),
          },
        );
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Herramienta actualizada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _repository.registrarHerramienta(
          nombre: _nombreController.text.trim(),
          descripcion: _descController.text.trim(),
          fotoUrl: fotoUrl,
          ubicacionId: _selectedUbicacion!,
          unidadMedidaId: _selectedUnidadMedida!,
          stockInicial: int.tryParse(_stockController.text) ?? 0,
          costoUnitario: double.tryParse(_costoController.text) ?? 0.00,
          especificaciones: {
            'marca': _marcaController.text.trim(),
            'modelo': _modeloController.text.trim(),
            'n_serie': _nSerieController.text.trim(),
          },
        );
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Herramienta registrada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.herramienta == null
                ? 'Registrar Herramienta'
                : 'Editar Herramienta',
          ),
        ),
        body: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final formWidget = Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Visualización de Foto
                      Center(
                        child: GestureDetector(
                          onTap: _mostrarOpcionesImagen,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: _imageFile != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Image.file(
                                      _imageFile!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : (widget.herramienta != null &&
                                      widget.herramienta!['foto_url'] != null)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: CachedNetworkImage(
                                      imageUrl: widget.herramienta!['foto_url'],
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.grey,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt_outlined,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Cargar Imagen',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la Herramienta',
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _marcaController,
                              decoration: const InputDecoration(
                                labelText: 'Marca',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _modeloController,
                              decoration: const InputDecoration(
                                labelText: 'Modelo',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nSerieController,
                        decoration: const InputDecoration(
                          labelText: 'Número de Serie',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dropdown de Ubicación Física
                      DropdownButtonFormField<String>(
                        hint: const Text('Ubicación Física'),
                        initialValue: _selectedUbicacion,
                        items: _ubicaciones.map((u) {
                          return DropdownMenuItem<String>(
                            value: u['id'],
                            child: Text(u['nombre']),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedUbicacion = v),
                        validator: (v) =>
                            v == null ? 'Seleccione ubicación' : null,
                      ),
                      const SizedBox(height: 16),

                      // Dropdown de Unidad de Medida
                      DropdownButtonFormField<String>(
                        hint: const Text('Unidad de Medida'),
                        initialValue: _selectedUnidadMedida,
                        items: _unidadesMedida.map((u) {
                          return DropdownMenuItem<String>(
                            value: u['id'],
                            child: Text('${u['nombre']} (${u['abreviatura']})'),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedUnidadMedida = v),
                        validator: (v) =>
                            v == null ? 'Seleccione unidad de medida' : null,
                      ),
                      const SizedBox(height: 16),

                      if (widget.herramienta == null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _stockController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Stock Inicial',
                                  hintText: '0',
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _costoController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Costo Unitario (\$)',
                                  hintText: '0.00',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ] else ...[
                        const SizedBox(height: 32),
                      ],
                      ElevatedButton(
                        onPressed: _guardarHerramienta,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.herramienta == null
                              ? 'Registrar en Sistema'
                              : 'Guardar Cambios',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );

                if (constraints.maxWidth > 650) {
                  final colors = Theme.of(context).colorScheme;
                  return SingleChildScrollView(
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
                    padding: const EdgeInsets.all(24.0),
                    child: formWidget,
                  );
                }
              },
            ),
      ),
    );
  }
}
