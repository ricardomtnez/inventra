import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/herramientas_repository.dart';

class PapeleraScreen extends StatefulWidget {
  const PapeleraScreen({super.key});

  @override
  State<PapeleraScreen> createState() => _PapeleraScreenState();
}

class _PapeleraScreenState extends State<PapeleraScreen> {
  final _repository = HerramientasRepository();
  List<Map<String, dynamic>> _herramientasEliminadas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarHerramientasEliminadas();
  }

  Future<void> _cargarHerramientasEliminadas() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.obtenerHerramientas(soloActivas: false);
      // Filtrar las que tienen activo == false
      final eliminadas = list.where((h) => h['activo'] == false).toList();
      setState(() {
        _herramientasEliminadas = eliminadas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar la papelera: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _restaurarHerramienta(Map<String, dynamic> h) async {
    final id = h['id'] as String;
    final nombre = h['nombre'] as String;
    
    try {
      await _repository.restaurarHerramientaLogica(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$nombre" ha sido restaurada con éxito.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _cargarHerramientasEliminadas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar herramienta: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _eliminarPermanente(Map<String, dynamic> h) async {
    final id = h['id'] as String;
    final nombre = h['nombre'] as String;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, size: 40, color: Colors.redAccent),
          title: const Text('Eliminación Permanente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¿Estás completamente seguro de eliminar permanentemente la herramienta "$nombre"?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Esta acción es irreversible. Se borrarán todos sus registros históricos de movimientos (compras, préstamos, pérdidas) debido a la eliminación en cascada.',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar Permanentemente'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await _repository.eliminarHerramientaPermanente(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$nombre" ha sido eliminada permanentemente del sistema.'),
            backgroundColor: Colors.grey.shade800,
          ),
        );
      }
      _cargarHerramientasEliminadas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar herramienta: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Papelera de Reciclaje', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Banner explicativo/advertencia
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.orange.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Las herramientas aquí listadas fueron eliminadas lógicamente y conservan sus registros. Al eliminarlas permanentemente se perderá todo su historial en cascada.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _herramientasEliminadas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_sweep_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'La papelera de reciclaje está vacía.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _herramientasEliminadas.length,
                            itemBuilder: (context, index) {
                              final h = _herramientasEliminadas[index];
                              final stock = h['stock'] as int? ?? 0;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                  child: Row(
                                    children: [
                                      // Foto
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: h['foto_url'] != null
                                            ? CachedNetworkImage(
                                                imageUrl: h['foto_url'],
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => Container(
                                                  width: 50,
                                                  height: 50,
                                                  color: Colors.grey.shade200,
                                                  child: const Center(
                                                      child: CircularProgressIndicator(strokeWidth: 2)),
                                                ),
                                                errorWidget: (_, __, ___) => Container(
                                                  width: 50,
                                                  height: 50,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                                                ),
                                              )
                                            : Container(
                                                width: 50,
                                                height: 50,
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.handyman_rounded, color: Colors.grey, size: 20),
                                              ),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Detalles
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              h['nombre'] ?? 'Sin nombre',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              h['ubicaciones']?['nombre'] ?? 'Sin ubicación',
                                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Último Stock: $stock ${h['unidades_medida']?['abreviatura'] ?? 'Pza'}',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Acciones: Restaurar o Eliminar Permanente
                                      IconButton(
                                        icon: const Icon(Icons.restore_from_trash_rounded),
                                        color: Colors.green,
                                        tooltip: 'Restaurar herramienta',
                                        onPressed: () => _restaurarHerramienta(h),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever_rounded),
                                        color: Colors.redAccent,
                                        tooltip: 'Eliminar permanentemente',
                                        onPressed: () => _eliminarPermanente(h),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
