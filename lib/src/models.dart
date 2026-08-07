// Data models & configuration for flutter_compress.
//
// Design goal: express the *intent* of a compression job (a target size, a
// target bitrate, or a quality tier) rather than a fixed "quality preset".
// The native side turns that intent into concrete encoder settings.

/// Video codec to request for the output stream.
enum VideoCodec {
  /// H.264 / AVC. Universally supported, larger files.
  h264,

  /// H.265 / HEVC. ~40% smaller at similar quality, but needs a hardware
  /// encoder. When unavailable, the plugin automatically falls back to
  /// [h264] (see [VideoCompressResult.codec] for what was actually used).
  h265,
}

/// Convenience quality tiers. Used only when neither [VideoCompressConfig.targetSizeMB]
/// nor [VideoCompressConfig.videoBitrateKbps] is provided.
enum CompressQuality {
  /// Keep near-source resolution, high bitrate.
  high,

  /// 720p-class output, balanced bitrate. Sensible default.
  medium,

  /// 480p-class output, low bitrate.
  low,

  /// Aggressive size reduction, noticeable quality loss.
  veryLow,
}

/// Output container for compressed video.
enum VideoContainer {
  /// Keep the source's container where the platform's muxer supports it, and
  /// fall back to [mp4] otherwise. In practice: iOS keeps `.mov`/`.mp4`;
  /// Android and Web can only produce `.mp4`, so non-mp4 sources become mp4.
  /// The output extension always matches the bytes actually written.
  auto,

  /// Always write an `.mp4` (the universal container for H.264/H.265).
  mp4,
}

/// How to reconcile output dimensions with encoder requirements.
enum DimensionAlignment {
  /// Round width/height to the nearest multiple of 16 (only when needed).
  /// Prevents green/black edge artifacts from encoder macroblock padding.
  auto16,

  /// Keep requested dimensions exactly (may produce edge artifacts).
  none,
}

/// A trim window, in milliseconds from the start of the source.
class TrimRange {
  const TrimRange({required this.startMs, required this.endMs})
      : assert(endMs > startMs, 'endMs must be greater than startMs');

  final int startMs;
  final int endMs;

  Map<String, dynamic> toMap() => {'startMs': startMs, 'endMs': endMs};
}

/// Full compression request.
///
/// Priority when multiple size controls are set:
///   1. [targetSizeMB]      — plugin computes the bitrate to hit this size
///   2. [videoBitrateKbps]  — explicit bitrate
///   3. [qualityPercent]    — output bitrate = source bitrate × percent
///   4. [quality]           — preset tier (maps to a percentage; fallback)
class VideoCompressConfig {
  const VideoCompressConfig({
    this.quality = CompressQuality.medium,
    this.qualityPercent,
    this.targetSizeMB,
    this.videoBitrateKbps,
    this.codec = VideoCodec.h265,
    this.maxWidth,
    this.maxHeight,
    this.frameRate,
    this.removeAudio = false,
    this.audioBitrateKbps,
    this.trim,
    this.alignment = DimensionAlignment.auto16,
    this.keepOriginalIfLarger = true,
    this.container = VideoContainer.auto,
  })  : assert(
          qualityPercent == null ||
              (qualityPercent >= 1 && qualityPercent <= 100),
          'qualityPercent must be between 1 and 100',
        ),
        // Without these, a zero or negative value silently reaches the native
        // side and yields a garbage bitrate instead of an error.
        assert(targetSizeMB == null || targetSizeMB > 0,
            'targetSizeMB must be > 0'),
        assert(videoBitrateKbps == null || videoBitrateKbps > 0,
            'videoBitrateKbps must be > 0'),
        assert(audioBitrateKbps == null || audioBitrateKbps > 0,
            'audioBitrateKbps must be > 0'),
        assert(maxWidth == null || maxWidth > 0, 'maxWidth must be > 0'),
        assert(maxHeight == null || maxHeight > 0, 'maxHeight must be > 0'),
        assert(frameRate == null || frameRate > 0, 'frameRate must be > 0');

  /// Preset quality tier. Used only when [qualityPercent] is null (and no
  /// higher-priority size control is set).
  final CompressQuality quality;

  /// Explicit target quality as a percentage (1–100) of the *source* video
  /// bitrate — e.g. 50 roughly halves the bitrate. More flexible than [quality]
  /// and, being explicit, takes priority over it. Ignored if [targetSizeMB] or
  /// [videoBitrateKbps] is set.
  final int? qualityPercent;

  /// Desired output size in megabytes. The native side derives a video
  /// bitrate from this (after subtracting the audio budget and applying a
  /// safety margin). Highest-priority size control.
  final int? targetSizeMB;

  /// Explicit average video bitrate in kbps. Ignored if [targetSizeMB] is set.
  final int? videoBitrateKbps;

  final VideoCodec codec;

  /// Cap the longest side / dimensions. Aspect ratio is preserved; the video
  /// is only ever scaled *down*, never up.
  final int? maxWidth;
  final int? maxHeight;

  /// Cap the frame rate (e.g. 30). Source fps is kept if lower.
  final double? frameRate;

  final bool removeAudio;
  final int? audioBitrateKbps;

