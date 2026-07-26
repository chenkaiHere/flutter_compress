import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Small muted section heading (e.g. "编码格式").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: context.c.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    ),
  );
}

/// Small metadata chip (e.g. "1080p", "248 MB").
class LabelChip extends StatelessWidget {
  const LabelChip(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.pill,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: c.pillBorder),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: c.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Selectable pill. [dense] uses compact padding; otherwise a full-height
/// (42px) segment meant to be wrapped in an [Expanded].
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: dense ? null : 42,
        alignment: Alignment.center,
        padding: dense
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 9)
            : null,
        decoration: BoxDecoration(
          gradient: selected ? c.accentGradient : null,
          color: selected ? null : c.pill,
          borderRadius: BorderRadius.circular(dense ? 11 : 13),
          border: Border.all(
            color: selected ? Colors.transparent : c.pillBorder,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? c.onAccent : c.textSecondary,
              fontWeight: dense ? FontWeight.w600 : FontWeight.w700,
              fontSize: dense ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Large icon + label toggle used for the compression-mode switch.
class ModeToggle extends StatelessWidget {
  const ModeToggle({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? c.accentGradient : null,
          color: selected ? null : c.pill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : c.pillBorder,
          ),
        ),
        // scaleDown so a longer label (e.g. a third mode) never overflows on
        // narrow phones — it shrinks to fit instead.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? c.onAccent : c.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? c.onAccent : c.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Secondary (outlined/glass) action button.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.pill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.pillBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: disabled ? c.textMuted : c.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: disabled ? c.textMuted : c.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prominent gradient (or [danger]) primary button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: danger ? null : c.accentGradient,
          color: danger ? c.danger : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (danger ? c.danger : c.accent).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label plus a big monospace number with a unit (e.g. "目标大小  60 MB").
class ValueReadout extends StatelessWidget {
  const ValueReadout({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                fontFamilyFallback: kMonoFallback,
                height: 1,
              ),
            ),
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                unit,
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Round 44px glass icon button (theme toggle, language, …).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, this.icon, this.onTap, this.child});

  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c.pill,
          shape: BoxShape.circle,
          border: Border.all(color: c.pillBorder),
        ),
        child: child ?? Icon(icon, color: c.textPrimary, size: 20),
      ),
    );
  }
}
