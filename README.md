# 📦 Inventra — Smart Tool & Inventory Management Mobile App

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![QR Scanner](https://img.shields.io/badge/Scanner-Mobile_QR-FF6F00?style=for-the-badge)](https://pub.dev/packages/mobile_scanner)

<p align="center">
  <b>Inventra</b> es una solución móvil diseñada para el control, auditoría y trazabilidad de herramientas, maquinaria e inventario industrial en tiempo real.
</p>

</div>

---

## 📌 Visión General

Inventra permite a empresas y talleres técnicos administrar el flujo de préstamos, devoluciones, mantenimiento preventivo y disponibilidad de equipos, minimizando pérdidas y mejorando la rendición de cuentas operativa.

### 🌟 Funcionalidades Clave

* 📷 **Escaneo Rápido de QR / Códigos de Barras:** Identificación instantánea de herramientas y activos mediante cámara móvil (`mobile_scanner`).
* 🔄 **Sincronización en Tiempo Real:** Gestión de estados de inventario (Disponible, En Uso, En Mantenimiento, Baja) respaldado por Supabase.
* 👥 **Control de Préstamos y Asignaciones:** Registro detallado de operadores receptores, fechas límite y firmas de entrega.
* 📊 **Alertas de Stock y Mantenimiento:** Notificación automática cuando una herramienta requiere calibración o servicio técnico.

---

## 🛠️ Stack Tecnológico

| Componente | Tecnologías |
| :--- | :--- |
| **Framework Móvil** | Flutter 3.x / Dart |
| **Backend & Base de Datos** | Supabase (PostgreSQL, Storage, Auth) |
| **Hardware Integration** | Mobile Scanner (Cámara & Lectura Óptica) |
| **Almacenamiento Local** | SharedPreferences / CachedNetworkImage |

---

## 🚀 Puesta en Marcha

```bash
# 1. Clonar el repositorio
git clone https://github.com/ricardomtnez/inventra.git
cd inventra

# 2. Instalar dependencias
flutter pub get

# 3. Ejecutar la aplicación
flutter run
```

---

## 👨‍💻 Autor
**Ricardo Martínez** — [@ricardomtnez](https://github.com/ricardomtnez) | [LinkedIn](https://www.linkedin.com/in/ricardomtnezhdez/)
