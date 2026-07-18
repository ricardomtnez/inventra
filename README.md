# INVENTRA - Sistema de Control de Inventario de Herramientas

INVENTRA es una solución multiplataforma (Web y Móvil) premium diseñada para el control riguroso, trazabilidad y administración del catálogo y préstamos de herramientas en talleres o laboratorios universitarios. El sistema está integrado con **Supabase** para el backend (base de datos relacional PostgreSQL con RLS y almacenamiento de archivos) y optimizado para despliegues web automatizados en **Vercel**.

---

## 🏗️ Arquitectura del Proyecto (Feature-First)

El proyecto ha sido reestructurado desde un patrón MVC tradicional a una **Arquitectura Orientada a Características (Feature-First)**, lo que mejora drásticamente la mantenibilidad, escalabilidad y separación de conceptos.

```
lib/
├── main.dart                      # Punto de entrada de la aplicación
├── core/                          # Recursos globales y configuraciones transversales
│   ├── config/
│   │   └── app_config.dart        # Configuración global, URLs, claves de Supabase
│   ├── theme/
│   │   └── app_theme.dart         # Paleta de colores premium, tipografía Material 3
│   └── supabase/
│       └── supabase_client.dart   # Inicialización y singleton del cliente Supabase
└── features/                      # Módulos organizados por características de negocio
    ├── auth/                      # Autenticación administrativa y carga de roles RBAC
    ├── dashboard/                 # Panel principal con KPIs y acciones rápidas en tiempo real
    ├── herramientas_catalogo/     # Control del catálogo de herramientas, stock e impresión de QRs
    ├── movimientos_qr/            # Escaneo de QRs, firmas digitales y generación de vales locales
    └── web_public_view/           # Vista pública responsiva y de solo lectura de herramientas
```

---

## ⚡ Características Principales

1. **Autenticación con Roles Múltiples (RBAC):**
   * Login intuitivo que añade automáticamente el dominio institucional en segundo plano (ej: `admin` -> `admin@inventra-uni.com`) para no alterar la experiencia de usuario.
   * Carga dinámica de roles (`ADMIN`, `OPERADOR`, `VISITANTE`) desde Supabase Auth para restringir operaciones de escritura mediante políticas de seguridad de base de datos.
2. **Dashboard de Métricas en Tiempo Real:**
   * Indicadores (KPIs) dinámicos que muestran el total de piezas de herramientas en inventario y los préstamos activos actuales.
3. **Escáner e Impresión de Códigos QR:**
   * Diseñador visual de planilla de impresión para exportar los códigos QR de herramientas seleccionadas en una cuadrícula ajustable (tamaño y columnas) directamente a PDF.
   * Escáner QR optimizado integrado con linterna y cambio de cámara para capturar rápidamente códigos QR de equipos y abrir transacciones.
4. **Registro de Movimientos Multi-Herramienta y Generación de Vales Agrupados:**
   * **Carrito de Préstamos:** Permite escanear o seleccionar manualmente múltiples equipos en una sola sesión de escaneo, agregándolos a un carrito.
   * **Firma Única y Vale Unificado:** El responsable firma una sola vez y se genera un único vale digital PDF profesional que detalla en una tabla todos los equipos solicitados.
   * **Agrupación por `grupo_id`:** En la base de datos se almacena una fila individual para cada herramienta (tanto en `prestamos` como en `movimientos`) que comparte el mismo identificador de grupo (`grupo_id` de tipo UUID).
   * **Regla de Devolución Parcial y Retención de INE:** Las herramientas se pueden devolver de forma individual o total escaneando directamente el QR del equipo o el código del Vale (`INVENTRA_VALE:grupo_id`). Si se realiza una devolución parcial, se actualiza el stock correspondiente, pero el vale y la identificación (INE) subida al storage (`identificaciones/ine_$prestamoId.jpg`) se retienen de forma segura en la base de datos y en Supabase Storage hasta que se devuelva el **último** equipo del grupo.
   * **Resolución Dinámica de Deudores:** Al escanear el código QR de un equipo para registrar una entrada (`ENTRADA`), el sistema busca los préstamos activos para ese equipo. Si hay uno solo, carga los datos del deudor automáticamente; si hay múltiples préstamos activos para esa misma herramienta, despliega una hoja inferior de selección con los nombres y matrículas de los deudores activos para que el operador elija el correcto.
   * **Motivo Simplificado de Movimiento:** Se ha migrado y simplificado el motivo del movimiento de `"PRESTAMO_ALUMNO_PROFESOR"` a `"PRESTAMO"` tanto en la interfaz como en el esquema de restricciones de base de datos de Supabase, convirtiendo todos los registros históricos.
