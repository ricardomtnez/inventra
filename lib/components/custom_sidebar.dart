import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../views/login.dart';
import '../views/inventory.dart';
import '../views/inputs.dart';

class CustomSidebar extends StatefulWidget {
  const CustomSidebar({super.key});

  @override
  State<CustomSidebar> createState() => _CustomSidebarState();
}

class _CustomSidebarState extends State<CustomSidebar> {
  String nombre = "Cargando...";
  String rol = "Cargando...";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      nombre = prefs.getString('nombre') ?? "Usuario";
      rol = prefs.getString('rol') ?? "Cargo";
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Borrar datos del usuario

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1C1C1E),
      child: Column(
        children: [
          // HEADER USUARIO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),

                // Nombre centrado y multilínea
                Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.fade,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                // Rol centrado
                Text(
                  rol,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),

          // MENÚ
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _menuTile(
                  icon: Icons.dashboard,
                  title: 'Inicio',
                  isActive: true,
                  onTap: () => Navigator.pop(context),
                ),
                _menuTile(
                  icon: Icons.inventory,
                  title: 'Inventario',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InventoryScreen()),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.arrow_downward,
                  title: 'Entradas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InputsScreen()),
                    );
                  },
                ),
                _menuTile(
                  icon: Icons.assignment,
                  title: 'Asignaciones',
                  onTap: () => Navigator.pop(context),
                ),
                _menuTile(
                  icon: Icons.arrow_upward,
                  title: 'Devoluciones',
                  onTap: () => Navigator.pop(context),
                ),
                _menuTile(
                  icon: Icons.refresh,
                  title: 'Reposiciones',
                  onTap: () => Navigator.pop(context),
                ),
                _menuTile(
                  icon: Icons.bar_chart,
                  title: 'Reportes',
                  onTap: () => Navigator.pop(context),
                ),
                _menuTile(
                  icon: Icons.admin_panel_settings,
                  title: 'Administración',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // BOTÓN CERRAR SESIÓN
          Container(
            padding: const EdgeInsets.all(20),
            child: _menuTile(
              icon: Icons.logout,
              title: "Cerrar sesión",
              isLogout: true,
              onTap: _logout,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.red.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isLogout
                    ? Colors.red
                    : isActive
                        ? Colors.red
                        : Colors.grey[400],
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isLogout
                      ? Colors.red
                      : isActive
                          ? Colors.white
                          : Colors.grey[300],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
