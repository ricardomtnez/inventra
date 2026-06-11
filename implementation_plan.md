# Plan de Reestructuración a Arquitectura Orientada a Características (Feature-First) con Supabase (Actualizado)

Este documento detalla la reestructuración completa del sistema de Inventario de Herramientas para la Universidad. Se migrará el backend actual en PHP a **Supabase** y se reorganizará el frontend de Flutter utilizando una **Arquitectura Orientada a Características (Feature-First)**.

Se han incorporado consideraciones de routing nativo en web para facilitar el futuro despliegue en Vercel, permisos nativos para Android/iOS, y la limpieza completa de archivos obsoletos.

## User Review Required

> [!IMPORTANT]
> **Autenticación en Supabase**: Supabase Auth requiere correo electrónico y contraseña por defecto. El login anterior utilizaba un nombre de usuario plano (`nombre_usuario`). Para mantener la compatibilidad y simplicidad, proponemos dos opciones:
> 1. Configurar un correo institucional del Administrador (ej: `admin@universidad.edu`).
> 2. Que el usuario ingrese su nombre de usuario en el formulario y la aplicación le añada un sufijo de correo por detrás automáticamente (ej: `admin` -> `admin@inventra-uni.com`) para realizar el inicio de sesión en Supabase de manera transparente.
>
> **En este plan, utilizaremos la opción 2 (sufijo automático) para mantener la experiencia de usuario idéntica.**

> [!WARNING]
> **Costo Promedio Ponderado en Devoluciones**: Las devoluciones de préstamos (`DEVOLUCION_PRESTAMO`) no alteran el Costo Promedio Ponderado ya que no representan una nueva compra de activos, solo aumentan el stock físico disponible. Las únicas transacciones que afectan el costo promedio son las `COMPRA_NUEVA`.

> [!TIP]
> **Compresión de Imágenes al Cargar**: Para ahorrar almacenamiento en Supabase (plan gratuito de 1GB), todas las imágenes de herramientas cargadas (ya sea capturadas desde la cámara o seleccionadas desde la galería) serán redimensionadas y comprimidas sobre la marcha usando la configuración de `image_picker` con un ancho/alto máximo de `800px` y una calidad de compresión JPEG del `70%`. Esto reduce el peso de las imágenes de varios megabytes a menos de 100 KB por foto sin comprometer la visualización en dispositivos móviles.

---

## Open Questions

> [!NOTE]
> **Dominio de los QR**: ¿Cuál será el dominio final de producción para la visualización pública de las herramientas? El QR generará enlaces del tipo `https://dominio.com/herramienta?id=UUID`. Por ahora, se dejará configurable en una constante global (`AppConfig.publicWebUrl`).

---

## Proposed Changes

### Componente 1: Base de Datos (Supabase SQL)

#### [NEW] [schema.sql](file:///home/rick/Documents/GitHub/inventra/supabase/schema.sql)
Script completo para crear las tablas, el trigger de cálculo de stock/costo promedio ponderado, configurar RLS y crear los buckets de Storage.

