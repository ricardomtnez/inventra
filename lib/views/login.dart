import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard.dart';
import '../api/login_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false; // 👈 Nuevo

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final saved = await LoginController.getSavedCredentials();

    if (saved["user"] != null && saved["pass"] != null) {
      setState(() {
        _userController.text = saved["user"]!;
        _passwordController.text = saved["pass"]!;
        _rememberMe = true;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final nombreUsuario = _userController.text.trim();
    final hashContrasena = _passwordController.text.trim();

    final response = await LoginController.signIn(
      nombreUsuario,
      hashContrasena,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      final user = response['user']; // Datos del usuario desde la BD

      // Guardar datos persistentes del usuario
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nombre', user['nombre_completo']);
      await prefs.setString('rol', user['nombre_rol']);
      await prefs.setInt(
        'id_usuario',
        user['id_usuario'],
      ); // Opcional para futuras consultas
      // Guardar o eliminar credenciales según checkbox
      if (_rememberMe) {
        await LoginController.saveCredentials(nombreUsuario, hashContrasena);
      } else {
        await LoginController.clearCredentials();
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['error'] ?? 'Error de autenticación'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    _buildLogo(),
                    const SizedBox(height: 60),
                    _buildForm(),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                '© 2026 Key Solutions Technology.\nTodos los derechos reservados.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.inventory_2, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          'Inventra',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Gestiona tu inventario de manera inteligente',
          style: TextStyle(fontSize: 16, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _userController,
            decoration: _inputDecoration('Usuario', Icons.person_outline),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Ingresa tu usuario' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _inputDecoration('Contraseña', Icons.lock_outline)
                .copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
            validator: (value) => (value == null || value.length < 4)
                ? 'La contraseña debe tener al menos 4 caracteres'
                : null,
          ),
          const SizedBox(height: 8),

          // ⭐ Checkbox Recordar credenciales
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v!),
              ),
              const Text("Recordar mis credenciales"),
            ],
          ),

          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Iniciar Sesión',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
