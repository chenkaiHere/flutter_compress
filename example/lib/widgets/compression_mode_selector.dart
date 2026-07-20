import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/compress_options.dart';
import 'ui.dart';

/// The mutually-exclusive top-level mode switch: target size vs quality.
class CompressionModeSelector extends StatelessWidget {
  const CompressionModeSelector({
    super.key,
    required this.mode,
    required this.busy,
    required this.onChanged,
  });

  final SizeMode mode;
  final bool busy;
  final ValueChanged<SizeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: ModeToggle(
            icon: Icons.data_usage,
            label: l10n.modeTargetSize,
            selected: mode == SizeMode.targetSize,
            onTap: busy ? null : () => onChanged(SizeMode.targetSize),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ModeToggle(
            icon: Icons.star_outline,
            label: l10n.modeQuality,
            selected: mode == SizeMode.quality,
            onTap: busy ? null : () => onChanged(SizeMode.quality),
          ),
        ),
      ],
    );
  }
}
