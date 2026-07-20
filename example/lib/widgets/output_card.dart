import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';

/// Output destination row. On Android output always goes to public Downloads
/// (MediaStore), so the picker is hidden there.
class OutputCard extends StatelessWidget {
  const OutputCard({
    super.key,
    required this.isAndroid,
    required this.outputDir,
    required this.busy,
    required this.onPick,
  });

  final bool isAndroid;
  final String? outputDir;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, color: c.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.outputFolder,
                  style: TextStyle(color: c.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  isAndroid
                      ? l10n.outputHintAndroid
                      : (outputDir ?? l10n.outputHintOther),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!isAndroid)
            TextButton(
              onPressed: busy ? null : onPick,
              child: Text(
                l10n.pickFolder,
                style: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
