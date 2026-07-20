import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/auth_repository.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  static const _secureStorage = FlutterSecureStorage();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
    _loadSavedCredentials();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarAutoLogin());
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
              pageBuilder: (_, __, ___) => const DashboardScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } catch (e) {
        if (mounted) _showError('Error al restaurar sesión: ${e.toString()}');
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

      if (_rememberMe) {
        await _secureStorage.write(key: 'remember_me', value: 'true');
        await _secureStorage.write(
            key: 'saved_email', value: _emailController.text.trim());
        await _secureStorage.write(
            key: 'saved_password', value: _passwordController.text.trim());
      } else {
        await _secureStorage.write(key: 'remember_me', value: 'false');
        await _secureStorage.delete(key: 'saved_email');
        await _secureStorage.delete(key: 'saved_password');
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const DashboardScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Credenciales incorrectas. Verifica tu correo y contraseña.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.accentRed, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 768) {
              return _buildDesktopLayout(constraints);
            }
            return _buildMobileLayout();
          },
        ),
      ),
    );
  }

  // ── DESKTOP LAYOUT ────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(BoxConstraints constraints) {
    return Row(
      children: [
        // Panel izquierdo: Branding
        Expanded(
          flex: 5,
          child: Container(
            height: double.infinity,
            color: AppColors.bgDark,
            child: Stack(
              children: [
                // Dot grid background
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SubtleDotGridPainter(),
                  ),
                ),
                // Gradiente derecho para separación visual
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Color(0x20060D12),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(56.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        _buildLogoWidget(size: 80),
                        const SizedBox(height: 40),
                        // Wordmark
                        Text(
                          'INVENTRA',
                          style: AppTextStyles.display.copyWith(
                            color: AppColors.textPrimaryDark,
                            letterSpacing: 5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Control inteligente de inventario\ny trazabilidad de herramientas.',
                          style: AppTextStyles.bodyLg.copyWith(
                            color: AppColors.textSecondaryDark,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 52),
                        // Feature pills
                        _buildFeaturePill(
                          Icons.qr_code_scanner_rounded,
                          'Escaneo QR Instantáneo',
                          'Registra entradas y salidas en segundos',
                        ),
                        const SizedBox(height: 20),
                        _buildFeaturePill(
                          Icons.inventory_2_outlined,
                          'Stock en Tiempo Real',
                          'Alertas automáticas y disponibilidad live',
                        ),
                        const SizedBox(height: 20),
                        _buildFeaturePill(
                          Icons.picture_as_pdf_outlined,
                          'Vales Digitales PDF',
                          'Firma digital y descarga inmediata',
                        ),
                        const SizedBox(height: 20),
                        _buildFeaturePill(
                          Icons.analytics_outlined,
                          'Costo Promedio Ponderado',
                          'Contabilidad automatizada en cada entrada',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Separador vertical con glow
        Container(
          width: 1,
          color: AppColors.bgDarkBorder,
        ),

        // Panel derecho: Form
        Expanded(
          flex: 5,
          child: Container(
            color: AppColors.bgDarkSecondary,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 56.0, vertical: 32.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildLoginForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT ─────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.splashGradient),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _SubtleDotGridPainter()),
            ),
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 32.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo + wordmark compacto
                      _buildLogoWidget(size: 100),
                      const SizedBox(height: 20),
                      Text(
                        'INVENTRA',
                        style: AppTextStyles.headlineLg.copyWith(
                          color: AppColors.textPrimaryDark,
                          letterSpacing: 5,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Control Inteligente de Herramientas',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondaryDark,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      _buildLoginForm(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── LOGO WIDGET ───────────────────────────────────────────────────────────
  Widget _buildLogoWidget({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.bgDarkSecondary,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: AppColors.accentTeal.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentTeal.withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22 - 1),
        child: Image.asset(
          'assets/images/inventra_logo.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // ── FEATURE PILL ──────────────────────────────────────────────────────────
  Widget _buildFeaturePill(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.accentTealDim,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accentTeal.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(icon, color: AppColors.accentTeal, size: 20),
        ),
        const SizedBox(width: 16),
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
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── LOGIN FORM ────────────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDarkSecondary : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.bgDarkBorder, width: 1.0),
      ),
      child: _isLoading && _emailController.text.isEmpty
          ? _buildRestoringSession()
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header del form
                  Text(
                    'Iniciar Sesión',
                    style: AppTextStyles.headlineLg.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa tus credenciales para acceder',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: const Icon(
                        Icons.alternate_email_rounded,
                        size: 20,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Ingresa tu correo';
                      }
                      if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(v)) {
                        return 'Correo inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 20),

                  // Remember me con Switch moderno
                  Row(
                    children: [
                      SizedBox(
                        height: 28,
                        width: 48,
                        child: Switch(
                          value: _rememberMe,
                          onChanged: (v) => setState(() => _rememberMe = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _rememberMe = !_rememberMe),
                        child: Text(
                          'Recordar sesión',
                          style: AppTextStyles.labelMd.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Botón de login
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Color(0xFF001F1A),
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Ingresar',
                              style: AppTextStyles.buttonLg.copyWith(
                                color: const Color(0xFF001F1A),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Developed by Key Solutions Technology
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.asset(
                          'assets/images/key_solutions_logo.png',
                          width: 18,
                          height: 18,
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
                          fontSize: 10.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRestoringSession() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: AppColors.accentTeal,
            strokeWidth: 2.5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Restaurando sesión...',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
      ],
    );
  }
}

// ── Dot Grid Painter ─────────────────────────────────────────────────────────
class _SubtleDotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentTeal.withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;
    const spacing = 32.0;
    const dotRadius = 1.2;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SubtleDotGridPainter old) => false;
}
