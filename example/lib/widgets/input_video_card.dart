import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_compress/flutter_compress.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import 'ui.dart';

/// Input picker: an empty "pick video" state, or a preview card with the
/// thumbnail, filename, metadata chips and a "reselect" button.
class InputVideoCard extends StatelessWidget {
  const InputVideoCard({
    super.key,
    required this.inputPath,
    required this.info,
    required this.thumbPath,
    required this.busy,
    required this.onPick,
  });

  final String? inputPath;
  final VideoInfo? info;
  final String? thumbPath;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l10n = AppLocalizations.of(context);

    if (inputPath == null) {
      return GestureDetector(
        onTap: busy ? null : onPick,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 34),
          child: Column(
            children: [
              Icon(Icons.video_call_outlined, color: c.accent, size: 34),
              const SizedBox(height: 10),
              Text(
                l10n.pickVideo,
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GlassCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(thumbPath: thumbPath, info: info),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.inputVideo,
                      style: TextStyle(color: c.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      inputPath!.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (info != null)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          LabelChip(_resLabel(info!)),
                          LabelChip(
                            '${(info!.sizeBytes / 1024 / 1024).toStringAsFixed(0)} MB',
                          ),
                          if (info!.codec != null)
                            LabelChip(info!.codec!.toUpperCase()),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GhostButton(
            icon: Icons.refresh,
            label: l10n.reselectVideo,
            onTap: busy ? null : onPick,
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.thumbPath, required this.info});
  final String? thumbPath;
  final VideoInfo? info;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: thumbPath != null
                // Web thumbnails are data: URLs; native ones are file paths.
                ? (kIsWeb
                      ? Image.network(thumbPath!, fit: BoxFit.cover)
                      : Image.file(File(thumbPath!), fit: BoxFit.cover))
                : DecoratedBox(
                    decoration: BoxDecoration(gradient: c.thumbGradient),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
          ),
          if (info != null)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _fmtDuration(info!.durationMs),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _fmtDuration(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String _resLabel(VideoInfo i) {
  final shortSide = i.width < i.height ? i.width : i.height;
  return '${shortSide}p';
}
