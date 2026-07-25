// Image-compression models — deliberately separate from the video models so the
// two APIs never blur together.

/// Output container/codec for image compression.
enum ImageFormat {
  /// Lossy, universal. Quality-controlled.
  jpeg,

  /// Lossless (quality is ignored; target-size is met by downscaling).
  png,

  /// Lossy, ~30% smaller than JPEG at similar quality. Web: Chrome/Firefox.
  webp,

  /// Lossy, best ratio. iOS native; Android needs a HEIC encoder (else the
  /// engine falls back to JPEG). Not available on Web.
  heic,
}

/// Image compression request.
///
/// Priority: [targetSizeKB] (iterative, precise) > [quality].
class ImageCompressConfig {
  const ImageCompressConfig({
    this.format = ImageFormat.jpeg,
    this.quality = 85,
    this.targetSizeKB,
    this.maxWidth,
    this.maxHeight,
    this.keepExif = false,
  })  : assert(quality >= 1 && quality <= 100, 'quality must be 1–100'),
        assert(targetSizeKB == null || targetSizeKB > 0);

  /// Output format. Defaults to [ImageFormat.jpeg].
  final ImageFormat format;

  /// 1–100 quality, used when [targetSizeKB] is null (ignored for PNG).
  final int quality;

  /// Desired output size in KB. The native engines iterate (binary-search the
  /// quality, then downscale if needed) to land at or just under this — images
  /// encode in milliseconds, so this is accurate, unlike single-pass video.
  final int? targetSizeKB;

  /// Cap dimensions; aspect ratio is kept and the image is only scaled down.
  final int? maxWidth;
  final int? maxHeight;

  /// Keep EXIF metadata (orientation, GPS, …). Default strips it.
  final bool keepExif;

  Map<String, dynamic> toMap() => {
        'format': format.name,
        'quality': quality,
        'targetSizeKB': targetSizeKB,
        'maxWidth': maxWidth,
        'maxHeight': maxHeight,
        'keepExif': keepExif,
      };
}

/// Metadata about a source image. (Named `ImageMeta` to avoid clashing with
/// Flutter's `ImageInfo`.)
class ImageMeta {
  const ImageMeta({
    required this.path,
    required this.width,
    required this.height,
    required this.sizeBytes,
    this.format,
  });

  final String path;
  final int width;
  final int height;
  final int sizeBytes;
  final String? format;

  factory ImageMeta.fromMap(Map<dynamic, dynamic> m) => ImageMeta(
        path: m['path'] as String,
        width: (m['width'] as num).toInt(),
        height: (m['height'] as num).toInt(),
        sizeBytes: (m['sizeBytes'] as num).toInt(),
        format: m['format'] as String?,
      );
}

/// Result of a completed image compression.
class ImageCompressResult {
  const ImageCompressResult({
    required this.outputPath,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.width,
    required this.height,
    required this.format,
  });

  final String outputPath;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final int width;
  final int height;

  /// The format actually written ("jpeg"/"png"/"webp"/"heic") — may differ
  /// from the request if a fallback occurred.
  final String format;

  double get compressionRatio =>
      originalSizeBytes == 0 ? 1 : compressedSizeBytes / originalSizeBytes;

  double get savedPercent => (1 - compressionRatio) * 100;

  factory ImageCompressResult.fromMap(Map<dynamic, dynamic> m) =>
      ImageCompressResult(
        outputPath: m['outputPath'] as String,
        originalSizeBytes: (m['originalSizeBytes'] as num).toInt(),
        compressedSizeBytes: (m['compressedSizeBytes'] as num).toInt(),
        width: (m['width'] as num).toInt(),
        height: (m['height'] as num).toInt(),
        format: m['format'] as String,
      );
}