```sql
-- 1. Habilitar extensión pgcrypto para generación de UUIDs
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Crear tabla de Ubicaciones
CREATE TABLE IF NOT EXISTS public.ubicaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL UNIQUE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Crear tabla de Herramientas
CREATE TABLE IF NOT EXISTS public.herramientas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    especificaciones JSONB DEFAULT '{}'::jsonb,
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    costo_promedio NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (costo_promedio >= 0),
    ubicacion_id UUID REFERENCES public.ubicaciones(id) ON DELETE SET NULL,
    foto_url TEXT,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Crear tabla de Movimientos (Transacciones de Inventario)
CREATE TABLE IF NOT EXISTS public.movimientos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    herramienta_id UUID NOT NULL REFERENCES public.herramientas(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL CHECK (tipo IN ('ENTRADA', 'SALIDA')),
    motivo TEXT NOT NULL CHECK (motivo IN (
        'COMPRA_NUEVA', 
        'DEVOLUCION_PRESTAMO', 
        'PRESTAMO_ALUMNO_PROFESOR', 
        'BAJA_DESCOMPOSTURA', 
        'BAJA_PERDIDA'
    )),
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) DEFAULT 0.00 CHECK (precio_unitario >= 0),
    responsable_nombre TEXT,
    matricula TEXT,
    firma_url TEXT,
    vale_pdf_url TEXT,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Trigger PostgreSQL para actualizar Stock y Costo Promedio Ponderado
CREATE OR REPLACE FUNCTION public.fn_actualizar_stock_y_costo()
RETURNS TRIGGER AS $$
DECLARE
    v_stock_actual INT;
    v_costo_actual NUMERIC(12,2);
    v_nuevo_stock INT;
    v_nuevo_costo NUMERIC(12,2);
BEGIN
    -- Obtener datos actuales de la herramienta
    SELECT stock, costo_promedio INTO v_stock_actual, v_costo_actual
    FROM public.herramientas
    WHERE id = NEW.herramienta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La herramienta con ID % no existe', NEW.herramienta_id;
    END IF;

    -- Garantizar no-nulos
    v_stock_actual := COALESCE(v_stock_actual, 0);
    v_costo_actual := COALESCE(v_costo_actual, 0.00);

    -- Lógica de negocio según el tipo de movimiento
    IF NEW.tipo = 'ENTRADA' THEN
        v_nuevo_stock := v_stock_actual + NEW.cantidad;
        
        IF NEW.motivo = 'COMPRA_NUEVA' THEN
            -- Calcular costo promedio ponderado contable
            IF v_nuevo_stock > 0 THEN
                v_nuevo_costo := ((v_stock_actual * v_costo_actual) + (NEW.cantidad * COALESCE(NEW.precio_unitario, 0.00))) / v_nuevo_stock;
            ELSE
                v_nuevo_costo := COALESCE(NEW.precio_unitario, 0.00);
            END IF;
        ELSE
            -- Las devoluciones no alteran el precio de compra original ponderado
            v_nuevo_costo := v_costo_actual;
        END IF;

    ELSIF NEW.tipo = 'SALIDA' THEN
        -- Validar stock suficiente
        IF v_stock_actual < NEW.cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente para la herramienta. Disponible: %, Solicitado: %', v_stock_actual, NEW.cantidad;
        END IF;
        
        v_nuevo_stock := v_stock_actual - NEW.cantidad;
        v_nuevo_costo := v_costo_actual; -- Las salidas no afectan el costo promedio
    ELSE
        RAISE EXCEPTION 'Tipo de movimiento inválido: %', NEW.tipo;
    END IF;

    -- Actualizar herramienta
    UPDATE public.herramientas
    SET stock = v_nuevo_stock,
        costo_promedio = ROUND(v_nuevo_costo, 2)
    WHERE id = NEW.herramienta_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear el trigger propiamente
CREATE OR REPLACE TRIGGER trg_actualizar_stock_y_costo
AFTER INSERT ON public.movimientos
FOR EACH ROW
EXECUTE FUNCTION public.fn_actualizar_stock_y_costo();

-- 6. Configurar RLS (Row Level Security)
ALTER TABLE public.ubicaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.herramientas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos ENABLE ROW LEVEL SECURITY;

-- Políticas para ubicaciones: Lectura pública, escritura solo autenticados
CREATE POLICY "Lectura pública de ubicaciones" ON public.ubicaciones
    FOR SELECT TO public USING (true);

CREATE POLICY "Escritura de ubicaciones reservada a administradores" ON public.ubicaciones
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Políticas para herramientas: Lectura pública (para consulta web de QRs), escritura solo autenticados
CREATE POLICY "Lectura pública de herramientas" ON public.herramientas
    FOR SELECT TO public USING (true);

CREATE POLICY "Escritura de herramientas reservada a administradores" ON public.herramientas
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Políticas para movimientos: Lectura y escritura exclusiva de administradores autenticados
CREATE POLICY "Acceso total a movimientos para administradores" ON public.movimientos
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 7. Crear Buckets en Supabase Storage (Ejecutar después de inicializar la BD)
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('fotos_herramientas', 'fotos_herramientas', true),
    ('vales_pdf', 'vales_pdf', true)
ON CONFLICT (id) DO NOTHING;

-- Políticas de Storage para fotos_herramientas
CREATE POLICY "Acceso público de lectura a fotos" ON storage.objects
    FOR SELECT USING (bucket_id = 'fotos_herramientas');

CREATE POLICY "Carga de fotos reservada a administradores" ON storage.objects
    FOR INSERT TO authenticated WITH CHECK (bucket_id = 'fotos_herramientas');

-- Políticas de Storage para vales_pdf
CREATE POLICY "Acceso público de lectura a vales" ON storage.objects
    FOR SELECT USING (bucket_id = 'vales_pdf');

CREATE POLICY "Carga de vales reservada a administradores" ON storage.objects
    FOR INSERT TO authenticated WITH CHECK (bucket_id = 'vales_pdf');
```

