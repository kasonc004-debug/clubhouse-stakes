import 'package:flutter/material.dart';

/// Apple-dark-glass palette. Dark base with the brand forest green
/// reserved for hero gradients + the wordmark, gold for accents and
/// primary CTAs. Translucent surfaces are opaque approximations so
/// const constructors keep working.
class AppColors {
  AppColors._();

  // ── Brand greens (unchanged) ───────────────────────────────────
  // Used for hero gradients, the wordmark backdrop, the primary
  // identity moments. NOT used as a button background on dark UI.
  static const Color primary       = Color(0xFF1B3D2C);
  static const Color primaryLight  = Color(0xFF2A5940);
  static const Color primaryDark   = Color(0xFF15251D);
  static const Color primaryDeep   = Color(0xFF0A0F0C);

  // ── Surfaces — DARK ────────────────────────────────────────────
  static const Color background    = Color(0xFF0A0F0C);
  static const Color surface       = Color(0xFF15201A);
  static const Color cardBg        = Color(0xFF15201A);
  static const Color elevatedBg    = Color(0xFF1B2820);

  // Translucent helpers (call as functions so callers can wrap them
  // with the right alpha — used for glass cards on top of gradients).
  static Color glassFill([double opacity = 0.04]) =>
      Colors.white.withValues(alpha: opacity);
  static Color glassBorder([double opacity = 0.08]) =>
      Colors.white.withValues(alpha: opacity);

  // ── Legacy 'cream' — kept as aliases so existing references work
  // without a screen-by-screen refactor. They now point at the dark
  // surface so any screen using them as a fill renders correctly.
  static const Color cream         = surface;
  static const Color creamDark     = elevatedBg;

  // ── Accent (gold) ──────────────────────────────────────────────
  static const Color gold          = Color(0xFFC9A84C);
  static const Color goldLight     = Color(0xFFE2C77E);
  static const Color accent        = gold;

  // ── Text ──────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8FA098);
  static const Color textTertiary  = Color(0xFF5C6B62);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  // Gold buttons need dark text for contrast.
  static const Color textOnAccent  = Color(0xFF0A0F0C);
  static const Color textLight     = Color(0xFFFFFFFF);

  // ── Status ─────────────────────────────────────────────────────
  // Bumped saturation/brightness for dark-bg legibility.
  static const Color success       = Color(0xFF3FB37A);
  static const Color error         = Color(0xFFEF5350);
  static const Color warning       = Color(0xFFFFB74D);

  // ── Scorecard ─────────────────────────────────────────────────
  static const Color birdie        = Color(0xFF42A5F5);
  static const Color eagle         = Color(0xFFAB47BC);
  static const Color bogey         = Color(0xFFEF5350);
  static const Color par           = Color(0xFFFFFFFF);

  // ── Divider — subtle white overlay ───────────────────────────
  static const Color divider       = Color(0xFF1F2A24);
}
