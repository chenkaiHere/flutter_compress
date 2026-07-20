import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import 'ui.dart';

/// Info / Estimate secondary actions plus the primary Compress/Cancel button.
class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.busy,
    required this.onInfo,
    required this.onEstimate,
    required this.onCompress,
    required this.onCancel,
  });

  final bool busy;
  final VoidCallback onInfo;
  final VoidCallback onEstimate;
  final VoidCallback onCompress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: GhostButton(
                icon: Icons.info_outline,
                label: l10n.actionInfo,
                onTap: busy ? null : onInfo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GhostButton(
                icon: Icons.calculate_outlined,
                label: l10n.actionEstimate,
                onTap: busy ? null : onEstimate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: busy ? l10n.actionCancel : l10n.actionCompress,
          icon: busy ? Icons.close : Icons.bolt,
          onTap: busy ? onCancel : onCompress,
          danger: busy,
        ),
      ],
    );
  }
}

/// Determinate progress bar with a percentage read-out.
class ProgressView extends StatelessWidget {
  const ProgressView({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: c.pill,
            valueColor: AlwaysStoppedAnimation(c.accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12,
            fontFamilyFallback: kMonoFallback,
          ),
        ),
      ],
    );
  }
}

/// Scrollable, monospace activity log.
class LogView extends StatelessWidget {
  const LogView({super.key, required this.log});
  final String log;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 160),
        child: SingleChildScrollView(
          child: Text(
            log,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11.5,
              height: 1.5,
              fontFamilyFallback: kMonoFallback,
            ),
          ),
        ),
      ),
    );
  }
}