5. **Ficha Técnica Pública Web:**
   * Cuando se escanea un código QR, el sistema redirige al usuario a la URL de Vercel con el parámetro `?id=UUID`.
   * El sistema detecta que es una petición web pública y muestra una **Ficha Técnica responsiva y profesional** de solo lectura de la herramienta (detalles, stock, ubicación física) con un botón para descargar la ficha en formato PDF.

---

## 💾 Configuración de la Base de Datos (Supabase)

Toda la base de datos se inicializa de manera limpia y centralizada. Puedes crear la estructura completa copiando el contenido de [supabase/schema.sql](file:///home/rick/Documents/GitHub/inventra/supabase/schema.sql) y ejecutándolo en el **SQL Editor** de la consola de tu proyecto de Supabase.

El script crea:
* Tablas principales (`ubicaciones`, `herramientas`, `movimientos`, `roles`, `perfiles`, `usuario_roles`).
* Función y trigger PostgreSQL (`trg_actualizar_stock_y_costo`) para recalcular existencias y costo promedio contable de manera segura a nivel servidor.
* Políticas de seguridad RLS (Row Level Security) y control de acceso basado en roles (RBAC).
* Buckets de Storage públicos con políticas de lectura pública y escritura solo para administradores.

---

## 🛠️ Desarrollo Local y Ejecución

### Requisitos previos:
* Flutter SDK instalado en tu sistema.
* Un proyecto de Supabase activo.

### Pasos para ejecutar:
1. Clona el repositorio e instala las dependencias:
   ```bash
   flutter pub get
   ```
2. Modifica el archivo [app_config.dart](file:///home/rick/Documents/GitHub/inventra/lib/core/config/app_config.dart) con las llaves de tu proyecto de Supabase y tu dominio en Vercel:
   ```dart
   static const String supabaseUrl = 'https://TU-PROYECTO.supabase.co';
   static const String supabaseAnonKey = 'TU-ANON-KEY-DE-SUPABASE';
   static const String publicWebUrl = 'https://TU-APLICACION.vercel.app/herramienta';
   ```
3. Ejecuta el formateador y analizador de código para validar la salud del proyecto:
   ```bash
   flutter analyze
   ```
4. Corre la suite de pruebas unitarias:
   ```bash
   flutter test
   ```
5. Corre la aplicación localmente:
   ```bash
   flutter run
   ```

---

## 🌐 Despliegue en Vercel (Flutter Web)

El proyecto cuenta con los archivos de automatización de compilación para Vercel:
* `vercel.json`: Define que el comando de construcción es `bash vercel-build.sh`, la carpeta de salida es `build/web` y configura las redirecciones URL para que las rutas del QR funcionen.
* `vercel-build.sh`: Script de Bash que descarga automáticamente el SDK de Flutter en el contenedor temporal de Vercel, habilita el soporte web, instala dependencias y compila el frontend en modo release (`flutter build web --release`).

Para desplegar:
1. Conecta este repositorio en tu cuenta de Vercel.
2. Vercel detectará el archivo de configuración y compilará la versión web automáticamente.
3. Copia el dominio asignado por Vercel y colócalo en la constante `publicWebUrl` en [app_config.dart](file:///home/rick/Documents/GitHub/inventra/lib/core/config/app_config.dart).