---

### Componente 2: Estructura del Frontend de Flutter (Feature-First)

A continuación se muestra el mapa completo de carpetas y los archivos clave reorganizados bajo `lib/core` y `lib/features`.

```
lib/
├── main.dart
├── core/
│   ├── config/
│   │   └── app_config.dart        (Configuración global, URLs, claves)
│   ├── theme/
│   │   └── app_theme.dart         (Esquema de colores premium, tipografía)
│   └── supabase/
│       └── supabase_client.dart   (Inicialización de Supabase y helpers)
└── features/
    ├── auth/
    │   ├── data/
    │   │   └── auth_repository.dart
    │   └── presentation/
    │       └── login_screen.dart   (Login administrativo con estados)
    ├── dashboard/
    │   └── presentation/
    │       └── dashboard_screen.dart (Pantalla principal con KPIs)
    ├── herramientas_catalogo/
    │   ├── data/
    │   │   └── herramientas_repository.dart
    │   └── presentation/
    │       ├── herramientas_form.dart   (Registro con foto comprimida)
    │       ├── herramientas_list.dart   (Catálogo del administrador)
    │       └── qr_print_selector.dart   (Grid de impresión adaptable y PDF)
    ├── movimientos_qr/
    │   ├── data/
    │   │   └── movimientos_repository.dart
    │   └── presentation/
    │       ├── scanner_view.dart        (Escáner de QR de herramientas)
    │       ├── registrar_movimiento_screen.dart (Lanzador de vales con firma)
    │       └── firma_canvas.dart        (Lienzo táctil para firma)
    └── web_public_view/
        └── presentation/
            └── public_tool_detail_screen.dart (Vista de solo lectura vía QR)
```

#### [MODIFY] [pubspec.yaml](file:///home/rick/Documents/GitHub/inventra/pubspec.yaml)
Añadir todas las dependencias necesarias.
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  shared_preferences: ^2.5.3
  cached_network_image: ^3.4.1
  supabase_flutter: ^2.8.3
  mobile_scanner: ^6.0.0
  qr_flutter: ^4.1.0
  pdf: ^3.11.1
  printing: ^5.14.1
  image_picker: ^1.1.2
  signature: ^5.5.0
```

#### [DELETE] Eliminación de archivos MVC antiguos
Para evitar duplicidades en la compilación y contaminación del proyecto, eliminaremos los siguientes directorios y archivos:
- `lib/api/` (Toda la carpeta)
- `lib/components/` (Toda la carpeta)
- `lib/models/` (Toda la carpeta)
- `lib/views/` (Toda la carpeta)

#### [MODIFY] [AndroidManifest.xml](file:///home/rick/Documents/GitHub/inventra/android/app/src/main/AndroidManifest.xml)
Añadir permisos de cámara y acceso de almacenamiento requeridos por `image_picker` y `mobile_scanner` en Android.
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permisos agregados -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
    
    <application ...
```

#### [MODIFY] [Info.plist](file:///home/rick/Documents/GitHub/inventra/ios/Runner/Info.plist)
Añadir descripciones de uso de permisos de cámara y galería de fotos requeridos por iOS.
```xml
<plist version="1.0">
<dict>
    ...
    <key>NSCameraUsageDescription</key>
    <string>Esta aplicación requiere acceso a la cámara para escanear los códigos QR de las herramientas y capturar fotos de los equipos para el catálogo.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Esta aplicación requiere acceso a la biblioteca de fotos para seleccionar imágenes de las herramientas.</string>
</dict>
</plist>
```

#### [NEW] [app_config.dart](file:///home/rick/Documents/GitHub/inventra/lib/core/config/app_config.dart)
Constantes globales de la aplicación.
```dart
class AppConfig {
  static const String supabaseUrl = 'https://YOUR_SUPABASE_PROJECT_URL.supabase.co';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  static const String publicWebUrl = 'https://inventario-uni.com/herramienta'; // Cambiar a Vercel más adelante
}
```

