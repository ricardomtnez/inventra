import 'package:flutter/material.dart';

/// Sistema de tokens de color de Inventra.
/// Basado en paleta industrial dark-first con Teal eléctrico como accent.
abstract final class AppColors {
  // ── BACKGROUNDS DARK ─────────────────────────────────────────────────────
  /// Scaffold principal — near-black navy, optimizado para OLED
  static const Color bgDark = Color(0xFF060D12);

  /// Cards, AppBar, BottomSheet
  static const Color bgDarkSecondary = Color(0xFF0E1A22);

  /// Input fields, chips, items seleccionados
  static const Color bgDarkTertiary = Color(0xFF162130);

  /// Bordes de cards y dividers
  static const Color bgDarkBorder = Color(0xFF1E3040);

  // ── BACKGROUNDS LIGHT ────────────────────────────────────────────────────
  static const Color bgLight = Color(0xFFF2F5F7);
  static const Color bgLightSecondary = Color(0xFFFFFFFF);
  static const Color bgLightTertiary = Color(0xFFEBF1F5);
  static const Color bgLightBorder = Color(0xFFD4DFE6);

  // ── ACCENT — TEAL ELÉCTRICO ───────────────────────────────────────────────
  /// CTA principal, estados activos, success
  static const Color accentTeal = Color(0xFF00BFA5);
  static const Color accentTealLight = Color(0xFF00897B); // Light mode variant
  static const Color accentTealDim = Color(0xFF004D42); // Muted / subtle BG
  static const Color accentTealGlow = Color(0x2600BFA5); // 15% alpha para glow

  // ── ACCENT — AMBER (warnings / préstamos) ────────────────────────────────
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color accentAmberDim = Color(0xFF3D2A00);
  static const Color accentAmberGlow = Color(0x26FFB300);

  // ── ACCENT — RED (errors / bajas) ────────────────────────────────────────
  static const Color accentRed = Color(0xFFFF5252);
  static const Color accentRedLight = Color(0xFFD32F2F);
  static const Color accentRedDim = Color(0xFF3D0000);
  static const Color accentRedGlow = Color(0x26FF5252);

  // ── ACCENT — GREEN (entradas / disponibles) ───────────────────────────────
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentGreenLight = Color(0xFF2E7D32);
  static const Color accentGreenDim = Color(0xFF003D1A);
  static const Color accentGreenGlow = Color(0x2600E676);

  // ── TEXT DARK ─────────────────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFF0F4F8);
  static const Color textSecondaryDark = Color(0xFF7A9AAD);
  static const Color textMutedDark = Color(0xFF3D5A6B);

  // ── TEXT LIGHT ────────────────────────────────────────────────────────────
  static const Color textPrimaryLight = Color(0xFF0A1A24);
  static const Color textSecondaryLight = Color(0xFF4A6575);
  static const Color textMutedLight = Color(0xFF8AA5B3);

  // ── SEMANTIC HELPERS ──────────────────────────────────────────────────────
  static const Color success = accentTeal;
  static const Color warning = accentAmber;
  static const Color error = accentRed;
  static const Color info = Color(0xFF40C4FF);

  // ── GRADIENTS ─────────────────────────────────────────────────────────────
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF060D12), Color(0xFF0A1E2D)],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
  );

  static const LinearGradient heroCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E2A38), Color(0xFF0A1A24)],
  );
}
