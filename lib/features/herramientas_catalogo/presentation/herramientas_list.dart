import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/herramientas_repository.dart';
import 'herramientas_form.dart';
import 'qr_print_selector.dart';
import '../../movimientos_qr/presentation/registrar_movimiento_screen.dart';

class HerramientasListScreen extends StatefulWidget {
  const HerramientasListScreen({super.key});

  @override
  State<HerramientasListScreen> createState() => _HerramientasListScreenState();
}

class _HerramientasListScreenState extends State<HerramientasListScreen> {
  final _repository = HerramientasRepository();
  List<Map<String, dynamic>> _herramientas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarHerramientas();
  }

  Future<void> _cargarHerramientas() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.obtenerHerramientas();
      setState(() {
        _herramientas = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar catálogo: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Herramientas', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: 'Imprimir Planilla de QRs',
            onPressed: _herramientas.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QrPrintSelectorScreen(herramientas: _herramientas),
                      ),
                    ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarHerramientas,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _herramientas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No hay herramientas registradas en el catálogo.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          final res = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HerramientasFormScreen()),
                          );
                          if (res == true) _cargarHerramientas();
                        },
                        child: const Text('Registrar Primera Herramienta'),
                      )
                    ],
                  ),
                )
              : Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _herramientas.length,
                      itemBuilder: (context, index) {
                        final h = _herramientas[index];
                        final stock = h['stock'] as int;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // Foto
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: h['foto_url'] != null
                                      ? CachedNetworkImage(
                                          imageUrl: h['foto_url'],
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            width: 64,
                                            height: 64,
                                            color: Colors.grey.shade200,
                                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          ),
                                          errorWidget: (_, __, ___) => Container(
                                            width: 64,
                                            height: 64,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                                          ),
                                        )
                                      : Container(
                                          width: 64,
                                          height: 64,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.handyman_rounded, color: Colors.grey),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                // Detalles
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        h['nombre'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        h['ubicaciones']?['nombre'] ?? 'Sin ubicación',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: stock > 0 ? Colors.green : Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            stock > 0 ? '$stock disponibles' : 'Sin stock',
                                            style: TextStyle(
                                              color: stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Botón de Transacción
                                IconButton(
                                  icon: const Icon(Icons.swap_horiz_rounded),
                                  color: colors.primary,
                                  tooltip: 'Nueva Transacción',
                                  onPressed: () async {
                                    final res = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RegistrarMovimientoScreen(herramienta: h),
                                      ),
                                    );
                                    if (res == true) _cargarHerramientas();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HerramientasFormScreen()),
          );
          if (res == true) _cargarHerramientas();
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
