import 'package:flutter/material.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../herramientas_catalogo/data/herramientas_repository.dart';

class HistorialMovimientosScreen extends StatefulWidget {
  const HistorialMovimientosScreen({super.key});

  @override
  State<HistorialMovimientosScreen> createState() => _HistorialMovimientosScreenState();
}

class _HistorialMovimientosScreenState extends State<HistorialMovimientosScreen> {
  final _repository = HerramientasRepository();
  final _authRepository = AuthRepository();
  List<Map<String, dynamic>> _movimientos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    if (_movimientos.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final list = await _repository.obtenerMovimientos();
      setState(() {
        _movimientos = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar historial: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _mostrarDetalleMovimiento(Map<String, dynamic> m) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tipo = m['tipo'] as String;
    final folio = m['folio'] ?? 0;
    final folioStr = tipo == 'ENTRADA' ? 'E-${folio.toString().padLeft(6, '0')}' : 'VALE-${folio.toString().padLeft(6, '0')}';
    final fecha = DateTime.parse(m['fecha']).toLocal().toString().split('.')[0];
    final toolName = m['herramientas']?['nombre'] ?? 'Herramienta no identificada';
    final hasBeenEdited = m['observacion_edicion'] != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  folioStr,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tipo == 'ENTRADA' ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tipo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: tipo == 'ENTRADA' ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            _buildDetailRow('Herramienta:', toolName),
            _buildDetailRow('Cantidad:', '${m['cantidad']} uds'),
            _buildDetailRow('Motivo:', m['motivo'].toString().replaceAll('_', ' ')),
            if (m['precio_unitario'] != null && (double.tryParse(m['precio_unitario'].toString()) ?? 0.0) > 0.0)
              _buildDetailRow('Precio Unitario:', '\$${double.parse(m['precio_unitario'].toString()).toStringAsFixed(2)}'),
            _buildDetailRow('Responsable:', m['responsable_nombre'] ?? 'Sin asignar'),
            _buildDetailRow('Matrícula / ID:', m['matricula'] ?? 'Sin matrícula'),
            _buildDetailRow('Fecha / Hora:', fecha),
            
            if (hasBeenEdited) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: colors.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Registro Editado (Auditoría)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Motivo: ${m['observacion_edicion']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (m['fecha_edicion'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Fecha de corrección: ${DateTime.parse(m['fecha_edicion']).toLocal().toString().split('.')[0]}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            
            // Botón de Editar (sólo para administradores)
            if (_authRepository.isAdmin)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Cerrar bottom sheet
                  _mostrarDialogoEdicion(m);
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Corregir / Editar Registro'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEdicion(Map<String, dynamic> m) {
    final formKey = GlobalKey<FormState>();
    final qtyController = TextEditingController(text: m['cantidad'].toString());
    final obsController = TextEditingController();
    String motivo = m['motivo'] as String;
    final tipo = m['tipo'] as String;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  const Text('Editar Movimiento'),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Herramienta: ${m['herramientas']?['nombre'] ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cantidad'),
                        validator: (v) => (v == null || int.tryParse(v) == null || int.parse(v) <= 0)
                            ? 'Ingresa una cantidad mayor a 0'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: motivo,
                        decoration: const InputDecoration(labelText: 'Motivo'),
                        items: tipo == 'ENTRADA'
                            ? const [
                                DropdownMenuItem(value: 'COMPRA_NUEVA', child: Text('COMPRA NUEVA')),
                                DropdownMenuItem(value: 'DEVOLUCION_PRESTAMO', child: Text('DEVOLUCIÓN DE PRÉSTAMO')),
                              ]
                            : const [
                                DropdownMenuItem(value: 'PRESTAMO_ALUMNO_PROFESOR', child: Text('PRÉSTAMO A ALUMNO/PROFESOR')),
                                DropdownMenuItem(value: 'BAJA_DESCOMPOSTURA', child: Text('BAJA POR DESCOMPOSTURA')),
                                DropdownMenuItem(value: 'BAJA_PERDIDA', child: Text('BAJA POR PÉRDIDA')),
                              ],
                        onChanged: (v) => setDialogState(() => motivo = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: obsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Motivo de Corrección (Auditoría)',
                          hintText: 'Explica el motivo de la corrección...',
                        ),
                        validator: (v) => (v == null || v.trim().length < 8)
                            ? 'Explica detalladamente (mínimo 8 caracteres)'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    
                    nav.pop(); // Cerrar diálogo

                    setState(() => _isLoading = true);
                    try {
                      await _repository.actualizarMovimiento(
                        id: m['id'],
                        cantidad: int.parse(qtyController.text),
                        motivo: motivo,
                        observacionEdicion: obsController.text.trim(),
                      );
                      _cargarHistorial();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Movimiento corregido y stock actualizado.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      _cargarHistorial();
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
                              SizedBox(width: 12),
                              Text('Error de Inventario'),
                            ],
                          ),
                          content: Text(
                            e.toString().contains('Stock insuficiente')
                                ? 'No se puede guardar: la corrección causaría que el stock disponible de la herramienta sea menor a cero.'
                                : 'No se pudo aplicar la corrección: ${e.toString()}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cerrar'),
                            )
                          ],
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Movimientos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: _isLoading && _movimientos.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _cargarHistorial,
                    child: _movimientos.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.7,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No hay transacciones de inventario registradas.',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _movimientos.length,
                                itemBuilder: (context, index) {
                                  final m = _movimientos[index];
                                  final tipo = m['tipo'] as String;
                                  final folio = m['folio'] ?? 0;
                                  final folioStr = tipo == 'ENTRADA' ? 'E-${folio.toString().padLeft(6, '0')}' : 'VALE-${folio.toString().padLeft(6, '0')}';
                                  final dateStr = DateTime.parse(m['fecha']).toLocal().toString().split(' ')[0];
                                  final toolName = m['herramientas']?['nombre'] ?? 'N/A';
                                  final wasEdited = m['observacion_edicion'] != null;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _mostrarDetalleMovimiento(m),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        child: Row(
                                          children: [
                                            // Icono indicador Entrada/Salida
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: tipo == 'ENTRADA'
                                                    ? Colors.green.withValues(alpha: 0.12)
                                                    : Colors.red.withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                tipo == 'ENTRADA' ? Icons.login_rounded : Icons.logout_rounded,
                                                color: tipo == 'ENTRADA' ? Colors.green : Colors.red,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            
                                            // Información de transacción
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        folioStr,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      if (wasEdited)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.amber.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            'Corregido',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.amber.shade900,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    toolName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Responsable: ${m['responsable_nombre'] ?? 'Sin asignar'}',
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            // Cantidad
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${tipo == 'ENTRADA' ? '+' : '-'}${m['cantidad']}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: tipo == 'ENTRADA' ? Colors.green.shade700 : Colors.red.shade700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  dateStr,
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
