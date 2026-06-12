import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/herramientas_repository.dart';

class HerramientasFormScreen extends StatefulWidget {
  const HerramientasFormScreen({super.key});

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
  final _stockController = TextEditingController(text: '0');
  final _costoController = TextEditingController(text: '0.00');
  
  final _repository = HerramientasRepository();
  final _picker = ImagePicker();
  
  File? _imageFile;
  bool _isSaving = false;
  
  String? _selectedUbicacion;
  List<Map<String, dynamic>> _ubicaciones = [];

  @override
  void initState() {
    super.initState();
    _cargarUbicaciones();
  }

  Future<void> _cargarUbicaciones() async {
    final list = await _repository.obtenerUbicaciones();
    setState(() {
      _ubicaciones = list;
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
    if (!_formKey.currentState!.validate() || _selectedUbicacion == null) return;
    setState(() => _isSaving = true);

    try {
      String? fotoUrl;
      if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        fotoUrl = await _repository.subirFoto(_imageFile!, fileName);
      }

      await _repository.registrarHerramienta(
        nombre: _nombreController.text.trim(),
        descripcion: _descController.text.trim(),
        fotoUrl: fotoUrl,
        ubicacionId: _selectedUbicacion!,
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
          const SnackBar(content: Text('Herramienta registrada exitosamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${e.toString()}'), backgroundColor: Colors.redAccent),
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
        appBar: AppBar(title: const Text('Registrar Herramienta')),
        body: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
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
                                    child: Image.file(_imageFile!, fit: BoxFit.cover),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Cargar Imagen', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(labelText: 'Nombre de la Herramienta'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(labelText: 'Descripción'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _marcaController,
                              decoration: const InputDecoration(labelText: 'Marca'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _modeloController,
                              decoration: const InputDecoration(labelText: 'Modelo'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nSerieController,
                        decoration: const InputDecoration(labelText: 'Número de Serie'),
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
                        onChanged: (v) => setState(() => _selectedUbicacion = v),
                        validator: (v) => v == null ? 'Seleccione ubicación' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Stock Inicial'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _costoController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Costo Unitario (\$)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _guardarHerramienta,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Registrar en Sistema', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
