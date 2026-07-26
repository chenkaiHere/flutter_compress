import 'dart:async';

import 'flutter_compress_platform_interface.dart';
import 'src/image_models.dart';
import 'src/models.dart';

export 'src/image_models.dart';
export 'src/models.dart';

/// A cancellation handle for a single compression job.
///
/// Pass one to [FlutterCompress.compress]; call [cancel] to abort. Cancelling
/// makes the in-flight `compress` future complete with a
/// [VideoCompressCancelledException].
class CancellationToken {
  bool _cancelled = false;
  String? _id;
  bool get isCancelled => _cancelled;

  void _bind(String id) => _id = id;

  Future<void> cancel() async {
    _cancelled = true;
    if (_id != null) {
      await FlutterCompress.instance.cancel(_id);
    }
  }
}

/// High-level, app-facing API for video compression.
///
/// ```dart
/// final result = await FlutterCompress.instance.compress(
///   inputPath,
///   const VideoCompressConfig(targetSizeMB: 10, codec: VideoCodec.h265),
///   onProgress: (p) => print('${(p.progress * 100).toStringAsFixed(0)}%'),
/// );
/// print('saved ${result.savedPercent.toStringAsFixed(1)}%');
/// ```
class FlutterCompress {
  FlutterCompress._();
  static final FlutterCompress instance = FlutterCompress._();

  FlutterCompressPlatform get _platform => FlutterCompressPlatform.instance;

  int _counter = 0;
  String _newId() =>
      'job_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  /// Broadcast progress for every job. Prefer the per-call [onProgress]
  /// callback in [compress] unless you need a global feed (e.g. batch UI).
  Stream<CompressionProgress> get progressStream => _platform.progressStream;

  /// Probe a source video's metadata.
  Future<VideoInfo> getVideoInfo(String path) => _platform.getVideoInfo(path);

  /// Estimate the output size/bitrate for [config] without encoding.
  Future<CompressionEstimate> estimate(
          String path, VideoCompressConfig config) =>
      _platform.estimate(path, config);

  /// Compress a single video.
  ///
  /// [onProgress] receives events for this job only. Provide a
  /// [cancellationToken] to abort mid-flight.
  ///
  /// [outputDirectory] chooses where the encoded file is written; when null the
  /// plugin uses its own cache directory (call [clearCache] to reclaim it).
  ///
  /// [outputName] sets the output file name **without extension** — the correct
  /// extension is appended automatically from the actual container (see
  /// [VideoCompressConfig.container]). When null, the name defaults to the
  /// source's base name plus a timestamp.
  Future<VideoCompressResult> compress(
    String path,
    VideoCompressConfig config, {
    void Function(CompressionProgress)? onProgress,
    CancellationToken? cancellationToken,
    String? outputDirectory,
    String? outputName,
  }) async {
    final id = _newId();
    cancellationToken?._bind(id);

    if (cancellationToken?.isCancelled ?? false) {
      throw VideoCompressCancelledException();
    }

    StreamSubscription<CompressionProgress>? sub;
    if (onProgress != null) {
      sub = progressStream.where((p) => p.id == id).listen(onProgress);
    }
    try {
      return await _platform.compress(
          id, path, config, outputDirectory, outputName);
    } finally {
      await sub?.cancel();
    }
  }

  /// Compress a list of videos sequentially, reporting per-item results.
  ///
  /// [onItemProgress] carries the item index alongside its progress so a batch
  /// UI can render one bar per file.
  Future<List<VideoCompressResult>> compressAll(
    List<String> paths,
    VideoCompressConfig config, {
    void Function(int index, CompressionProgress)? onItemProgress,
    CancellationToken? cancellationToken,
    String? outputDirectory,
  }) async {
    final results = <VideoCompressResult>[];
    for (var i = 0; i < paths.length; i++) {
      if (cancellationToken?.isCancelled ?? false) {
        throw VideoCompressCancelledException();
      }
      results.add(await compress(
        paths[i],
        config,
        onProgress: onItemProgress == null ? null : (p) => onItemProgress(i, p),
        cancellationToken: cancellationToken,
        outputDirectory: outputDirectory,
      ));
    }
    return results;
  }

