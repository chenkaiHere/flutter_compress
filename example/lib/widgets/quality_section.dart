import 'package:flutter/material.dart';
import 'package:flutter_compress/flutter_compress.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/compress_options.dart';
import 'ui.dart';

/// Quality mode: a preset-tier / custom-percentage sub-switch and its control.
class QualitySection extends StatelessWidget {
  const QualitySection({
    super.key,
    required this.qualityMode,
    required this.quality,
    required this.qualityPercent,
    required this.busy,
    required this.onQualityModeChanged,
    required this.onQualityChanged,
    required this.onPercentChanged,
    required this.onChangeEnd,
  });

  final QualityMode qualityMode;
  final CompressQuality quality;
  final int qualityPercent;
  final bool busy;
  final ValueChanged<QualityMode> onQualityModeChanged;
  final ValueChanged<CompressQuality> onQualityChanged;
  final ValueChanged<int> onPercentChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    final isPreset = qualityMode == QualityMode.preset;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Pill(
                  label: l10n.modePreset,
                  selected: isPreset,
                  onTap: busy
                      ? null
                      : () => onQualityModeChanged(QualityMode.preset),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pill(
                  label: l10n.modeCustom,
                  selected: !isPreset,
                  onTap: busy
                      ? null
                      : () => onQualityModeChanged(QualityMode.percent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isPreset)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in CompressQuality.values)
                  Pill(
                    dense: true,
                    label: q.name,
                    selected: quality == q,
                    onTap: busy ? null : () => onQualityChanged(q),
                  ),
              ],
            )
          else ...[
            ValueReadout(
                label: l10n.qualityPercent, value: '$qualityPercent', unit: '%'),
            Slider(
              value: qualityPercent.toDouble(),
              min: 1,
              max: 100,
              onChanged: (v) => onPercentChanged(v.round()),
              onChangeEnd: (_) => onChangeEnd(),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child:
                  Text('1%', style: TextStyle(color: c.textMuted, fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}
