import 'package:flutter/material.dart';
import 'package:flutter_compress/flutter_compress.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import 'ui.dart';

/// Target-size slider (1–200 MB) with the source size for reference.
class TargetSizeControl extends StatelessWidget {
  const TargetSizeControl({
    super.key,
    required this.targetSizeMB,
    required this.info,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final int targetSizeMB;
  final VideoInfo? info;
  final ValueChanged<int> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    // The ceiling is the source size — you can't "compress" to larger than the
    // original. Fall back to 200 MB until a video is loaded.
    final maxMB = info != null
        ? (info!.sizeBytes / 1024 / 1024).ceil().clamp(2, 100000)
        : 200;
    final value = targetSizeMB.clamp(1, maxMB).toDouble();
    return GlassCard(
      child: Column(
        children: [
          ValueReadout(
              label: l10n.modeTargetSize, value: '${value.round()}', unit: 'MB'),
          Slider(
            value: value,
            min: 1,
            max: maxMB.toDouble(),
            divisions: maxMB - 1,
            onChanged: (v) => onChanged(v.round()),
            onChangeEnd: (_) => onChangeEnd(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 MB', style: TextStyle(color: c.textMuted, fontSize: 11)),
              if (info != null)
                Text('${l10n.sourceLabel} $maxMB MB',
                    style: TextStyle(color: c.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
