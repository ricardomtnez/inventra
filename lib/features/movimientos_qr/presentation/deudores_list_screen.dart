import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _fetchLoans();
    _suscribirRealtime();
  }

  void _suscribirRealtime() {
    try {
      _realtimeChannel = SupabaseClientHelper.client
          .channel('public:deudores_updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'prestamos',
            callback: (payload) => _fetchLoans(),
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error en realtime deudores: $e');
    }
  }

  void refresh() {
    _fetchLoans();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
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
              'Préstamos Activos',
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterLoans,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return newValue.copyWith(
                        text: newValue.text.toUpperCase(),
                      );
                    }),
                  ],
                  style: AppTextStyles.bodyMd
                      .copyWith(color: AppColors.textPrimaryDark),
                  decoration: InputDecoration(
                    hintText: 'Buscar responsable, matrícula, herramienta...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _filterLoans('');
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: AppColors.accentTeal,
              backgroundColor: AppColors.bgDarkSecondary,
              onRefresh: _fetchLoans,
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          color: AppColors.accentTeal,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : _filteredLoans.isEmpty
                      ? _buildEmptyState()
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 650) {
                              return GridView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredLoans.length,
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 460,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 1.6,
                                    ),
                                itemBuilder: (_, index) =>
                                    _buildDeudorCard(_filteredLoans[index]),
                              );
                            } else {
                              return Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 800),
                                  child: ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                    itemCount: _filteredLoans.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, index) =>
                                        _buildDeudorCard(_filteredLoans[index]),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _searchQuery.isNotEmpty
                        ? AppColors.bgDarkSecondary
                        : AppColors.accentTealDim,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _searchQuery.isNotEmpty
                          ? AppColors.bgDarkBorder
                          : AppColors.accentTeal.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    _searchQuery.isNotEmpty
                        ? Icons.search_off_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 32,
                    color: _searchQuery.isNotEmpty
                        ? AppColors.textMutedDark
                        : AppColors.accentTeal,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Sin resultados'
                      : '¡Sin préstamos pendientes!',
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Intenta otros términos de búsqueda.'
                      : 'Todos los préstamos han sido devueltos.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textMutedDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeudorCard(Map<String, dynamic> loan) {
    final tool = loan['herramientas'] ?? {};
    final folio = loan['folio'] ?? 0;
    final cantTotal = loan['cantidad'] as int? ?? 0;
    final cantDev = loan['cantidad_devuelta'] as int? ?? 0;
    final pending = cantTotal - cantDev;
    final estado = loan['estado'] ?? 'ACTIVO';
    final fechaStr = loan['fecha_prestamo'] ?? '';
    final responsable = loan['responsable_nombre'] ?? 'Sin nombre';
    final matricula = loan['matricula'] ?? '';

    // Calcular días transcurridos
    int diasTranscurridos = 0;
    if (fechaStr.isNotEmpty) {
      try {
        final fechaDt = DateTime.parse(fechaStr).toLocal();
        diasTranscurridos = DateTime.now().difference(fechaDt).inDays;
      } catch (_) {}
    }

    final bool isUrgente = diasTranscurridos >= 3;
    final Color urgenciaColor =
        isUrgente ? AppColors.accentRed : AppColors.accentAmber;

    // Initial del responsable
    final String initial = responsable.isNotEmpty
        ? responsable[0].toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgDarkSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUrgente
                ? AppColors.accentRed.withValues(alpha: 0.25)
                : AppColors.bgDarkBorder,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: folio + estado badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'VALE-${folio.toString().padLeft(6, '0')}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMutedDark,
                    fontFamily: 'Inter',
                  ),
                ),
                Row(
                  children: [
                    if (diasTranscurridos > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: urgenciaColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: urgenciaColor.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          '${diasTranscurridos}d',
                          style: AppTextStyles.overline.copyWith(
                            color: urgenciaColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: estado == 'PARCIAL'
                            ? const Color(0xFF0D2A3D)
                            : AppColors.accentAmberDim,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        estado,
                        style: AppTextStyles.overline.copyWith(
                          color: estado == 'PARCIAL'
                              ? const Color(0xFF40C4FF)
                              : AppColors.accentAmber,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Body: avatar + info + foto herramienta
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentTealDim,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: AppColors.accentTeal.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: AppTextStyles.headlineMd.copyWith(
                      color: AppColors.accentTeal,
                      fontFamily: 'DMSans',
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info responsable + herramienta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        responsable,
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (matricula.isNotEmpty)
                        Text(
                          matricula,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        tool['nombre'] ?? 'Sin herramienta',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textSecondaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Foto de herramienta
                if (tool['foto_url'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: tool['foto_url'],
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 48,
                        height: 48,
                        color: AppColors.bgDarkTertiary,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: AppColors.bgDarkTertiary,
                        child: const Icon(
                          Icons.handyman_rounded,
                          color: AppColors.textMutedDark,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Footer: pendiente + fecha + botón devolver
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgDarkTertiary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PENDIENTE',
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.textMutedDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$pending de $cantTotal ${tool['unidades_medida']?['abreviatura'] ?? 'Pza'}',
                        style: AppTextStyles.dataMd.copyWith(
                          color: urgenciaColor,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final String? grupoId = loan['grupo_id'] as String?;
                      if (grupoId != null && grupoId.isNotEmpty) {
                        try {
                          final client = SupabaseClientHelper.client;
                          final loansInGroup = await client
                              .from('prestamos')
                              .select('*, herramientas(*, ubicaciones(nombre), unidades_medida(abreviatura, nombre))')
                              .eq('grupo_id', grupoId)
                              .neq('estado', 'DEVUELTO')
                              .order('fecha_prestamo', ascending: true);

                          if (loansInGroup.length > 1) {
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegistrarMovimientoScreen(
                                  herramientas: loansInGroup.map((l) => l['herramientas'] as Map<String, dynamic>).toList(),
                                  tipoInicial: 'ENTRADA',
                                  prestamosIniciales: List<Map<String, dynamic>>.from(loansInGroup),
                                ),
                              ),
                            ).then((result) {
                              if (result == true) _fetchLoans();
                            });
                            return;
                          }
                        } catch (e) {
                          debugPrint('Error fetching group loans: $e');
                        }
                      }

                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegistrarMovimientoScreen(
                            herramienta: tool,
                            tipoInicial: 'ENTRADA',
                            prestamoInicial: loan,
                          ),
                        ),
                      ).then((result) {
                        if (result == true) _fetchLoans();
                      });
                    },
                    icon: const Icon(Icons.assignment_turned_in_rounded,
                        size: 16),
                    label: const Text('Devolver'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentTeal,
                      foregroundColor: const Color(0xFF001F1A),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: AppTextStyles.labelMd,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
