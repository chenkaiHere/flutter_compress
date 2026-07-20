import 'package:flutter/material.dart';

/// The design-system palette (dark + light) derived from the provided mockup:
/// deep near-black purple base, a #7C5CFF → #C04DFF accent gradient, glassy
/// cards, and green/amber signal colors.
class AppColors {
  const AppColors({
    required this.bg,
    required this.glow1,
    required this.glow2,
    required this.cardTop,
    required this.cardBottom,
    required this.cardBorder,
    required this.pill,
    required this.pillBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accent2,
    required this.onAccent,
    required this.success,
    required this.warn,
    required this.danger,
    required this.thumbTop,
    required this.thumbBottom,
  });

  final Color bg;
  final Color glow1;
  final Color glow2;
  final Color cardTop;
  final Color cardBottom;
  final Color cardBorder;
  final Color pill;
  final Color pillBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accent2;
  final Color onAccent;
  final Color success;
  final Color warn;
  final Color danger;
  final Color thumbTop;
  final Color thumbBottom;

  LinearGradient get accentGradient => LinearGradient(
        colors: [accent, accent2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get cardGradient => LinearGradient(
        colors: [cardTop, cardBottom],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get thumbGradient => LinearGradient(
        colors: [thumbTop, thumbBottom],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const dark = AppColors(
    bg: Color(0xFF0A0912),
    glow1: Color(0xFF1A1530),
    glow2: Color(0xFF171029),
    cardTop: Color(0xFF241F38),
    cardBottom: Color(0xFF14111F),
    cardBorder: Color(0x1AFFFFFF),
    pill: Color(0x0DFFFFFF),
    pillBorder: Color(0x14FFFFFF),
    textPrimary: Color(0xFFF4F2FF),
    textSecondary: Color(0xFF9B93C4),
    textMuted: Color(0xFF75708F),
    accent: Color(0xFF7C5CFF),
    accent2: Color(0xFFC04DFF),
    onAccent: Colors.white,
    success: Color(0xFF57E0A0),
    warn: Color(0xFFE0CF57),
    danger: Color(0xFFE0735A),
    thumbTop: Color(0xFF6D4DFF),
    thumbBottom: Color(0xFFC04DFF),
  );

  static const light = AppColors(
    bg: Color(0xFFF3F2FA),
    glow1: Color(0xFFE7E1FF),
    glow2: Color(0xFFF0E4FF),
    cardTop: Color(0xFFFFFFFF),
    cardBottom: Color(0xFFF3F1FB),
    cardBorder: Color(0x14000000),
    pill: Color(0x08000000),
    pillBorder: Color(0x11000000),
    textPrimary: Color(0xFF191527),
    textSecondary: Color(0xFF5A5470),
    textMuted: Color(0xFF8A85A0),
    accent: Color(0xFF7C5CFF),
    accent2: Color(0xFFB94DFF),
    onAccent: Colors.white,
    success: Color(0xFF16A96D),
    warn: Color(0xFFB79100),
    danger: Color(0xFFD2593F),
    thumbTop: Color(0xFF7C5CFF),
    thumbBottom: Color(0xFFB94DFF),
  );
}

/// A monospace-ish style for the big numeric read-outs (approximates the
/// mock's JetBrains Mono without bundling a font).
const List<String> kMonoFallback = ['monospace', 'Menlo', 'Courier New'];

extension AppColorsContext on BuildContext {
  AppColors get c => Theme.of(this).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
}

ThemeData buildAppTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(surface: c.bg, primary: c.accent),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 6,
      activeTrackColor: c.accent,
      inactiveTrackColor: c.pill,
      thumbColor: Colors.white,
      overlayColor: c.accent.withValues(alpha: 0.15),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    ),
  );
}

/// Full-bleed app background: base color plus two soft radial "glows" matching
/// the mock's ambient lighting.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      color: c.bg,
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: -120,
            child: _glow(c.glow1, 460),
          ),
          Positioned(
            top: 40,
            right: -160,
            child: _glow(c.glow2, 480),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      );
}

/// Rounded glassy card used throughout the layout.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: c.cardGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.cardBorder),
      ),
      child: child,
    );
  }
}
