import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_screen.dart';
import '../../herramientas_catalogo/presentation/herramientas_list.dart';
import '../../movimientos_qr/presentation/scanner_view.dart';
import '../../movimientos_qr/presentation/historial_movimientos_screen.dart';
import '../../movimientos_qr/presentation/deudores_list_screen.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

// ── Shell de navegación principal ─────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  StreamSubscription<AuthState>? _authSubscription;
  final GlobalKey<_HomeTabState> _homeTabKey = GlobalKey<_HomeTabState>();
  final GlobalKey _herramientasKey = GlobalKey();
  final GlobalKey _deudoresKey = GlobalKey();
  final GlobalKey _historialKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _escucharAuthState();
  }

  void _escucharAuthState() {
    _authSubscription =
        SupabaseClientHelper.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _refrescarTodasLasPestanas() {
    _homeTabKey.currentState?.refresh();
    (_herramientasKey.currentState as dynamic)?.refresh();
    (_deudoresKey.currentState as dynamic)?.refresh();
    (_historialKey.currentState as dynamic)?.refresh();
  }

  void _onTabChanged(int index) {
    // Tab del scanner abre modal, no cambia de pantalla
    if (index == 2) {
      HapticFeedback.mediumImpact();
      _mostrarMenuScanner();
      return;
    }
    HapticFeedback.selectionClick();
    
    // Al tocar cualquier pestaña, refrescamos el contenido de esa pestaña
    if (index == 0) {
      _homeTabKey.currentState?.refresh();
    } else if (index == 1) {
      (_herramientasKey.currentState as dynamic)?.refresh();
    } else if (index == 3) {
      (_historialKey.currentState as dynamic)?.refresh();
    } else if (index == 4) {
      (_deudoresKey.currentState as dynamic)?.refresh();
    }
    
    setState(() => _selectedIndex = index);
  }

  void _mostrarMenuScanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => _ScannerModal(
        onEntrada: () async {
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ScannerView(defaultTipo: 'ENTRADA')),
          );
          _refrescarTodasLasPestanas();
        },
        onSalida: () async {
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ScannerView(defaultTipo: 'SALIDA')),
          );
          _refrescarTodasLasPestanas();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mapear el _selectedIndex al índice del IndexedStack
    int stackIndex = 0;
    if (_selectedIndex == 1) {
      stackIndex = 1;
    } else if (_selectedIndex == 3) {
      stackIndex = 3;
    } else if (_selectedIndex == 4) {
      stackIndex = 2;
    }

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _homeTabKey.currentState?.refresh();
        setState(() => _selectedIndex = 0);
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: AppColors.bgDark,
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: IndexedStack(
                  index: stackIndex,
                  children: [
                    _HomeTab(key: _homeTabKey),
                    HerramientasListScreen(key: _herramientasKey),
                    DeudoresListScreen(key: _deudoresKey),
                    HistorialMovimientosScreen(key: _historialKey),
                  ],
                ),
              ),
            ],
          ),
          // ── Bottom Navigation Bar ──────────────────────────────────────────
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgDarkSecondary,
        border: Border(
          top: BorderSide(color: AppColors.bgDarkBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Inicio',
                isActive: _selectedIndex == 0,
                onTap: () => _onTabChanged(0),
              ),
              _NavItem(
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
                label: 'Inventario',
                isActive: _selectedIndex == 1,
                onTap: () => _onTabChanged(1),
              ),
              // Centro: botón de scanner destacado
              _ScannerNavButton(onTap: () => _onTabChanged(2)),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Historial',
                isActive: _selectedIndex == 3,
                onTap: () => _onTabChanged(3),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Préstamos',
                isActive: _selectedIndex == 4,
                onTap: () => _onTabChanged(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  size: 24,
                  color: isActive
                      ? AppColors.accentTeal
                      : AppColors.textMutedDark,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTextStyles.caption.copyWith(
                  color: isActive
                      ? AppColors.accentTeal
                      : AppColors.textMutedDark,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 10,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Scanner Center Button ─────────────────────────────────────────────────────
class _ScannerNavButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ScannerNavButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.tealGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentTeal.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFF001F1A),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Escanear',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accentTeal,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Home Tab (KPI Dashboard) ──────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab({super.key});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;


  bool _isLoading = true;
  Map<String, dynamic>? _currentProfile;

  // ── KPI Data ────────────────────────────────────────────────────────────
  int _totalHerramientas = 0;
  int _stockTotal = 0;
  int _prestamosActivos = 0;
  int _herramientasDisponibles = 0;
  int _bajasMes = 0;
  double _valorInventario = 0.0;
  List<Map<String, dynamic>> _ultimosMovimientos = [];
  List<Map<String, dynamic>> _alertasStock = [];

  RealtimeChannel? _realtimeChannel;
  late final AnimationController _enterController;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _cargarTodo();
    _suscribirRealtime();
  }

  void _suscribirRealtime() {
    try {
      _realtimeChannel = SupabaseClientHelper.client
          .channel('public:kpi_updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'movimientos',
            callback: (payload) => _cargarTodo(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'prestamos',
            callback: (payload) => _cargarTodo(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'herramientas',
            callback: (payload) => _cargarTodo(),
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error registrando suscripción Realtime: $e');
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _enterController.dispose();
    super.dispose();
  }

  void refresh() {
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarPerfil(),
      _cargarKPIs(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cargarPerfil() async {
    try {
      final user = SupabaseClientHelper.client.auth.currentUser;
      if (user != null) {
        final profile = await SupabaseClientHelper.client
            .from('perfiles')
            .select('nombre_completo, correo, matricula')
            .eq('id', user.id)
            .single();
        if (mounted) setState(() => _currentProfile = profile);
      }
    } catch (e) {
      debugPrint('Error profile: $e');
    }
  }

  Future<void> _cargarKPIs() async {
    try {
      final client = SupabaseClientHelper.client;

      // Herramientas activas + stock disponible en almacén + valor
      final toolsRes = await client
          .from('herramientas')
          .select('stock, costo_promedio, activo');

      int totalHerramientas = 0;
      int stockDisponiblesEnAlmacen = 0;
      double valorTotal = 0.0;
      for (var r in toolsRes) {
        final isActivo = r['activo'] as bool? ?? true;
        if (!isActivo) continue;
        totalHerramientas++;
        final stock = r['stock'] as int? ?? 0;
        stockDisponiblesEnAlmacen += stock;
        valorTotal += stock * ((r['costo_promedio'] as num?)?.toDouble() ?? 0.0);
      }

      // Préstamos activos (pendientes en campo)
      int prestadas = 0;
      try {
        final prestamosRes = await client
            .from('prestamos')
            .select('cantidad, cantidad_devuelta, estado');

        for (var p in prestamosRes) {
          final estado = p['estado'] as String? ?? 'ACTIVO';
          if (estado == 'DEVUELTO') continue;
          final cant = p['cantidad'] as int? ?? 0;
          final dev = p['cantidad_devuelta'] as int? ?? 0;
          prestadas += (cant - dev);
        }
      } catch (e) {
        debugPrint('Error prestamos count: $e');
      }

      // Herramientas con stock bajo (stock <= 2, umbral configurable)
      final alertasRes = await client
          .from('herramientas')
          .select('nombre, stock, foto_url')
          .or('activo.is.null,activo.eq.true')
          .lte('stock', 2)
          .order('stock', ascending: true)
          .limit(5);

      // Bajas del mes actual (suma de cantidad física dada de baja)
      final now = DateTime.now();
      final inicioMes = DateTime(now.year, now.month, 1).toIso8601String();
      int bajasContador = 0;
      try {
        final bajasRes = await client
            .from('movimientos')
            .select('cantidad')
            .eq('tipo', 'SALIDA')
            .or('motivo.eq.BAJA_DESCOMPOSTURA,motivo.eq.BAJA_PERDIDA')
            .gte('fecha', inicioMes);
        for (var b in bajasRes) {
          bajasContador += (b['cantidad'] as int? ?? 0);
        }
      } catch (e) {
        debugPrint('Error bajas count: $e');
      }

      // Últimos 5 movimientos
      List<Map<String, dynamic>> ultimosMovs = [];
      try {
        final movRes = await client
            .from('movimientos')
            .select('tipo, fecha, herramientas(nombre), responsable_nombre, cantidad')
            .order('fecha', ascending: false)
            .limit(5);
        ultimosMovs = List<Map<String, dynamic>>.from(movRes);
      } catch (e) {
        debugPrint('Error ultimos movs: $e');
      }

      if (mounted) {
        setState(() {
          _totalHerramientas = totalHerramientas;
          _herramientasDisponibles = stockDisponiblesEnAlmacen;
          _prestamosActivos = prestadas < 0 ? 0 : prestadas;
          _stockTotal = stockDisponiblesEnAlmacen + _prestamosActivos;
          _bajasMes = bajasContador;
          _valorInventario = valorTotal;
          _alertasStock = List<Map<String, dynamic>>.from(alertasRes);
          _ultimosMovimientos = ultimosMovs;
        });
      }
    } catch (e) {
      debugPrint('Error KPIs: $e');
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String get _userName {
    final name = _currentProfile?['nombre_completo']?.toString() ?? '';
    final parts = name.split(' ');
    return parts.isNotEmpty ? parts[0] : 'Admin';
  }

  String get _userInitial {
    final name = _currentProfile?['nombre_completo']?.toString() ?? '';
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: AppColors.accentTeal,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

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
              'Inicio',
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _mostrarModalPerfil,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppColors.accentTealDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.accentTeal.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _userInitial,
                style: AppTextStyles.labelLg.copyWith(
                  color: AppColors.accentTeal,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accentTeal,
        backgroundColor: AppColors.bgDarkSecondary,
        onRefresh: _cargarTodo,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),

            // ── KPI Grid principal ─────────────────────────────────
            _buildKPIGrid(),
            const SizedBox(height: 28),

                // ── Alertas de stock bajo ──────────────────────────────
                if (_alertasStock.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Stock Bajo',
                    Icons.warning_amber_rounded,
                    AppColors.accentRed,
                    subtitle: '${_alertasStock.length} herramienta(s) críticas',
                  ),
                  const SizedBox(height: 12),
                  _buildStockAlerts(),
                  const SizedBox(height: 28),
                ],

                // ── Últimas actividad ──────────────────────────────────
                if (_ultimosMovimientos.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Actividad Reciente',
                    Icons.timeline_rounded,
                    AppColors.accentTeal,
                  ),
                  const SizedBox(height: 12),
                  _buildRecentActivity(),
                ],
              ],
            ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _enterController,
      builder: (_, child) => Opacity(
        opacity: _enterController.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - _enterController.value)),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_greeting, $_userName',
            style: AppTextStyles.headlineMd.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Resumen de hoy',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarModalPerfil() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgDarkSecondary : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.bgDarkBorder : AppColors.bgLightBorder,
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.bgDarkBorder : AppColors.bgLightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.accentTealDim,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.accentTeal.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _userInitial,
                      style: AppTextStyles.displaySm.copyWith(
                        color: AppColors.accentTeal,
                        fontFamily: 'DMSans',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentProfile?['nombre_completo'] ?? 'Administrador',
                          style: AppTextStyles.headlineMd.copyWith(
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentProfile?['correo'] ?? '',
                          style: AppTextStyles.bodySm.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_currentProfile?['matricula'] != null) ...[
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Matrícula',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    Text(
                      _currentProfile?['matricula'] ?? '',
                      style: AppTextStyles.headlineSm.copyWith(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final navigator = Navigator.of(context);
                    await AuthRepository().logout();
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/images/key_solutions_logo.png',
                      width: 16,
                      height: 16,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Desarrollado por Key Solutions Technology',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark.withValues(alpha: 0.6)
                          : AppColors.textSecondaryLight.withValues(alpha: 0.6),
                      fontSize: 10,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── KPI GRID ──────────────────────────────────────────────────────────────
  Widget _buildKPIGrid() {
    // Formatear valor del inventario
    final valorStr = _valorInventario >= 1000
        ? '\$${(_valorInventario / 1000).toStringAsFixed(1)}K'
        : '\$${_valorInventario.toStringAsFixed(0)}';

    final kpis = [
      _KpiData(
        label: 'Herramientas',
        value: '$_totalHerramientas',
        icon: Icons.handyman_rounded,
        color: AppColors.accentTeal,
        sublabel: 'tipos en catálogo',
        index: 0,
      ),
      _KpiData(
        label: 'Stock Total',
        value: '$_stockTotal',
        icon: Icons.layers_rounded,
        color: const Color(0xFF7C83FD),
        sublabel: 'piezas en sistema',
        index: 1,
      ),
      _KpiData(
        label: 'Disponibles',
        value: '$_herramientasDisponibles',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.accentGreen,
        sublabel: 'listas para usar',
        index: 2,
      ),
      _KpiData(
        label: 'Prestadas',
        value: '$_prestamosActivos',
        icon: Icons.swap_horiz_rounded,
        color: AppColors.accentAmber,
        sublabel: 'en préstamo activo',
        index: 3,
      ),
      _KpiData(
        label: 'Bajas',
        value: '$_bajasMes',
        icon: Icons.remove_circle_outline_rounded,
        color: AppColors.accentRed,
        sublabel: 'este mes',
        index: 4,
      ),
      _KpiData(
        label: 'Valor Est.',
        value: valorStr,
        icon: Icons.attach_money_rounded,
        color: const Color(0xFF4DD0E1),
        sublabel: 'valor del inventario',
        index: 5,
      ),
    ];

    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 900 ? 6 : (c.maxWidth > 550 ? 3 : 2);
      final ratio = cols >= 6 ? 1.4 : (cols == 3 ? 1.25 : 1.1);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: ratio,
        children: kpis.map((k) => _buildKPICard(k)).toList(),
      );
    });
  }

  Widget _buildKPICard(_KpiData kpi) {
    return AnimatedBuilder(
      animation: _enterController,
      builder: (_, child) {
        final delay = kpi.index * 0.12;
        final t = ((_enterController.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgDarkSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.bgDarkBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kpi.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(kpi.icon, color: kpi.color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kpi.value,
                  style: AppTextStyles.dataHero.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kpi.label,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
                Text(
                  kpi.sublabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMutedDark,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── SECTION HEADER ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMutedDark,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── STOCK ALERTS ──────────────────────────────────────────────────────────
  Widget _buildStockAlerts() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgDarkSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentRed.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: _alertasStock.asMap().entries.map((entry) {
          final i = entry.key;
          final tool = entry.value;
          final stock = tool['stock'] as int? ?? 0;
          final isLast = i == _alertasStock.length - 1;
          final urgency = stock == 0 ? AppColors.accentRed : AppColors.accentAmber;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: urgency,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tool['nombre'] ?? 'Sin nombre',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgency.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stock == 0 ? 'Sin stock' : 'Stock: $stock',
                        style: AppTextStyles.labelSm.copyWith(
                          color: urgency,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: AppColors.bgDarkBorder,
                  indent: 36,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── RECENT ACTIVITY ───────────────────────────────────────────────────────
  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgDarkSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDarkBorder, width: 1),
      ),
      child: Column(
        children: _ultimosMovimientos.asMap().entries.map((entry) {
          final i = entry.key;
          final m = entry.value;
          final tipo = m['tipo'] as String? ?? 'ENTRADA';
          final isEntrada = tipo == 'ENTRADA';
          final toolName = m['herramientas']?['nombre'] ?? 'N/A';
          final responsable = m['responsable_nombre'] ?? '';
          final cantidad = m['cantidad'] as int? ?? 0;
          final fecha = DateTime.tryParse(m['fecha'] ?? '');
          final timeStr = fecha != null
              ? '${fecha.toLocal().hour.toString().padLeft(2, '0')}:${fecha.toLocal().minute.toString().padLeft(2, '0')}'
              : '';
          final typeColor = isEntrada ? AppColors.accentGreen : AppColors.accentAmber;
          final isLast = i == _ultimosMovimientos.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Dot timeline
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEntrada
                            ? Icons.login_rounded
                            : Icons.logout_rounded,
                        color: typeColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            toolName,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.textPrimaryDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (responsable.isNotEmpty)
                            Text(
                              responsable,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isEntrada ? '+' : '−'}$cantidad',
                          style: AppTextStyles.dataMd.copyWith(
                            color: typeColor,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMutedDark,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: AppColors.bgDarkBorder,
                  indent: 60,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}


// ── Data models ───────────────────────────────────────────────────────────────
class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String sublabel;
  final int index;
  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sublabel,
    required this.index,
  });
}

// ── Scanner Modal ─────────────────────────────────────────────────────────────
class _ScannerModal extends StatelessWidget {
  final VoidCallback onEntrada;
  final VoidCallback onSalida;

  const _ScannerModal({
    required this.onEntrada,
    required this.onSalida,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgDarkSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.bgDarkBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.bgDarkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Escanear QR',
            style: AppTextStyles.headlineMd.copyWith(
              color: AppColors.textPrimaryDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Selecciona el tipo de movimiento',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textSecondaryDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(child: _ScanOption(icon: Icons.login_rounded, label: 'ENTRADA', sublabel: 'Devolución · Stock', color: AppColors.accentGreen, onTap: onEntrada)),
              const SizedBox(width: 14),
              Expanded(child: _ScanOption(icon: Icons.logout_rounded, label: 'SALIDA', sublabel: 'Préstamo · Baja', color: AppColors.accentAmber, onTap: onSalida)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ScanOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _ScanOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 14),
              Text(label, style: AppTextStyles.headlineSm.copyWith(color: color)),
              const SizedBox(height: 4),
              Text(sublabel, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryDark), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
