import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/widgets/offline_banner.dart';
import '../data/herramientas_repository.dart';
import 'herramientas_form.dart';
import 'qr_print_selector.dart';
import 'papelera_screen.dart';
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
  bool _isSelectionMode = false;
  final Set<String> _selectedToolIds = {};

  @override
  void initState() {
    super.initState();
    _cargarHerramientas();
  }

  Future<void> _cargarHerramientas() async {
    if (_herramientas.isEmpty) {
      setState(() => _isLoading = true);
    }
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
          SnackBar(
            content: Text('Error al cargar catálogo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/inventra_logo.png',
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Catálogo',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) async {
              if (value == 'papelera') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PapeleraScreen(),
                  ),
                );
                _cargarHerramientas();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'papelera',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Papelera de Reciclaje'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (_herramientas.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = !_isSelectionMode;
                          if (!_isSelectionMode) {
                            _selectedToolIds.clear();
                          }
                        });
                      },
                      icon: Icon(
                        _isSelectionMode
                            ? Icons.close_rounded
                            : Icons.checklist_rounded,
                      ),
                      label: Text(
                        _isSelectionMode ? 'Cancelar' : 'Seleccionar Varios',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_isSelectionMode) {
                          if (_selectedToolIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Selecciona al menos una herramienta',
                                ),
                                backgroundColor: Colors.amber,
                              ),
                            );
                            return;
                          }
                          final seleccionadas = _herramientas
                              .where((h) => _selectedToolIds.contains(h['id']))
                              .toList();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QrPrintSelectorScreen(
                                herramientas: seleccionadas,
                              ),
                            ),
                          ).then((_) {
                            setState(() {
                              _isSelectionMode = false;
                              _selectedToolIds.clear();
                            });
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QrPrintSelectorScreen(
                                herramientas: _herramientas,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.qr_code_rounded),
                      label: Text(
                        _isSelectionMode
                            ? 'Imprimir (${_selectedToolIds.length})'
                            : 'Imprimir QRs',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (_selectedToolIds.length == _herramientas.length) {
                            _selectedToolIds.clear();
                          } else {
                            _selectedToolIds.addAll(
                              _herramientas.map((h) => h['id'] as String),
                            );
                          }
                        });
                      },
                      child: Row(
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              value:
                                  _selectedToolIds.length ==
                                  _herramientas.length,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedToolIds.addAll(
                                      _herramientas.map(
                                        (h) => h['id'] as String,
                                      ),
                                    );
                                  } else {
                                    _selectedToolIds.clear();
                                  }
                                });
                              },
                              activeColor: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Seleccionar todos',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_selectedToolIds.length} seleccionados',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          Expanded(
            child: _isLoading && _herramientas.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _cargarHerramientas,
                    child: _herramientas.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.7,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No hay herramientas registradas en el catálogo.',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final res = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const HerramientasFormScreen(),
                                            ),
                                          );
                                          if (res == true) {
                                            _cargarHerramientas();
                                          }
                                        },
                                        child: const Text(
                                          'Registrar Primera Herramienta',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth > 650) {
                                return GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _herramientas.length,
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 460,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: 2.3,
                                  ),
                                  itemBuilder: (context, index) {
                                    final h = _herramientas[index];
                                    final stock = h['stock'] as int;
                                    final id = h['id'] as String;
                                    final isSelected = _selectedToolIds.contains(id);
                                    return _buildToolCard(h, id, stock, isSelected, colors);
                                  },
                                );
                              } else {
                                return Center(
                                  child: Container(
                                    constraints: const BoxConstraints(maxWidth: 800),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _herramientas.length,
                                      itemBuilder: (context, index) {
                                        final h = _herramientas[index];
                                        return _buildToolItem(h, colors);
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                          )),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HerramientasFormScreen(),
                  ),
                );
                if (res == true) _cargarHerramientas();
              },
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  Future<void> _confirmarEliminarHerramienta(Map<String, dynamic> h) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Herramienta?'),
        content: Text(
          '¿Desea dar de baja la herramienta "${h['nombre']}" del catálogo? Se conservará su historial en la papelera.',
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _repository.eliminarHerramientaLogica(h['id']);
        _cargarHerramientas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${h['nombre']}" eliminada lógicamente.'),
              action: SnackBarAction(
                label: 'Deshacer',
                onPressed: () async {
                  await _repository.restaurarHerramientaLogica(h['id']);
                  _cargarHerramientas();
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _mostrarDetalleHerramienta(Map<String, dynamic> h) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) => _ToolDetailModal(
        herramienta: h,
        repository: _repository,
      ),
    );
  }

  void _mostrarOpcionesMovimiento(
    BuildContext context,
    Map<String, dynamic> herramienta,
    VoidCallback onSuccess,
  ) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) => NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          return true; // Evita overscroll
        },
        child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Registrar Transacción',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona el tipo de movimiento para "${herramienta['nombre']}"',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _irARegistrar(context, herramienta, 'ENTRADA', onSuccess);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                        color: Colors.green.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.login_rounded,
                            color: Colors.green,
                            size: 32,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'ENTRADA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Devolución / Stock',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _irARegistrar(context, herramienta, 'SALIDA', onSuccess);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.3),
                        ),
                        color: colors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: colors.primary,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'SALIDA / PRÉSTAMO',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Préstamo / Baja',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

  void _irARegistrar(
    BuildContext context,
    Map<String, dynamic> herramienta,
    String tipo,
    VoidCallback onSuccess,
  ) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegistrarMovimientoScreen(
          herramienta: herramienta,
          tipoInicial: tipo,
        ),
      ),
    );
    if (res == true) onSuccess();
  }



  Widget _buildToolCard(Map<String, dynamic> h, String id, int stock, bool isSelected, ColorScheme colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedToolIds.remove(id);
              } else {
                _selectedToolIds.add(id);
              }
            });
          } else {
            _mostrarDetalleHerramienta(h);
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            setState(() {
              _isSelectionMode = true;
              _selectedToolIds.add(id);
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              if (_isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedToolIds.add(id);
                      } else {
                        _selectedToolIds.remove(id);
                      }
                    });
                  },
                  activeColor: const Color(0xFF5E60E6),
                ),
                const SizedBox(width: 8),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: h['foto_url'] != null
                    ? (kIsWeb
                        ? Image.network(
                            h['foto_url'],
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 64,
                              height: 64,
                              color: isDark ? const Color(0xFF121624) : Colors.grey.shade100,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: h['foto_url'],
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 64,
                              height: 64,
                              color: isDark ? const Color(0xFF121624) : Colors.grey.shade100,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5E60E6)),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 64,
                              height: 64,
                              color: isDark ? const Color(0xFF121624) : Colors.grey.shade100,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey,
                              ),
                            ),
                          ))
                    : Container(
                        width: 64,
                        height: 64,
                        color: isDark ? const Color(0xFF121624) : Colors.grey.shade100,
                        child: const Icon(
                          Icons.handyman_rounded,
                          color: Colors.grey,
                        ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      h['ubicaciones']?['nombre'] ?? 'Sin ubicación',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stock > 0
                            ? const Color(0xFF059669).withValues(alpha: 0.1)
                            : const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: stock > 0
                              ? const Color(0xFF059669).withValues(alpha: 0.25)
                              : const Color(0xFFEF4444).withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: stock > 0 ? const Color(0xFF059669) : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            stock > 0
                                ? '$stock ${h['unidades_medida']?['abreviatura'] ?? 'Pza'} disp.'
                                : 'Sin stock',
                            style: TextStyle(
                              color: stock > 0 ? const Color(0xFF059669) : const Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Botón de Transacción y opciones Web (Editar / Eliminar)
              if (!_isSelectionMode) ...[
                IconButton(
                  icon: const Icon(
                    Icons.swap_horiz_rounded,
                  ),
                  color: isDark ? Colors.white : colors.primary,
                  tooltip: 'Nueva Transacción',
                  onPressed: () =>
                      _mostrarOpcionesMovimiento(
                        context,
                        h,
                        _cargarHerramientas,
                      ),
                ),
                if (kIsWeb) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    color: const Color(0xFF5E60E6),
                    tooltip: 'Editar Herramienta',
                    onPressed: () async {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              HerramientasFormScreen(
                                herramienta: h,
                              ),
                        ),
                      );
                      if (res == true) {
                        _cargarHerramientas();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Colors.redAccent,
                    tooltip: 'Eliminar Herramienta',
                    onPressed: () =>
                        _confirmarEliminarHerramienta(h),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolItem(Map<String, dynamic> h, ColorScheme colors) {
    final stock = h['stock'] as int;
    final id = h['id'] as String;
    final isSelected = _selectedToolIds.contains(id);

    final cardWidget = _buildToolCard(h, id, stock, isSelected, colors);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: (_isSelectionMode || kIsWeb)
          ? cardWidget
          : Slidable(
              key: ValueKey(id),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.45,
                children: [
                  SlidableAction(
                    onPressed: (context) async {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              HerramientasFormScreen(
                                herramienta: h,
                              ),
                        ),
                      );
                      if (res == true) {
                        _cargarHerramientas();
                      }
                    },
                    backgroundColor: const Color(0xFF5E60E6),
                    foregroundColor: Colors.white,
                    icon: Icons.edit_rounded,
                    label: 'Editar',
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                  ),
                  SlidableAction(
                    onPressed: (context) => _confirmarEliminarHerramienta(h),
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    icon: Icons.delete_outline_rounded,
                    label: 'Eliminar',
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(12),
                    ),
                  ),
                ],
              ),
              child: cardWidget,
            ),
    );
  }
}