  final TrimRange? trim;

  final DimensionAlignment alignment;

  /// If the compressed file would be larger than the source, return the
  /// original untouched and mark the result [VideoCompressResult.skipped].
  final bool keepOriginalIfLarger;

  /// Output container. Defaults to [VideoContainer.auto] (keep the source's
  /// container where the platform can, else mp4).
  final VideoContainer container;

  Map<String, dynamic> toMap() => {
        'quality': quality.name,
        'qualityPercent': qualityPercent,
        'targetSizeMB': targetSizeMB,
        'videoBitrateKbps': videoBitrateKbps,
        'codec': codec.name,
        'maxWidth': maxWidth,
        'maxHeight': maxHeight,
        'frameRate': frameRate,
        'removeAudio': removeAudio,
        'audioBitrateKbps': audioBitrateKbps,
        'trim': trim?.toMap(),
        'alignment': alignment.name,
        'keepOriginalIfLarger': keepOriginalIfLarger,
        'container': container.name,
      };
}

/// Metadata about a source (or output) video.
class VideoInfo {
  const VideoInfo({
    required this.path,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.sizeBytes,
    required this.bitrateKbps,
    this.frameRate,
    this.codec,
    this.rotation = 0,
  });

  final String path;
  final int width;
  final int height;
  final int durationMs;
  final int sizeBytes;
  final int bitrateKbps;
  final double? frameRate;
  final String? codec;
  final int rotation;

  factory VideoInfo.fromMap(Map<dynamic, dynamic> m) => VideoInfo(
        path: m['path'] as String,
        width: (m['width'] as num).toInt(),
        height: (m['height'] as num).toInt(),
        durationMs: (m['durationMs'] as num).toInt(),
        sizeBytes: (m['sizeBytes'] as num).toInt(),
        bitrateKbps: (m['bitrateKbps'] as num).toInt(),
        frameRate: (m['frameRate'] as num?)?.toDouble(),
        codec: m['codec'] as String?,
        rotation: (m['rotation'] as num?)?.toInt() ?? 0,
      );
}

/// Result of a completed compression.
class VideoCompressResult {
  const VideoCompressResult({
    required this.id,
    required this.outputPath,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.codec,
    required this.skipped,
  });

  final String id;
  final String outputPath;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final int width;
  final int height;
  final int durationMs;

  /// The codec actually used ("h264" / "h265") — may differ from the request
  /// if a fallback occurred.
  final String codec;

  /// True when compression was skipped because it would not have reduced size
  /// (see [VideoCompressConfig.keepOriginalIfLarger]); [outputPath] then points
  /// at the original file.
  final bool skipped;

  double get compressionRatio =>
      originalSizeBytes == 0 ? 1 : compressedSizeBytes / originalSizeBytes;

  double get savedPercent => (1 - compressionRatio) * 100;

  factory VideoCompressResult.fromMap(Map<dynamic, dynamic> m) =>
      VideoCompressResult(
        id: m['id'] as String,
        outputPath: m['outputPath'] as String,
        originalSizeBytes: (m['originalSizeBytes'] as num).toInt(),
        compressedSizeBytes: (m['compressedSizeBytes'] as num).toInt(),
        width: (m['width'] as num).toInt(),
        height: (m['height'] as num).toInt(),
        durationMs: (m['durationMs'] as num).toInt(),
        codec: m['codec'] as String,
        skipped: m['skipped'] as bool? ?? false,
      );
}

/// A pre-flight estimate produced without actually encoding.
class CompressionEstimate {
  const CompressionEstimate({
    required this.estimatedSizeBytes,
    required this.estimatedBitrateKbps,
    required this.targetWidth,
    required this.targetHeight,
  });

  final int estimatedSizeBytes;
  final int estimatedBitrateKbps;
  final int targetWidth;
  final int targetHeight;

  factory CompressionEstimate.fromMap(Map<dynamic, dynamic> m) =>
      CompressionEstimate(
        estimatedSizeBytes: (m['estimatedSizeBytes'] as num).toInt(),
        estimatedBitrateKbps: (m['estimatedBitrateKbps'] as num).toInt(),
        targetWidth: (m['targetWidth'] as num).toInt(),
        targetHeight: (m['targetHeight'] as num).toInt(),
      );
}

/// Live progress event streamed during compression.
class CompressionProgress {
  const CompressionProgress({
    required this.id,
    required this.progress,
    this.estimatedRemainingMs,
    this.currentOutputBytes,
  });

  /// Job id — matches the id returned by [FlutterCompress.compress].
  final String id;

  /// 0.0 – 1.0.
  final double progress;

  final int? estimatedRemainingMs;
  final int? currentOutputBytes;

  factory CompressionProgress.fromMap(Map<dynamic, dynamic> m) =>
      CompressionProgress(
        id: m['id'] as String,
        progress: (m['progress'] as num).toDouble(),
        estimatedRemainingMs: (m['estimatedRemainingMs'] as num?)?.toInt(),
        currentOutputBytes: (m['currentOutputBytes'] as num?)?.toInt(),
      );
}

// Exceptions live in src/exceptions.dart — they're shared with the image API.
