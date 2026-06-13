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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF070B19), // Azul-negro ultra profundo
              Color(0xFF0F172A), // Slate 900
              Color(0xFF1E293B), // Slate 800
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 40),
              // Bloque Central: Logo y Título animado
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
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.6),
                                blurRadius: _glowAnimation.value,
                                spreadRadius: 3,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(36),
                            child: Image.asset(
                              'assets/images/inventra_logo.png',
                              width: 170,
                              height: 170,
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
                        Text(
                          'INVENTRA',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.blue.shade600.withValues(alpha: 0.8),
                                blurRadius: 15,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Control Inteligente de Herramientas',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Bloque Inferior: Indicador de Carga y Texto de Estado
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 48.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Texto dinámico con animación de cambio de texto
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
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Barra de progreso lineal elegante
                    Container(
                      width: 240,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 50),
                            width: 240 * _progressValue,
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2563EB), // Azul 600
                                  Color(0xFF60A5FA), // Azul 400
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade400.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
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
            ],
          ),
        ),
      ),
    );
  }
}
