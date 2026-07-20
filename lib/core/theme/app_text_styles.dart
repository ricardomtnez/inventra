import 'package:flutter/material.dart';

/// Sistema tipográfico centralizado de Inventra.
/// Pareja: DM Sans (headlines) + Inter (body/data)
abstract final class AppTextStyles {
  // ── DISPLAY / HERO (DM Sans 700) ─────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 38,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.1,
  );

  static const TextStyle displaySm = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    height: 1.15,
  );

  // ── HEADLINE (DM Sans 600) ────────────────────────────────────────────────
  static const TextStyle headlineLg = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
  );

  static const TextStyle headlineSm = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
  );

  // ── TITLE (DM Sans 500) ───────────────────────────────────────────────────
  static const TextStyle titleLg = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 17,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static const TextStyle titleMd = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  // ── BODY (Inter 400) ──────────────────────────────────────────────────────
  static const TextStyle bodyLg = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ── LABEL / UI (Inter 500) ────────────────────────────────────────────────
  static const TextStyle labelLg = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const TextStyle labelMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const TextStyle labelSm = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.3,
  );

  // ── DATA / MONO (Inter 600-700) ───────────────────────────────────────────
  /// Para KPIs, números grandes, folios
  static const TextStyle dataHero = TextStyle(
    fontFamily: 'Inter',
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.0,
  );

  static const TextStyle dataLg = TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static const TextStyle dataMd = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  // ── CAPTION / META (Inter 400) ────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle overline = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    height: 1.4,
  );

  // ── BUTTON (DM Sans 600) ──────────────────────────────────────────────────
  static const TextStyle buttonLg = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle buttonMd = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
}
