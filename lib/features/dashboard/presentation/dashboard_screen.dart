import 'package:flutter/material.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_screen.dart';
import '../../herramientas_catalogo/presentation/herramientas_list.dart';
import '../../movimientos_qr/presentation/scanner_view.dart';
import '../../../core/supabase/supabase_client.dart';

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

  @override
  void initState() {
    super.initState();
    _cargarMetricas();
  }

  Future<void> _cargarMetricas() async {
    try {
      final client = SupabaseClientHelper.client;
      
      // 1. Obtener total de herramientas
      final countRes = await client.from('herramientas').select('stock');
      int total = 0;
      for (var row in countRes) {
        total += (row['stock'] as int);
      }

      // 2. Obtener préstamos activos (Movimientos de salida por préstamo - devoluciones de préstamo)
      final movimientos = await client.from('movimientos').select('tipo, motivo, cantidad');
      int prestadas = 0;
      for (var m in movimientos) {
        if (m['tipo'] == 'SALIDA' && m['motivo'] == 'PRESTAMO_ALUMNO_PROFESOR') {
          prestadas += (m['cantidad'] as int);
        } else if (m['tipo'] == 'ENTRADA' && m['motivo'] == 'DEVOLUCION_PRESTAMO') {
          prestadas -= (m['cantidad'] as int);
        }
      }

      setState(() {
        _totalHerramientas = total;
        _prestamosActivos = prestadas < 0 ? 0 : prestadas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración', style: TextStyle(fontWeight: FontWeight.bold)),
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
          )
        ],
      ),
      body: RefreshIndicator(
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
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: LinearProgressIndicator(),
                    )
                  else ...[
                // Tarjetas KPI
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Acciones Rápidas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Botones de acción rápida
                _buildActionButton(
                  title: 'Escanear QR de Herramienta',
                  subtitle: 'Registrar préstamo, devolución o baja',
                  icon: Icons.qr_code_scanner_rounded,
                  color: colors.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ScannerView()),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  title: 'Catálogo de Herramientas',
                  subtitle: 'Gestionar equipos, stock e imprimir QRs',
                  icon: Icons.format_list_bulleted_rounded,
                  color: colors.secondary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HerramientasListScreen()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildKPICard({required String title, required String value, required IconData icon, required Color color}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
