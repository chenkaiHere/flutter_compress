// Turns a VideoCompressConfig intent (target size / bitrate / quality) into
// concrete encoder numbers.
//
// This is the Dart half of a three-way port — `SizeMath.kt` and `SizeMath.swift`
// implement the same algorithm line for line. **Any change here MUST be mirrored
// in both** (CLAUDE.md §12.2). It deliberately depends on nothing but the models
// so it stays unit-testable on the VM: the web platform implementation imports
// `dart:js_interop` and cannot be loaded by `flutter test`.

import 'models.dart';

/// Shared size/bitrate math. Pure functions, no platform dependencies.
abstract final class SizeMath {
  /// Real muxed output runs slightly over `bitrate × duration` (container
  /// overhead, keyframes), so aim a little under the requested size.
  static const double sizeSafety = 0.95;

  /// Never ask an encoder for less than this — below it output is unusable.
  static const int minVideoBps = 100000;

  /// Assumed audio bitrate when the caller doesn't specify one.
  static const int defaultAudioKbps = 128;

  /// The video bitrate (bits/sec) implied by [config].
  ///
  /// Priority: `targetSizeMB` → `videoBitrateKbps` → `qualityPercent` →
  /// `quality` preset.
  ///
  /// [reserveAudio] subtracts an audio budget from a target size. Native passes
  /// `true`; **web passes `false`** because its v1 pipeline drops the audio
  /// track, so the whole budget belongs to video. Making that an argument keeps
  /// the divergence explicit and testable instead of forking the algorithm.
  static int videoBitrateBps({
    required VideoCompressConfig config,
    required int durationMs,
    required int sourceBitrateKbps,
    required int targetHeight,
    bool reserveAudio = true,
  }) {
    final targetMB = config.targetSizeMB;
    if (targetMB != null) {
      final totalBits = targetMB * 8 * 1024 * 1024;
      final durationSec = (durationMs / 1000.0).clamp(0.001, double.infinity);
      final audioBps = (!reserveAudio || config.removeAudio)
          ? 0
          : (config.audioBitrateKbps ?? defaultAudioKbps) * 1000;
      final videoBits = totalBits * sizeSafety - audioBps * durationSec;
      return _atLeastMin((videoBits / durationSec).toInt());
    }

    final explicit = config.videoBitrateKbps;
    if (explicit != null) return explicit * 1000;

    // A percentage of the *source* bitrate. <= 100 means we never re-inflate.
    final percent =
        (config.qualityPercent ?? _presetPercent(config.quality)).clamp(1, 100);
    final srcBps = sourceBitrateKbps * 1000;
    if (srcBps > 0) {
      return _atLeastMin((srcBps * percent / 100.0).toInt());
    }

    // Source bitrate unknown: fall back to a resolution-based baseline,
    // anchored so 50% is a reasonable "medium".
    final width = targetHeight * 16 ~/ 9;
    final baselineMedium = width * targetHeight * 30 * 0.12;
    return _atLeastMin((baselineMedium * percent / 50.0).toInt());
  }

  /// Output width/height: preserve aspect, only ever scale *down* to the caps,
  /// then align.
  static (int, int) targetDimensions(
    int srcW,
    int srcH,
    VideoCompressConfig config,
  ) {
    if (srcW <= 0 || srcH <= 0) return (srcW, srcH);
    final maxW = config.maxWidth;
    final maxH = config.maxHeight;
    // No cap requested → keep the source exactly. Aligning here would round
    // 1080 *up* to 1088, which breaks the "only ever scale down" promise and
    // forces a needless full-frame rescale.
    if (maxW == null && maxH == null) return (srcW, srcH);

    var w = srcW.toDouble();
    var h = srcH.toDouble();
    if (maxW != null && w > maxW) {
      final s = maxW / w;
      w *= s;
      h *= s;
    }
    if (maxH != null && h > maxH) {
      final s = maxH / h;
      w *= s;
      h *= s;
    }
    final m = config.alignment == DimensionAlignment.auto16 ? 16 : 2;
    return (_align(w.toInt(), m), _align(h.toInt(), m));
  }

  static int _presetPercent(CompressQuality q) => switch (q) {
        CompressQuality.high => 80,
        CompressQuality.medium => 50,
        CompressQuality.low => 30,
        CompressQuality.veryLow => 15,
      };

  /// Clamp to the floor only. A `clamp(min, max)` with a source bitrate below
  /// [minVideoBps] would make `lower > upper` and throw.
  static int _atLeastMin(int bps) => bps < minVideoBps ? minVideoBps : bps;

  /// Always rounds *down*, so alignment can never upscale.
  static int _align(int v, int m) {
    final r = (v ~/ m) * m;
    return r < m ? m : r;
  }
}
