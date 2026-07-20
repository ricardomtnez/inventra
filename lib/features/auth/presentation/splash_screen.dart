import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../data/auth_repository.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _progressController;
  late final AnimationController _pulseController;

  // ── Animations ────────────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _pulseOpacity;

  double _progressValue = 0.0;
  String _statusText = 'Inicializando sistema...';
  Timer? _progressTimer;

  final List<String> _statusMessages = [
    'Inicializando sistema...',
    'Estableciendo conexión segura...',
    'Sincronizando inventario...',
    'Verificando sesión...',
  ];
  int _msgIndex = 0;
  Timer? _msgTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // Logo: escala + fade in
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    // Textos: fade + slide up
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Progress: animado lineal
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    // Pulso: glow pulsante en el logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseOpacity = Tween<double>(begin: 0.0, end: 0.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startSequence() async {
    // 1. Logo entra
    await _logoController.forward();

    // 2. Texto aparece tras logo
    await Future.delayed(const Duration(milliseconds: 100));
    _textController.forward();

    // 3. Pulso y progreso
    _pulseController.repeat(reverse: true);
    _startProgress();
    _startMessages();

    // 4. Verificar sesión en paralelo
    _ejecutarInicializacion();
  }

  void _startProgress() {
    const steps = 56;
    const step = 1.0 / steps;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!mounted) return;
      setState(() {
        _progressValue = (_progressValue + step).clamp(0.0, 1.0);
        if (_progressValue >= 1.0) t.cancel();
      });
    });
  }

  void _startMessages() {
    _msgTimer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted) return;
      setState(() {
        _msgIndex = (_msgIndex + 1) % _statusMessages.length;
        _statusText = _statusMessages[_msgIndex];
      });
    });
  }

  Future<void> _ejecutarInicializacion() async {
    final startTime = DateTime.now();
    final authRepository = AuthRepository();
    bool isAuthed = authRepository.isAuthenticated;

    if (isAuthed) {
      try {
        await authRepository.loadRoles();
      } catch (_) {
        final isOffline = ConnectivityService().isOffline.value;
        if (!isOffline) isAuthed = false;
      }
    }

    // Pantalla visible mínimo 2.8 s
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 2800) - elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            isAuthed ? const DashboardScreen() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    _progressTimer?.cancel();
    _msgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Dot grid pattern (sutil) ──────────────────────────────
              Positioned.fill(child: _DotGridPainter()),

              // ── Contenido principal ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Logo con glow animado
                    Center(child: _buildLogoSection()),

                    const SizedBox(height: 36),

                    // Wordmark + tagline
                    Center(child: _buildWordmark()),

                    const Spacer(flex: 3),

                    // Status + progress
                    Center(child: _buildProgressSection()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoScale, _logoFade, _pulseOpacity]),
      builder: (_, __) {
        return FadeTransition(
          opacity: _logoFade,
          child: ScaleTransition(
            scale: _logoScale,
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow ring pulsante
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentTeal
                              .withValues(alpha: _pulseOpacity.value),
                          blurRadius: 48,
                          spreadRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  // Logo container
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      color: AppColors.bgDarkSecondary,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.accentTeal.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(27),
                      child: Image.asset(
                        'assets/images/inventra_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWordmark() {
    return FadeTransition(
      opacity: _textFade,
      child: SlideTransition(
        position: _textSlide,
        child: Column(
          children: [
            Text(
              'INVENTRA',
              style: AppTextStyles.display.copyWith(
                color: AppColors.textPrimaryDark,
                letterSpacing: 6,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'CONTROL INTELIGENTE DE STOCK',
              style: AppTextStyles.overline.copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 3.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 48.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status text animado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              _statusText,
              key: ValueKey(_statusText),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryDark,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar premium
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return LayoutBuilder(builder: (_, constraints) {
      const barWidth = 200.0;
      const barHeight = 2.0;

      return SizedBox(
        width: barWidth,
        height: barHeight,
        child: Stack(
          children: [
            // Track
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgDarkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Fill con shimmer
            AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              width: barWidth * _progressValue,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentTeal, Color(0xFF80DEEA)],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentTeal.withValues(alpha: 0.6),
                    blurRadius: 6,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Dot Grid Painter ─────────────────────────────────────────────────────────
class _DotGridPainter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DotGridCustomPainter());
  }
}

class _DotGridCustomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentTeal.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const dotRadius = 1.2;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridCustomPainter old) => false;
}