#### [NEW] [app_theme.dart](file:///home/rick/Documents/GitHub/inventra/lib/core/theme/app_theme.dart)
Paleta de colores premium con degradados, oscuros y bordes redondeados sofisticados.
```dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0F172A); // Slate 900
  static const Color accentColor = Color(0xFF2563EB);  // Blue 600
  static const Color successColor = Color(0xFF10B981); // Emerald 500
  static const Color errorColor = Color(0xFFEF4444);   // Red 500
  static const Color warningColor = Color(0xFFF59E0B); // Amber 500
  static const Color backgroundColor = Color(0xFFF8FAFC); // Slate 50
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.dark,
        primary: accentColor,
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: const CardTheme(
        color: Color(0xFF1E293B),
        elevation: 4,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.light,
        primary: accentColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      cardTheme: const CardTheme(
        color: Colors.white,
        elevation: 2,
      ),
    );
  }
}
```

#### [NEW] [supabase_client.dart](file:///home/rick/Documents/GitHub/inventra/lib/core/supabase/supabase_client.dart)
Cliente Singleton para Supabase.
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseClientHelper {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
```

---

### Componente 3: Feature - Auth & Login

#### [NEW] [auth_repository.dart](file:///home/rick/Documents/GitHub/inventra/lib/features/auth/data/auth_repository.dart)
Repositorio para manejar la lógica de autenticación con el sufijo automático.
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseClientHelper.client;

  Future<AuthResponse> login(String username, String password) async {
    // Si no es un correo electrónico, agregamos el dominio automático
    final email = username.contains('@') ? username : '$username@inventra-uni.com';
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
}
```

#### [NEW] [login_screen.dart](file:///home/rick/Documents/GitHub/inventra/lib/features/auth/presentation/login_screen.dart)
Pantalla de Login con animaciones sutiles e interfaz premium de Slate/Azul.
```dart
import 'package:flutter/material.dart';
import '../data/auth_repository.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _authRepository.login(
        _userController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de Autenticación: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Premium
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(Icons.handyman_rounded, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'INVENTRA',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const Text(
                'Control de Inventario de Herramientas',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 48),
              
              // Formulario
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _userController,
                          decoration: InputDecoration(
                            labelText: 'Usuario Administrativo',
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

### Componente 4: Feature - Dashboard Principal

#### [NEW] [dashboard_screen.dart](file:///home/rick/Documents/GitHub/inventra/lib/features/dashboard/presentation/dashboard_screen.dart)
Dashboard del administrador mostrando métricas en tiempo real de Supabase.

```dart
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
              await _authRepository.logout();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarMetricas,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoading)
                const LinearProgressIndicator()
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
                color: color.withOpacity(0.1),
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
```

---

### Componente 5: Feature - Herramientas Catálogo

#### [NEW] [herramientas_repository.dart](file:///home/rick/Documents/GitHub/inventra/lib/features/herramientas_catalogo/data/herramientas_repository.dart)
Módulo para interactuar con la base de datos de herramientas y subir imágenes.

```dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

class HerramientasRepository {
  final SupabaseClient _client = SupabaseClientHelper.client;

