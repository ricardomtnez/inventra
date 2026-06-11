import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/supabase/supabase_client.dart';

class PublicToolDetailScreen extends StatefulWidget {
  final String herramientaId;

  const PublicToolDetailScreen({super.key, required this.herramientaId});

  @override
  State<PublicToolDetailScreen> createState() => _PublicToolDetailScreenState();
}

class _PublicToolDetailScreenState extends State<PublicToolDetailScreen> {
  Map<String, dynamic>? _herramienta;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDetalles();
  }

  Future<void> _cargarDetalles() async {
    try {
      final client = SupabaseClientHelper.client;
      final res = await client
          .from('herramientas')
          .select('*, ubicaciones(nombre)')
          .eq('id', widget.herramientaId)
          .single();

      setState(() {
        _herramienta = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se encontró la herramienta especificada o el código QR es inválido.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta de Herramienta', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Foto de la herramienta
                            if (_herramienta!['foto_url'] != null)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: CachedNetworkImage(
                                  imageUrl: _herramienta!['foto_url'],
                                  height: 250,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const SizedBox(
                                    height: 250,
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) => const SizedBox(
                                    height: 250,
                                    child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                child: const Icon(Icons.handyman_rounded, size: 64, color: Colors.grey),
                              ),
                            
                            // Detalles
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _herramienta!['nombre'].toUpperCase(),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Badge de Stock
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _herramienta!['stock'] > 0 
                                          ? Colors.green.shade50 
                                          : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _herramienta!['stock'] > 0 
                                          ? 'Disponible (${_herramienta!['stock']} piezas)' 
                                          : 'Sin Existencias',
                                      style: TextStyle(
                                        color: _herramienta!['stock'] > 0 ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  const Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(_herramienta!['descripcion'] ?? 'Sin descripción disponible.', style: const TextStyle(fontSize: 16)),
                                  const SizedBox(height: 20),
                                  
                                  const Text('Ubicación Física', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_rounded, color: Colors.redAccent),
                                      const SizedBox(width: 8),
                                      Text(
                                        _herramienta!['ubicaciones']?['nombre'] ?? 'No especificada',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
