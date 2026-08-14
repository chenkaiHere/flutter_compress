import 'dart:async';

import 'flutter_compress_platform_interface.dart';
import 'src/exceptions.dart';
import 'src/image_models.dart';
import 'src/models.dart';

export 'src/error_codes.dart';
export 'src/exceptions.dart';
export 'src/image_models.dart';
export 'src/models.dart';
export 'src/size_math.dart';

/// A cancellation handle for one or more compression jobs.
///
/// Pass one to [FlutterCompress.compress], [FlutterCompress.compressAll] or
/// [FlutterCompress.compressImages]; call [cancel] to abort. Cancelling makes
/// the in-flight future complete with a [VideoCompressCancelledException] (or
/// [ImageCompressCancelledException] for images) — catch [CompressCancelled] to
/// handle either.
///
/// A token latches: once cancelled it stays cancelled, and reusing it would
/// abort the next job immediately. Either create a fresh token per run or call
/// [reset] between runs.
class CancellationToken {
  bool _cancelled = false;

  /// Every job this token is bound to. A token handed to several concurrent
  /// jobs cancels all of them, not just the most recent.
  final Set<String> _ids = <String>{};

  bool get isCancelled => _cancelled;

  void _bind(String id) => _ids.add(id);

  void _unbind(String id) => _ids.remove(id);

  /// Make this token usable again for a new job.
  void reset() {
    _cancelled = false;
    _ids.clear();
  }

  Future<void> cancel() async {
    _cancelled = true;
    for (final id in _ids.toList()) {
      await FlutterCompress.instance.cancel(id);
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
      cancellationToken?._unbind(id);
    }
  }

  /// Compress a list of videos sequentially, reporting per-item results.
  ///
  /// [onItemProgress] carries the item index alongside its progress so a batch
  /// UI can render one bar per file.
  ///
  /// With [continueOnError] a failing video doesn't abort the batch: it is
  /// reported to [onItemError] and omitted from the result, so the returned list
  /// may be shorter than [paths]. Without it the first failure throws and the
  /// already-encoded results are lost.
  Future<List<VideoCompressResult>> compressAll(
    List<String> paths,
    VideoCompressConfig config, {
    void Function(int index, CompressionProgress)? onItemProgress,
    CancellationToken? cancellationToken,
    String? outputDirectory,
    bool continueOnError = false,
    void Function(int index, String path, Object error)? onItemError,
  }) async {
    final results = <VideoCompressResult>[];
    for (var i = 0; i < paths.length; i++) {
      if (cancellationToken?.isCancelled ?? false) {
        throw VideoCompressCancelledException();
      }
      try {
        results.add(await compress(
          paths[i],
          config,
          onProgress:
              onItemProgress == null ? null : (p) => onItemProgress(i, p),
          cancellationToken: cancellationToken,
          outputDirectory: outputDirectory,
        ));
      } catch (e) {
        // A cancel is for the whole batch, never just this item.
        if (!continueOnError || e is CompressCancelled) rethrow;
        onItemError?.call(i, paths[i], e);
      }
    }
    return results;
  }

  /// Cancel one job by [id] — or, when [id] is omitted, **every** job.
  ///
  /// Prefer a [CancellationToken] (it tracks its own job ids) or the explicit
  /// [cancelAll]; the bare `cancel()` form is easy to write by accident when you
  /// meant to stop a single job.
  Future<void> cancel([String? id]) => _platform.cancel(id);

  /// Cancel every in-flight job. Same as `cancel()` with no id, but says so.
  Future<void> cancelAll() => _platform.cancel(null);

  Future<bool> isCompressing() => _platform.isCompressing();

  /// Whether **video** compression works on this platform.
  ///
  /// Always true on Android/iOS. On web it checks for WebCodecs and the bundled
  /// demux/mux libraries, so call it before offering a compress action rather
  /// than discovering the gap by catching `CompressErrorCode.unsupported`.
  /// Image compression only needs a canvas and is always available.
  Future<bool> isSupported() => _platform.isSupported();

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

  /// Delete temporary files this plugin produced. On web this revokes every
  /// output blob: URL the engine handed out.
  Future<void> clearCache() => _platform.clearCache();

  /// Release a single output once you're done with it.
  ///
  /// On Android/iOS this is a no-op (files live until [clearCache]). On **web**
  /// it revokes the output's blob: URL — without it the browser holds the whole
  /// encoded file in memory for the lifetime of the page, so call it after you
  /// have downloaded or uploaded the result.
  Future<void> releaseOutput(String outputPath) =>
      _platform.releaseOutput(outputPath);

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
  ///
  /// [onItemDone] fires after each image with its 0-based index and the running
  /// total — images encode in milliseconds, so per-item is the useful
  /// granularity for a batch progress bar.
  ///
  /// [cancellationToken] stops the run between items, throwing
  /// [ImageCompressCancelledException]; images already finished are lost, so
  /// prefer [continueOnError] + [onItemDone] if you need to keep partial work.
  ///
  /// With [continueOnError] a failing image doesn't abort the batch: it is
  /// reported to [onItemError] and simply omitted from the result, so the
  /// returned list may be shorter than [paths].
  Future<List<ImageCompressResult>> compressImages(
    List<String> paths,
    ImageCompressConfig config, {
    String? outputDirectory,
    void Function(int index, int total)? onItemDone,
    CancellationToken? cancellationToken,
    bool continueOnError = false,
    void Function(int index, String path, Object error)? onItemError,
  }) async {
    final out = <ImageCompressResult>[];
    for (var i = 0; i < paths.length; i++) {
      if (cancellationToken?.isCancelled ?? false) {
        throw ImageCompressCancelledException();
      }
      try {
        out.add(await compressImage(
          paths[i],
          config,
          outputDirectory: outputDirectory,
        ));
      } catch (e) {
        if (!continueOnError) rethrow;
        onItemError?.call(i, paths[i], e);
      }
      onItemDone?.call(i, paths.length);
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
