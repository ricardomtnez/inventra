import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/auth_repository.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  static const _secureStorage = FlutterSecureStorage();
  
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    // Comprobar si hay una sesión persistente al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarAutoLogin();
    });
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final rememberMeStr = await _secureStorage.read(key: 'remember_me');
      if (rememberMeStr == 'true') {
        final email = await _secureStorage.read(key: 'saved_email');
        final password = await _secureStorage.read(key: 'saved_password');
        if (mounted) {
          setState(() {
            _rememberMe = true;
            if (email != null) _emailController.text = email;
            if (password != null) _passwordController.text = password;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    }
  }

  Future<void> _verificarAutoLogin() async {
    if (_authRepository.isAuthenticated) {
      setState(() => _isLoading = true);
      try {
        await _authRepository.loadRoles();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, anim, secAnim) => const DashboardScreen(),
              transitionsBuilder: (context, anim, secAnim, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al restaurar sesión: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _authRepository.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // Guardar o borrar credenciales en secure storage tras login exitoso
      if (_rememberMe) {
        await _secureStorage.write(key: 'remember_me', value: 'true');
        await _secureStorage.write(key: 'saved_email', value: _emailController.text.trim());
        await _secureStorage.write(key: 'saved_password', value: _passwordController.text.trim());
      } else {
        await _secureStorage.write(key: 'remember_me', value: 'false');
        await _secureStorage.delete(key: 'saved_email');
        await _secureStorage.delete(key: 'saved_password');
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, anim, secAnim) => const DashboardScreen(),
            transitionsBuilder: (context, anim, secAnim, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de Autenticación: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFFAFBFD),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Si la pantalla es ancha (Web / Tablet), usamos pantalla dividida
          if (constraints.maxWidth >= 768) {
            return Row(
              children: [
                // Panel Izquierdo: Branding & Promoción de la Aplicación
                Expanded(
                  flex: 5,
                  child: Container(
                    height: double.infinity,
                    color: const Color(0xFF0A0D14),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(48.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo de la Aplicación con resplandor suave
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF5E60E6).withValues(alpha: 0.15),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF5E60E6).withValues(alpha: 0.12),
                                    blurRadius: 24,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  'assets/images/inventra_logo.png',
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            const Text(
                              'INVENTRA',
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 8,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Control de inventario y trazabilidad de herramientas en tiempo real para tu taller o almacén.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF94A3B8),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Características clave
                            _buildFeatureRow(Icons.qr_code_scanner_rounded, 'Escaneo QR Instantáneo', 'Asigna y recibe herramientas leyendo códigos QR.'),
                            _buildFeatureRow(Icons.inventory_2_outlined, 'Control de Stock Dinámico', 'Monitoreo de disponibilidad y alertas automáticas.'),
                            _buildFeatureRow(Icons.analytics_outlined, 'Costo Promedio Ponderado', 'Cálculo contable automatizado en cada entrada.'),
                            _buildFeatureRow(Icons.picture_as_pdf_outlined, 'Generación de Vales en PDF', 'Descarga y firma digital de vales de resguardo.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Panel Derecho: Formulario de Login (limitando ancho máximo)
                Expanded(
                  flex: 5,
                  child: Container(
                    color: isDark ? const Color(0xFF0A0D14) : const Color(0xFFFAFBFD),
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _buildLoginForm(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Layout Móvil (iPhone, Xiaomi, Samsung)
            return Container(
              height: double.infinity,
              width: double.infinity,
              color: isDark ? const Color(0xFF0A0D14) : const Color(0xFFFAFBFD),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFF5E60E6).withValues(alpha: 0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF5E60E6).withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/images/inventra_logo.png',
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'INVENTRA',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Control Inteligente de Herramientas',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 13, letterSpacing: 0.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 36),
                          _buildLoginForm(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: _isLoading && _emailController.text.isEmpty
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF5E60E6)),
                  SizedBox(height: 20),
                  Text(
                    'Restaurando sesión...',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Iniciar Sesión',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ingresa tus credenciales para continuar',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Ingresa tu correo electrónico';
                        }
                        final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegExp.hasMatch(v)) {
                          return 'Ingresa un correo electrónico válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: const Color(0xFF5E60E6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _rememberMe = !_rememberMe;
                            });
                          },
                          child: const Text(
                            'Recordar datos',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF5E60E6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF818CF8), size: 24),
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
