import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_screen.dart';
import '../../herramientas_catalogo/presentation/herramientas_list.dart';
import '../../movimientos_qr/presentation/scanner_view.dart';
import '../../movimientos_qr/presentation/historial_movimientos_screen.dart';
import '../../movimientos_qr/presentation/deudores_list_screen.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/widgets/offline_banner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authRepository = AuthRepository();
  int _totalHerramientas = 0;
  int _prestamosActivos = 0;
  bool _isLoading = true;
  StreamSubscription<AuthState>? _authSubscription;
  Map<String, dynamic>? _currentProfile;

  @override
  void initState() {
    super.initState();
    _cargarMetricas();
    _escucharAuthState();
    _obtenerPerfilUsuario();
  }

  Future<void> _obtenerPerfilUsuario() async {
    try {
      final user = SupabaseClientHelper.client.auth.currentUser;
      if (user != null) {
        final profile = await SupabaseClientHelper.client
            .from('perfiles')
            .select('nombre_completo, correo, matricula')
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _currentProfile = profile;
          });
        }
      }
    } catch (e) {
      debugPrint('Error obtaining dashboard profile: $e');
    }
  }

  void _escucharAuthState() {
    _authSubscription = SupabaseClientHelper.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
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

  Future<void> _cargarMetricas({bool background = false}) async {
    if (_totalHerramientas == 0 && !background) {
      setState(() => _isLoading = true);
    }
    try {
      final client = SupabaseClientHelper.client;

      // 1. Obtener total de herramientas (solo activas)
      final countRes = await client.from('herramientas').select('stock').eq('activo', true);
      int total = 0;
      for (var row in countRes) {
        total += (row['stock'] as int);
      }

      // 2. Obtener préstamos activos de la tabla 'prestamos'
      final prestamosRes = await client
          .from('prestamos')
          .select('cantidad, cantidad_devuelta')
          .neq('estado', 'DEVUELTO');
      
      int prestadas = 0;
      for (var p in prestamosRes) {
        final cant = p['cantidad'] as int? ?? 0;
        final dev = p['cantidad_devuelta'] as int? ?? 0;
        prestadas += (cant - dev);
      }

      if (mounted) {
        setState(() {
          _totalHerramientas = total;
          _prestamosActivos = prestadas < 0 ? 0 : prestadas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panel de Administración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _authRepository.logout();
              navigator.pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: _isLoading && _totalHerramientas == 0
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF5E60E6)))
                : RefreshIndicator(
                    onRefresh: _cargarMetricas,
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              // Welcome Header Banner
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: colors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      (_currentProfile != null && _currentProfile!['nombre_completo'] != null)
                                          ? _currentProfile!['nombre_completo'].toString().substring(0, 1).toUpperCase()
                                          : 'A',
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Hola, ${_currentProfile?['nombre_completo'] ?? 'Administrador'} 👋',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Gestión de stock y préstamos en tiempo real',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              
                              // KPI Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildKPICard(
                                      title: 'Herramientas Totales',
                                      value: '$_totalHerramientas',
                                      icon: Icons.inventory_2_outlined,
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildKPICard(
                                      title: 'Préstamos Activos',
                                      value: '$_prestamosActivos',
                                      icon: Icons.handshake_outlined,
                                      color: Colors.amber.shade700,
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const DeudoresListScreen(),
                                          ),
                                        );
                                        _cargarMetricas(background: true);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                'Acciones Rápidas',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Botones de acción rápida
                              _buildActionButton(
                                title: 'Escanear QR de Herramienta',
                                subtitle:
                                    'Registrar Entradas, Prestamos, Salidas o Bajas de herramienta',
                                icon: Icons.qr_code_scanner_rounded,
                                color: colors.primary,
                                onTap: () => _mostrarMenuScanner(context),
                              ),
                              const SizedBox(height: 16),
                              _buildActionButton(
                                title: 'Préstamos Activos (Deudores)',
                                subtitle:
                                    'Ver alumnos/profesores con herramientas pendientes',
                                icon: Icons.people_outline_rounded,
                                color: Colors.amber.shade800,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const DeudoresListScreen(),
                                    ),
                                  );
                                  _cargarMetricas(background: true);
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildActionButton(
                                title: 'Catálogo de Herramientas',
                                subtitle:
                                    'Gestionar equipos, stock e imprimir QRs',
                                icon: Icons.format_list_bulleted_rounded,
                                color: colors.secondary,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const HerramientasListScreen(),
                                    ),
                                  );
                                  _cargarMetricas(background: true);
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildActionButton(
                                title: 'Historial de Movimientos',
                                subtitle:
                                    'Consultar y corregir registros de entrada/salida',
                                icon: Icons.history_rounded,
                                color: Colors.teal,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const HistorialMovimientosScreen(),
                                    ),
                                  );
                                  _cargarMetricas(background: true);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _mostrarMenuScanner(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) => Container(
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
              'Escanear Código QR',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona qué tipo de movimiento deseas registrar al escanear la herramienta',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _abrirScanner(context, 'ENTRADA');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        color: Colors.green.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.login_rounded, color: Colors.green, size: 32),
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
                      _abrirScanner(context, 'SALIDA');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                        color: colors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.logout_rounded, color: colors.primary, size: 32),
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
    );
  }

  void _abrirScanner(BuildContext context, String tipo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerView(defaultTipo: tipo),
      ),
    );
    _cargarMetricas(background: true);
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (onTap != null)
                    Icon(Icons.arrow_forward_rounded, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8), size: 18),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
