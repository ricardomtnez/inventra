import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/connectivity_service.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../data/auth_repository.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _glowController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _glowAnimation;

  final List<String> _loadingTexts = [
    'Inicializando sistema...',
    'Estableciendo enlace con Supabase...',
    'Sincronizando inventario de herramientas...',
    'Cargando catálogo de equipos...',
    'Verificando sesión...',
  ];
  
  String _currentText = 'Iniciando...';
  int _textIndex = 0;
  double _progressValue = 0.0;
  Timer? _textTimer;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();

    // 1. Configurar animaciones de entrada (Logo & Textos)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // 2. Configurar animación de resplandor infinito para el logo
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _glowAnimation = Tween<double>(begin: 20.0, end: 45.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _entranceController.forward();
    _glowController.repeat(reverse: true);

    // 3. Temporizador de textos dinámicos (más espaciado para permitir lectura)
    _currentText = _loadingTexts[_textIndex];
    _textTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _textIndex = (_textIndex + 1) % _loadingTexts.length;
          _currentText = _loadingTexts[_textIndex];
        });
      }
    });

    // 4. Temporizador del progreso de carga (2.5 segundos de duración mínima)
    const int totalSteps = 50;
    const double stepSize = 1.0 / totalSteps;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _progressValue += stepSize;
          if (_progressValue >= 1.0) {
            _progressValue = 1.0;
            _progressTimer?.cancel();
          }
        });
      }
    });

    // 5. Iniciar la verificación de sesión
    _ejecutarInicializacion();
  }

  Future<void> _ejecutarInicializacion() async {
    final startTime = DateTime.now();
    final authRepository = AuthRepository();
    bool isAuthed = authRepository.isAuthenticated;

    if (isAuthed) {
      try {
        await authRepository.loadRoles();
      } catch (_) {
        // Si falla por falta de internet (offline), mantenemos la sesión local.
        // Solo desautorizamos si realmente estamos online y la sesión es inválida.
        final isOffline = ConnectivityService().isOffline.value;
        if (!isOffline) {
          isAuthed = false;
        }
      }
    }

    // Asegurar que la pantalla dure al menos 2.8 segundos para visualización de marca
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 2800) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    // Navegar con una transición suave de desvanecimiento
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            isAuthed ? const DashboardScreen() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    _progressTimer?.cancel();
    _entranceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Central Block: Animated Logo and Title
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFF5E60E6).withValues(alpha: 0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5E60E6).withValues(alpha: 0.15),
                                blurRadius: _glowAnimation.value / 2,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              'assets/images/inventra_logo.png',
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Text(
                            'INVENTRA',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 10,
                              color: Colors.white,
                              fontFamily: Theme.of(context).textTheme.headlineLarge?.fontFamily,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.only(left: 2.0),
                          child: Text(
                            'CONTROL INTELIGENTE DE STOCK',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            // Bottom Block: Loading indicator & Status text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 48.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: const Interval(0.5, 1.0, curve: Curves.easeIn),
                    switchOutCurve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.15),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _currentText,
                      key: ValueKey<String>(_currentText),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 200,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 50),
                          width: 200 * _progressValue,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E60E6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