  Future<List<Map<String, dynamic>>> obtenerHerramientas() async {
    final data = await _client.from('herramientas').select('*, ubicaciones(nombre)').order('nombre');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> obtenerUbicaciones() async {
    final data = await _client.from('ubicaciones').select('*').order('nombre');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<String?> subirFoto(File file, String fileName) async {
    try {
      final path = 'fotos/$fileName';
      await _client.storage.from('fotos_herramientas').upload(
        path,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      return _client.storage.from('fotos_herramientas').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  Future<void> registrarHerramienta({
    required String nombre,
    required String descripcion,
    required String? fotoUrl,
    required String ubicacionId,
    required int stockInicial,
    required double costoUnitario,
    required Map<String, dynamic> especificaciones,
  }) async {
    // 1. Insertar herramienta
    final insertRes = await _client.from('herramientas').insert({
      'nombre': nombre,
      'descripcion': descripcion,
      'foto_url': fotoUrl,
      'ubicacion_id': ubicacionId,
      'especificaciones': especificaciones,
      'stock': 0, // El trigger calculará esto a partir del movimiento inicial
      'costo_promedio': 0.00,
    }).select().single();

    final uuidHerramienta = insertRes['id'];

    // 2. Si hay stock inicial, insertar el movimiento correspondiente
    if (stockInicial > 0) {
      await _client.from('movimientos').insert({
        'herramienta_id': uuidHerramienta,
        'tipo': 'ENTRADA',
        'motivo': 'COMPRA_NUEVA',
        'cantidad': stockInicial,
        'precio_unitario': costoUnitario,
        'responsable_nombre': 'Carga Inicial de Sistema',
      });
    }
  }
}
```

#### [NEW] [herramientas_form.dart](file:///home/rick/Documents/GitHub/inventra/lib/features/herramientas_catalogo/presentation/herramientas_form.dart)
Formulario con optimización de foto: limitando las dimensiones a 800px de ancho/alto máximo y una calidad del 70% usando `image_picker` (aplica a captura por cámara y a selección de la galería).

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/herramientas_repository.dart';

class HerramientasFormScreen extends StatefulWidget {
  const HerramientasFormScreen({super.key});

  @override
  State<HerramientasFormScreen> createState() => _HerramientasFormScreenState();
}

class _HerramientasFormScreenState extends State<HerramientasFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _costoController = TextEditingController(text: '0.00');
  
  final _repository = HerramientasRepository();
  final _picker = ImagePicker();
  
  File? _imageFile;
  bool _isSaving = false;
  
  String? _selectedUbicacion;
  List<Map<String, dynamic>> _ubicaciones = [];

  @override
  void initState() {
    super.initState();
    _cargarUbicaciones();
  }

  Future<void> _cargarUbicaciones() async {
    final list = await _repository.obtenerUbicaciones();
    setState(() {
      _ubicaciones = list;
    });
  }

  Future<void> _seleccionarImagen(ImageSource source) async {
    // Compresión activa en origen tanto para Cámara como para Galería
    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70, // Compresión de calidad al 70%
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Tomar Foto con Cámara'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Seleccionar de Galería'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarHerramienta() async {
    if (!_formKey.currentState!.validate() || _selectedUbicacion == null) return;
    setState(() => _isSaving = true);

    try {
      String? fotoUrl;
      if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        fotoUrl = await _repository.subirFoto(_imageFile!, fileName);
      }

      await _repository.registrarHerramienta(
        nombre: _nombreController.text.trim(),
        descripcion: _descController.text.trim(),
        fotoUrl: fotoUrl,
        ubicacionId: _selectedUbicacion!,
        stockInicial: int.tryParse(_stockController.text) ?? 0,
        costoUnitario: double.tryParse(_costoController.text) ?? 0.00,
        especificaciones: {},
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Herramienta registrada exitosamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Herramienta')),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Visualización de Foto
                    Center(
                      child: GestureDetector(
                        onTap: _mostrarOpcionesImagen,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: _imageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.file(_imageFile!, fit: BoxFit.cover),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Cargar Imagen', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre de la Herramienta'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: 'Descripción'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Dropdown de Ubicación Física
                    DropdownButtonFormField<String>(
                      hint: const Text('Ubicación Física'),
                      value: _selectedUbicacion,
                      items: _ubicaciones.map((u) {
                        return DropdownMenuItem<String>(
                          value: u['id'],
                          child: Text(u['nombre']),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedUbicacion = v),
                      validator: (v) => v == null ? 'Seleccione ubicación' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Stock Inicial'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _costoController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Costo Unitario ($)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _guardarHerramienta,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Registrar en Sistema', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
```

---

### Componente 6: Feature - Impresión Dinámica de QR y Configuración de Plantilla

#### [NEW] [qr_print_selector.dart](file:///home/rick/Documents/GitHub/inventra/lib/features/herramientas_catalogo/presentation/qr_print_selector.dart)
Modulo visual para ajustar la cuadrícula de impresión de códigos QR de herramientas.

```dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/config/app_config.dart';

class QrPrintSelectorScreen extends StatefulWidget {
  final List<Map<String, dynamic>> herramientas;

  const QrPrintSelectorScreen({super.key, required this.herramientas});

  @override
  State<QrPrintSelectorScreen> createState() => _QrPrintSelectorScreenState();
}

class _QrPrintSelectorScreenState extends State<QrPrintSelectorScreen> {
  double _qrSize = 100.0; // Dimensión dinámica modificable (alto/ancho)
  int _columns = 3;      // Cantidad de columnas en el PDF por fila

  Future<void> _generarEImprimirPdf() async {
    final pdf = pw.Document();
    
    // Obtener los datos del QR como imagen para el PDF
    final qrDataList = <Map<String, dynamic>>[];
    for (var h in widget.herramientas) {
      final qrUrl = '${AppConfig.publicWebUrl}?id=${h['id']}';
      qrDataList.add({
        'nombre': h['nombre'],
        'url': qrUrl,
      });
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'Planilla de Códigos QR - Inventario'),
            pw.SizedBox(height: 20),
            pw.GridView(
              crossAxisCount: _columns,
              childAspectRatio: 1.0,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: qrDataList.map((qr) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(qr['nombre'], style: const pw.TextStyle(fontSize: 8), maxLines: 1),
                      pw.SizedBox(height: 5),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qr['url'],
                        width: _qrSize - 20,
                        height: _qrSize - 20,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impresión de QR')),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('Configuración de Cuadrícula', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Slider de tamaño del QR
                  Row(
                    children: [
                      const Text('Dimensión: '),
                      Expanded(
                        child: Slider(
                          value: _qrSize,
                          min: 50.0,
                          max: 180.0,
                          onChanged: (v) => setState(() => _qrSize = v),
                        ),
                      ),
                      Text('${_qrSize.toInt()} px'),
                    ],
                  ),
                  
                  // Slider de columnas
                  Row(
                    children: [
                      const Text('Columnas: '),
                      Expanded(
                        child: Slider(
                          value: _columns.toDouble(),
                          min: 2.0,
                          max: 5.0,
                          divisions: 3,
                          onChanged: (v) => setState(() => _columns = v.toInt()),
                        ),
                      ),
                      Text('$_columns col'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: widget.herramientas.length,
              itemBuilder: (context, index) {
                final h = widget.herramientas[index];
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(h['nombre'], style: const TextStyle(fontSize: 10), maxLines: 1),
                      const SizedBox(height: 4),
                      QrImageView(
                        data: '${AppConfig.publicWebUrl}?id=${h['id']}',
                        size: _qrSize - 30 > 0 ? _qrSize - 30 : 20,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _generarEImprimirPdf,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.print_rounded),
              label: const Text('Imprimir Planilla optimizada'),
            ),
          )
        ],
      ),
    );
  }
}
```

---

### Componente 7: Feature - Movimientos (Lanzador de Vales y Firma Táctil)

#### [NEW] [firma_canvas.dart](file:///home/rick/Documents/GitHub/inventra/lib/features/movimientos_qr/presentation/firma_canvas.dart)
Lienzo táctil para capturar la firma del alumno o profesor.

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class FirmaCanvasScreen extends StatefulWidget {
  const FirmaCanvasScreen({super.key});

  @override
  State<FirmaCanvasScreen> createState() => _FirmaCanvasScreenState();
}

class _FirmaCanvasScreenState extends State<FirmaCanvasScreen> {
  late SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 4,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firma Digital del Responsable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: () => _controller.clear(),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Signature(
              controller: _controller,
              backgroundColor: Colors.grey.shade50,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                if (_controller.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor, firme el lienzo táctil antes de continuar')),
                  );
                  return;
                }
                
                final pngBytes = await _controller.toPngBytes();
                if (mounted && pngBytes != null) {
                  Navigator.pop(context, pngBytes);
                }
              },
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Confirmar Firma y Estampar'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          )
        ],
      ),
    );
  }
}
```

#### [NEW] [registrar_movimiento_screen.dart](file:///home/rick/Documents/GitHub/inventra/lib/features/movimientos_qr/presentation/registrar_movimiento_screen.dart)
Formulario de transacción (ENTRADA/SALIDA) que genera un Vale Digital PDF firmado, lo sube a Supabase y expone un link público para compartir rápidamente.

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firma_canvas.dart';
import '../../../core/supabase/supabase_client.dart';

class RegistrarMovimientoScreen extends StatefulWidget {
  final Map<String, dynamic> herramienta;

  const RegistrarMovimientoScreen({super.key, required this.herramienta});

  @override
  State<RegistrarMovimientoScreen> createState() => _RegistrarMovimientoScreenState();
}

class _RegistrarMovimientoScreenState extends State<RegistrarMovimientoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController(text: '0.00');
  final _responsableController = TextEditingController();
  final _matriculaController = TextEditingController();
  
  String _tipo = 'SALIDA';
  String _motivo = 'PRESTAMO_ALUMNO_PROFESOR';
  Uint8List? _firmaBytes;
  bool _isSaving = false;

  Future<void> _capturarFirma() async {
    final bytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(builder: (context) => const FirmaCanvasScreen()),
    );
    if (bytes != null) {
      setState(() => _firmaBytes = bytes);
    }
  }

  Future<void> _procesarTransaccion() async {
    if (!_formKey.currentState!.validate() || _firmaBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formulario incompleto o firma faltante')),
      );
      return;
    }
    setState(() => _isSaving = true);

    try {
      final client = SupabaseClientHelper.client;
      final filePrefix = DateTime.now().millisecondsSinceEpoch;

      // 1. Subir firma digital
      final pathFirma = 'firmas/$filePrefix.png';
      await client.storage.from('vales_pdf').uploadBinary(pathFirma, _firmaBytes!);
      final firmaUrl = client.storage.from('vales_pdf').getPublicUrl(pathFirma);

      // 2. Generar PDF del Vale Digital
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, text: 'UNIVERSIDAD - VALE DE CONTROL DE HERRAMIENTAS'),
                pw.SizedBox(height: 20),
                pw.Text('Tipo: $_tipo'),
                pw.Text('Motivo: $_motivo'),
                pw.Text('Cantidad: ${_qtyController.text}'),
                pw.Text('Herramienta: ${widget.herramienta['nombre']}'),
                pw.Text('Responsable: ${_responsableController.text}'),
                pw.Text('Matrícula/ID: ${_matriculaController.text}'),
                pw.Text('Fecha: ${DateTime.now().toLocal()}'),
                pw.SizedBox(height: 40),
                pw.Text('Firma del Responsable:'),
                pw.SizedBox(height: 10),
                pw.Image(pw.MemoryImage(_firmaBytes!), width: 150, height: 80),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final pathPdf = 'vales/$filePrefix.pdf';
      
      // 3. Subir Vale Digital PDF
      await client.storage.from('vales_pdf').uploadBinary(pathPdf, pdfBytes);
      final pdfUrl = client.storage.from('vales_pdf').getPublicUrl(pathPdf);

      // 4. Registrar Movimiento en Base de Datos (Esto dispara el Trigger contable)
      await client.from('movimientos').insert({
        'herramienta_id': widget.herramienta['id'],
        'tipo': _tipo,
        'motivo': _motivo,
        'cantidad': int.parse(_qtyController.text),
        'precio_unitario': double.tryParse(_priceController.text) ?? 0.00,
        'responsable_nombre': _responsableController.text.trim(),
        'matricula': _matriculaController.text.trim(),
        'firma_url': firmaUrl,
        'vale_pdf_url': pdfUrl,
      });

      if (mounted) {
        _mostrarLinkPdf(pdfUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _mostrarLinkPdf(String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('¡Movimiento Registrado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Se ha generado el vale digital en PDF con la firma integrada.'),
            const SizedBox(height: 16),
            SelectableText(
              url,
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // cerrar diálogo
              Navigator.pop(context, true); // regresar al listado
            },
            child: const Text('Finalizar'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Transacción: ${widget.herramienta['nombre']}')),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _tipo,
                      decoration: const InputDecoration(labelText: 'Tipo de Transacción'),
                      items: const [
                        DropdownMenuItem(value: 'ENTRADA', child: Text('ENTRADA')),
                        DropdownMenuItem(value: 'SALIDA', child: Text('SALIDA')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _tipo = v!;
                          _motivo = _tipo == 'ENTRADA' ? 'DEVOLUCION_PRESTAMO' : 'PRESTAMO_ALUMNO_PROFESOR';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _motivo,
                      decoration: const InputDecoration(labelText: 'Motivo del Movimiento'),
                      items: _tipo == 'ENTRADA'
                          ? const [
                              DropdownMenuItem(value: 'COMPRA_NUEVA', child: Text('COMPRA NUEVA')),
                              DropdownMenuItem(value: 'DEVOLUCION_PRESTAMO', child: Text('DEVOLUCIÓN DE PRÉSTAMO')),
                            ]
                          : const [
                              DropdownMenuItem(value: 'PRESTAMO_ALUMNO_PROFESOR', child: Text('PRÉSTAMO A ALUMNO/PROFESOR')),
                              DropdownMenuItem(value: 'BAJA_DESCOMPOSTURA', child: Text('BAJA POR DESCOMPOSTURA')),
                              DropdownMenuItem(value: 'BAJA_PERDIDA', child: Text('BAJA POR PÉRDIDA')),
                            ],
                      onChanged: (v) => setState(() => _motivo = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      validator: (v) => (v == null || int.tryParse(v) == null) ? 'Cantidad inválida' : null,
                    ),
                    if (_motivo == 'COMPRA_NUEVA') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Precio Unitario de Compra ($)'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _responsableController,
                      decoration: const InputDecoration(labelText: 'Nombre del Responsable'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _matriculaController,
                      decoration: const InputDecoration(labelText: 'Matrícula / ID'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 24),
                    
                    // Firma Box
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _firmaBytes != null
                          ? Image.memory(_firmaBytes!, fit: BoxFit.contain)
                          : Center(
                              child: TextButton.icon(
                                onPressed: _capturarFirma,
                                icon: const Icon(Icons.gesture_rounded),
                                label: const Text('Capturar Firma del Alumno/Profesor'),
                              ),
                            ),
                    ),
                    
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _procesarTransaccion,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Registrar Transacción y Generar Vale'),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
```