class _ToolDetailModal extends StatefulWidget {
  final Map<String, dynamic> herramienta;
  final HerramientasRepository repository;

  const _ToolDetailModal({
    required this.herramienta,
    required this.repository,
  });

  @override
  State<_ToolDetailModal> createState() => _ToolDetailModalState();
}

class _ToolDetailModalState extends State<_ToolDetailModal> {
  late final Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.repository.obtenerEstadisticasMovimientos(widget.herramienta['id']);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.herramienta;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final especificaciones = h['especificaciones'] as Map<String, dynamic>? ?? {};

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        return true; // Detiene la propagación de eventos de scroll
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0D14) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SingleChildScrollView(
          controller: ScrollController(),
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: h['foto_url'] != null
                        ? CachedNetworkImage(
                            imageUrl: h['foto_url'],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey,
                                size: 32,
                              ),
                            ),
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.handyman_rounded,
                              color: Colors.grey,
                              size: 32,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h['nombre'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                h['ubicaciones']?['nombre'] ?? 'Sin ubicación',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Divider(),
              const SizedBox(height: 10),
              const Text(
                'Especificaciones',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),
              _buildSpecRow('Marca:', especificaciones['marca'] ?? 'Sin marca'),
              _buildSpecRow(
                'Modelo:',
                especificaciones['modelo'] ?? 'Sin modelo',
              ),
              _buildSpecRow(
                'Número de Serie:',
                especificaciones['n_serie'] ?? 'Sin número de serie',
              ),
              if (h['descripcion'] != null &&
                  h['descripcion'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  h['descripcion'],
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),

              const Divider(),
              const SizedBox(height: 10),
              const Text(
                'Resumen de Inventario y Valoración',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),

              FutureBuilder<Map<String, int>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(
                        'Error al cargar métricas: ${snapshot.error}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }

                  final stats = snapshot.data!;
                  final stock = h['stock'] as int;
                  final prestadas = stats['prestadas'] ?? 0;
                  final perdidas = stats['perdidas'] ?? 0;
                  final descompostura = stats['descompostura'] ?? 0;
                  final costoPromedio =
                      double.tryParse(h['costo_promedio'].toString()) ?? 0.0;
                  final valorTotal = stock * costoPromedio;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Disponibles',
                              value:
                                  '$stock ${h['unidades_medida']?['abreviatura'] ?? 'Pza'}',
                              icon: Icons.check_circle_outline_rounded,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Prestados',
                              value:
                                  '$prestadas ${h['unidades_medida']?['abreviatura'] ?? 'Pza'}',
                              icon: Icons.handshake_outlined,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Bajas Pérdida',
                              value:
                                  '$perdidas ${h['unidades_medida']?['abreviatura'] ?? 'Pza'}',
                              icon: Icons.search_off_rounded,
                              color: Colors.red.shade400,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Bajas Daño',
                              value:
                                  '$descompostura ${h['unidades_medida']?['abreviatura'] ?? 'Pza'}',
                              icon: Icons.build_circle_outlined,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5E60E6).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF5E60E6).withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Valor Total Inventariado',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${valorTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5E60E6),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Costo Promedio',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${costoPromedio.toStringAsFixed(2)} c/u',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              SafeArea(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            QrPrintSelectorScreen(herramientas: [h]),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_rounded),
                  label: const Text('Imprimir QR'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
