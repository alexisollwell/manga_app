/// Color palette for the manga library app.
/// Uses a dark purple/indigo theme with neon accents
/// for a premium manga/anime aesthetic.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary Palette ──────────────────────────────
  static const Color primary = Color(0xFF7C4DFF);
  static const Color primaryLight = Color(0xFFB47CFF);
  static const Color primaryDark = Color(0xFF3F1DCB);

  // ── Secondary / Accent ───────────────────────────
  static const Color accent = Color(0xFF00E5FF);
  static const Color accentLight = Color(0xFF6EFFFF);
  static const Color accentDark = Color(0xFF00B2CC);

  // ── Surfaces ─────────────────────────────────────
  static const Color background = Color(0xFF0D0D1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF252540);
  static const Color surfaceCard = Color(0xFF16213E);

  // ── Semantic Colors ──────────────────────────────
  static const Color success = Color(0xFF00E676);       // Tomo adquirido
  static const Color successLight = Color(0xFF69F0AE);
  static const Color pending = Color(0xFF455A64);        // Tomo pendiente
  static const Color pendingLight = Color(0xFF78909C);
  static const Color danger = Color(0xFFFF1744);         // Eliminar
  static const Color dangerLight = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFAB00);        // Advertencia

  // ── Text Colors ──────────────────────────────────
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0B0C0);
  static const Color textHint = Color(0xFF6C6C80);

  // ── Connectivity Banner ──────────────────────────
  static const Color offline = Color(0xFFFF1744);
  static const Color syncing = Color(0xFFFFAB00);
  static const Color online = Color(0xFF00E676);

  // ── Gradients ────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF536DFE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [surfaceCard, Color(0xFF1A1A3E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFF448AFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