  /// Cancel a specific job by [id], or all jobs when [id] is null.
  Future<void> cancel([String? id]) => _platform.cancel(id);

  Future<bool> isCompressing() => _platform.isCompressing();

  /// Extract a JPEG thumbnail; returns its file path.
  Future<String> getThumbnail(
    String path, {
    int positionMs = 0,
    int quality = 80,
    int? maxWidth,
  }) =>
      _platform.getThumbnail(
        path,
        positionMs: positionMs,
        quality: quality,
        maxWidth: maxWidth,
      );

  /// Delete temporary files this plugin produced.
  Future<void> clearCache() => _platform.clearCache();

  // ==== Images ============================================================
  // A separate API surface from the video methods above; they never mix.

  /// Probe a source image's dimensions/size/format.
  Future<ImageMeta> getImageInfo(String path) => _platform.getImageInfo(path);

  /// Compress a single image.
  ///
  /// With [ImageCompressConfig.targetSizeKB] the native engine iterates to land
  /// at or just under the target (accurate, since images encode fast).
  ///
  /// [outputDirectory] chooses where to write; null uses the plugin cache.
  /// [outputName] sets the file name **without extension** — the correct
  /// extension is appended from the actual output format (which follows the
  /// source when [ImageCompressConfig.format] is null). When null, the name
  /// defaults to the source's base name plus a timestamp.
  Future<ImageCompressResult> compressImage(
    String path,
    ImageCompressConfig config, {
    String? outputDirectory,
    String? outputName,
  }) {
    return _platform.compressImage(path, config, outputDirectory, outputName);
  }

  /// Compress an image **losslessly** (pixel-for-pixel) — a convenience wrapper
  /// over [compressImage] with `lossless: true`. [quality] / `targetSizeKB`
  /// don't apply. The format is preserved: PNG is truly lossless, WebP uses its
  /// lossless mode where supported, and JPEG stays JPEG at maximum quality.
  /// Omit [format] to keep the source's format.
  Future<ImageCompressResult> compressImageLossless(
    String path, {
    ImageFormat? format,
    int? maxWidth,
    int? maxHeight,
    bool keepExif = false,
    String? outputDirectory,
    String? outputName,
  }) {
    return compressImage(
      path,
      ImageCompressConfig(
        format: format,
        lossless: true,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        keepExif: keepExif,
      ),
      outputDirectory: outputDirectory,
      outputName: outputName,
    );
  }

  /// Compress a list of images sequentially. Each output is auto-named from its
  /// own source (base name + timestamp).
  Future<List<ImageCompressResult>> compressImages(
    List<String> paths,
    ImageCompressConfig config, {
    String? outputDirectory,
  }) async {
    final out = <ImageCompressResult>[];
    for (final p in paths) {
      out.add(await compressImage(p, config, outputDirectory: outputDirectory));
    }
    return out;
  }

  // ========================================================================

  /// Persist [path] to a user-accessible location and return where it landed.
  ///
  /// - **Android**: inserted into the public **Downloads** collection via
  ///   MediaStore (no runtime permission needed on Android 10+; on Android 9
  ///   and below it uses `WRITE_EXTERNAL_STORAGE`). Returns a `content://` URI
  ///   on Android 10+, or a file path on older versions.
  /// - **iOS**: copied into the app's Documents directory (sandboxed; visible
  ///   in the Files app when the app enables file sharing). Returns a file path.
  ///
  /// [fileName] overrides the destination file name (defaults to the source's).
  Future<String> saveToDownloads(String path, {String? fileName}) =>
      _platform.saveToDownloads(path, fileName);
}