---

### Componente 8: Feature - Vista Pública Web (Vercel)

Esta vista se compilará para la Web y responderá a la URL generada en los códigos QR. Se ejecuta sin autenticación y es estrictamente de sólo lectura.

#### [NEW] [public_tool_detail_screen.dart](file:///home/rick/Documents/GitHub/inventra/lib/features/web_public_view/presentation/public_tool_detail_screen.dart)
Pantalla pública para consulta rápida por estudiantes o docentes.

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/supabase/supabase_client.dart';

class PublicToolDetailScreen extends StatefulWidget {
  final String herramientaId;

  const PublicToolDetailScreen({super.key, required this.herramientaId});

  @override
  State<PublicToolDetailScreen> createState() => _PublicToolDetailScreenState();
}

class _PublicToolDetailScreenState extends State<PublicToolDetailScreen> {
  Map<String, dynamic>? _herramienta;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDetalles();
  }

  Future<void> _cargarDetalles() async {
    try {
      final client = SupabaseClientHelper.client;
      final res = await client
          .from('herramientas')
          .select('*, ubicaciones(nombre)')
          .eq('id', widget.herramientaId)
          .single();

      setState(() {
        _herramienta = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se encontró la herramienta especificada o el código QR es inválido.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta de Herramienta', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Foto de la herramienta
                            if (_herramienta!['foto_url'] != null)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: CachedNetworkImage(
                                  imageUrl: _herramienta!['foto_url'],
                                  height: 250,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const SizedBox(
                                    height: 250,
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) => const SizedBox(
                                    height: 250,
                                    child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                ),
                                child: const Icon(Icons.handyman_rounded, size: 64, color: Colors.grey),
                              ),
                            
                            // Detalles
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _herramienta!['nombre'].toUpperCase(),
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Badge de Stock
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _herramienta!['stock'] > 0 
                                          ? Colors.green.shade50 
                                          : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _herramienta!['stock'] > 0 
                                          ? 'Disponible (${_herramienta!['stock']} piezas)' 
                                          : 'Sin Existencias',
                                      style: TextStyle(
                                        color: _herramienta!['stock'] > 0 ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  const Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(_herramienta!['descripcion'] ?? 'Sin descripción disponible.', style: const TextStyle(fontSize: 16)),
                                  const SizedBox(height: 20),
                                  
                                  const Text('Ubicación Física', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_rounded, color: Colors.redAccent),
                                      const SizedBox(width: 8),
                                      Text(
                                        _herramienta!['ubicaciones']?['nombre'] ?? 'No especificada',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
```

---

### Componente 9: Modificación del Archivo Principal (`main.dart`)

Configurar la inicialización asíncrona de Supabase y el parser nativo de parámetros de URL para atender la consulta de QRs en Web.

#### [MODIFY] [main.dart](file:///home/rick/Documents/GitHub/inventra/lib/main.dart)
```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/theme/app_theme.dart';
import 'core/supabase/supabase_client.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/web_public_view/presentation/public_tool_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización de Supabase
  await SupabaseClientHelper.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Widget homeScreen = const LoginScreen();

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
    );
  }
}
```

---

## Verification Plan

### Automated Tests
- Ejecutar `flutter test` en los controladores/modelos básicos simulando flujos de cálculo de promedio ponderado.
- Validar las Row Level Security (RLS) Policies en la base de datos simulando conexiones sin token (anon) para herramientas e intentando hacer insert/update en la consola SQL de Supabase.

### Manual Verification
- **Carga de imágenes**: Capturar fotos con un emulador/dispositivo real y verificar en la consola de Supabase Storage que las fotos se suban y midan menos de 800px con un tamaño liviano.
- **Firma Digital**: Firmar digitalmente y verificar que el archivo PDF se genere de forma legible y se pueda acceder mediante la URL pública.
- **Prueba de Despliegue en Web**: Compilar para web con `flutter build web --release` y probar localmente (`python3 -m http.server`) pasando `?id=UUID_DE_PRUEBA` para asegurar que el ruteador nativo dirija a la vista pública.
