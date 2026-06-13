import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/theme/app_theme.dart';
import 'core/supabase/supabase_client.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/sync_service.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/web_public_view/presentation/public_tool_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  
  // Inicialización de Supabase
  await SupabaseClientHelper.initialize();
  
  // Inicialización de servicios de conectividad y sincronización offline
  ConnectivityService().initialize();
  await SyncService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Widget homeScreen = const SplashScreen();

    // Detección nativa de parámetros en la URL (Despliegue Vercel / Web)
    if (kIsWeb) {
      final uri = Uri.base;
      // Permite capturar urls del tipo: https://dominio.com/?id=UUID o https://dominio.com/herramienta?id=UUID
      final toolId = uri.queryParameters['id'];
      if (toolId != null && toolId.isNotEmpty) {
        homeScreen = PublicToolDetailScreen(herramientaId: toolId);
      }
    }

    return MaterialApp(
      title: 'Inventra',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: homeScreen,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/herramienta')) {
          final uri = Uri.parse(settings.name!);
          final toolId = uri.queryParameters['id'];
          if (toolId != null && toolId.isNotEmpty) {
            return MaterialPageRoute(
              builder: (context) => PublicToolDetailScreen(herramientaId: toolId),
            );
          }
        }
        return null; // Deja que Flutter maneje el resto (home, etc.)
      },
    );
  }
}
