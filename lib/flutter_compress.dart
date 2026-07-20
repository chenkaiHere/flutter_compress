import 'dart:async';

import 'flutter_compress_platform_interface.dart';
import 'src/models.dart';

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
  /// [outputDirectory] chooses where the encoded file is written; the filename
  /// is derived from the job id. When null, the plugin uses its own cache
  /// directory (call [clearCache] to reclaim it).
  Future<VideoCompressResult> compress(
    String path,
    VideoCompressConfig config, {
    void Function(CompressionProgress)? onProgress,
    CancellationToken? cancellationToken,
    String? outputDirectory,
  }) async {
    final id = _newId();
    cancellationToken?._bind(id);

    if (cancellationToken?.isCancelled ?? false) {
      throw VideoCompressCancelledException();
    }

    final outputPath = outputDirectory == null
        ? null
        : '${_stripTrailingSlash(outputDirectory)}/$id.mp4';

    StreamSubscription<CompressionProgress>? sub;
    if (onProgress != null) {
      sub = progressStream.where((p) => p.id == id).listen(onProgress);
    }
    try {
      return await _platform.compress(id, path, config, outputPath);
    } finally {
      await sub?.cancel();
    }
  }

  String _stripTrailingSlash(String dir) =>
      dir.endsWith('/') ? dir.substring(0, dir.length - 1) : dir;

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
