import 'package:flutter/material.dart';

class AppColors {
  // ── System backgrounds ────────────────────────────────────────────────────
  static const background = Color(0xFFF0FAF6);   // very light green tint
  static const surface    = Color(0xFFFFFFFF);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1C1C1E);
  static const textSecondary = Color(0xFF8E8E93);
  static const textTertiary  = Color(0xFFC7C7CC);

  // ── Separators ────────────────────────────────────────────────────────────
  static const separator       = Color(0xFFC6C6C8);
  static const separatorOpaque = Color(0xFFE5E5EA);

  // ── Three-bucket brand colors ─────────────────────────────────────────────
  static const mine   = Color(0xFF3B82F6);  // vivid blue — my spending
  static const ours   = Color(0xFF22C55E);  // vivid green — our spending
  static const theirs = Color(0xFFF97316);  // vivid orange — partner's spending

  // ── Light fills (tint of bucket color on white) ───────────────────────────
  static const mineLight   = Color(0xFFEFF6FF);
  static const oursLight   = Color(0xFFF0FDF4);
  static const theirsLight = Color(0xFFFFF7ED);

  // ── Dark text on light fills ──────────────────────────────────────────────
  static const mineDark   = Color(0xFF1D4ED8);
  static const oursDark   = Color(0xFF15803D);
  static const theirsDark = Color(0xFFC2410C);

  // ── System semantic colors ────────────────────────────────────────────────
  static const success     = Color(0xFF34C759);  // iOS system green
  static const destructive = Color(0xFFFF3B30);  // iOS system red
  static const warning     = Color(0xFFFF9500);  // iOS system orange

  // ── Convenience helpers ───────────────────────────────────────────────────
  static Color forBucket(String bucket) => switch (bucket) {
    'mine'   => mine,
    'ours'   => ours,
    'theirs' => theirs,
    _        => Colors.grey,
  };

  static Color lightForBucket(String bucket) => switch (bucket) {
    'mine'   => mineLight,
    'ours'   => oursLight,
    'theirs' => theirsLight,
    _        => const Color(0xFFF2F2F7),
  };

  static Color darkForBucket(String bucket) => switch (bucket) {
    'mine'   => mineDark,
    'ours'   => oursDark,
    'theirs' => theirsDark,
    _        => Colors.grey.shade700,
  };
}
