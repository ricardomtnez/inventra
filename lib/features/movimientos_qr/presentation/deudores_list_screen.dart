import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/supabase/supabase_client.dart';
import 'registrar_movimiento_screen.dart';

class DeudoresListScreen extends StatefulWidget {
  const DeudoresListScreen({super.key});

  @override
  State<DeudoresListScreen> createState() => _DeudoresListScreenState();
}

class _DeudoresListScreenState extends State<DeudoresListScreen> {
  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _filteredLoans = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLoans();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLoans() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseClientHelper.client;
      final res = await client
          .from('prestamos')
          .select(
            '*, herramientas(*, ubicaciones(nombre), unidades_medida(abreviatura, nombre))',
          )
          .neq('estado', 'DEVUELTO')
          .order('fecha_prestamo', ascending: false);

      final List<Map<String, dynamic>> fetched =
          List<Map<String, dynamic>>.from(res);
      setState(() {
        _loans = fetched;
        _filterLoans(_searchQuery);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener deudores: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _filterLoans(String query) {
    setState(() {
      _searchQuery = query;
      if (query.trim().isEmpty) {
        _filteredLoans = _loans;
      } else {
        final q = query.toLowerCase().trim();
        _filteredLoans = _loans.where((loan) {
          final responsable = (loan['responsable_nombre'] ?? '')
              .toString()
              .toLowerCase();
          final matricula = (loan['matricula'] ?? '').toString().toLowerCase();
          final folio = 'vale-${loan['folio']}'.toLowerCase();
          final herramienta = (loan['herramientas']?['nombre'] ?? '')
              .toString()
              .toLowerCase();
          return responsable.contains(q) ||
              matricula.contains(q) ||
              folio.contains(q) ||
              herramienta.contains(q);
        }).toList();
      }
    });
  }

  String _formatFecha(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final monthNames = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = monthNames[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$min';
    } catch (e) {
      return dateStr.split('.')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Préstamos Activos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchLoans,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Búsqueda Premium
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterLoans,
              decoration: InputDecoration(
                hintText:
                    'Buscar por responsable, matrícula, folio o herramienta...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _filterLoans('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchLoans,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredLoans.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _searchQuery.isNotEmpty
                                          ? Icons.search_off_rounded
                                          : Icons.check_circle_outline_rounded,
                                      size: 72,
                                      color: colors.primary.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No se encontraron deudores que coincidan'
                                          : '¡Sin adeudos pendientes!',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Prueba modificando los términos de búsqueda.'
                                          : 'Todos los préstamos han sido devueltos a tiempo.',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredLoans.length,
                          itemBuilder: (context, index) {
                            final loan = _filteredLoans[index];
                            final tool = loan['herramientas'] ?? {};
                            final folio = loan['folio'] ?? 0;
                            final cantTotal = loan['cantidad'] as int? ?? 0;
                            final cantDev = loan['cantidad_devuelta'] as int? ?? 0;
                            final pending = cantTotal - cantDev;
                            final estado = loan['estado'] ?? 'ACTIVO';
                            final fechaStr = loan['fecha_prestamo'] ?? '';
                            final responsable =
                                loan['responsable_nombre'] ?? 'Sin nombre';
                            final matricula = loan['matricula'] ?? 'Sin matrícula';

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: colors.outline.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Encabezado con Folio y Estado
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'VALE-${folio.toString().padLeft(6, '0')}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: colors.primary,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: estado == 'PARCIAL'
                                                ? Colors.blue.withValues(alpha: 0.1)
                                                : Colors.amber.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            estado,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: estado == 'PARCIAL'
                                                  ? Colors.blue.shade700
                                                  : Colors.amber.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Detalles del Deudor y Herramienta
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Imagen de la herramienta
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: tool['foto_url'] != null
                                              ? CachedNetworkImage(
                                                  imageUrl: tool['foto_url'],
                                                  width: 55,
                                                  height: 55,
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, __) => Container(
                                                    width: 55,
                                                    height: 55,
                                                    color: Colors.grey.shade200,
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (_, __, ___) =>
                                                      Container(
                                                        width: 55,
                                                        height: 55,
                                                        color: Colors.grey.shade200,
                                                        child: const Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          color: Colors.grey,
                                                          size: 20,
                                                        ),
                                                      ),
                                                )
                                              : Container(
                                                  width: 55,
                                                  height: 55,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.handyman_rounded,
                                                    color: Colors.grey,
                                                    size: 20,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Texto
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                responsable,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Matrícula: $matricula',
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Herramienta: ${tool['nombre'] ?? 'Desconocido'}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Pendiente: $pending ${tool['unidades_medida']?['abreviatura'] ?? 'Pza'} (de $cantTotal total)',
                                                style: TextStyle(
                                                  color: Colors.red.shade700,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // Footer con fecha y botón de Devolución
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'FECHA DE PRÉSTAMO',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatFecha(fechaStr),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    RegistrarMovimientoScreen(
                                                      herramienta: tool,
                                                      tipoInicial: 'ENTRADA',
                                                      prestamoInicial: loan,
                                                    ),
                                              ),
                                            ).then((result) {
                                              if (result == true) {
                                                _fetchLoans();
                                              }
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green.shade700,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                10,
                                              ),
                                            ),
                                            elevation: 0,
                                          ),
                                          icon: const Icon(
                                            Icons.assignment_turned_in_rounded,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Devolver',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
