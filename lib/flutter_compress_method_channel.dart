import 'package:flutter/services.dart';

import 'flutter_compress_platform_interface.dart';
import 'src/error_codes.dart';
import 'src/exceptions.dart';
import 'src/image_models.dart';
import 'src/models.dart';

/// MethodChannel + EventChannel implementation of [FlutterCompressPlatform].
///
/// Channel keys are centralized in [_Keys] so the Dart and native sides have a
/// single source of truth. (If this plugin grows, these hand-written maps are
/// the natural point to migrate to Pigeon for compile-time-checked messages.)
class MethodChannelFlutterCompress extends FlutterCompressPlatform {
  final MethodChannel _method = const MethodChannel('flutter_compress/methods');
  final EventChannel _progress =
      const EventChannel('flutter_compress/progress');

  Stream<CompressionProgress>? _progressStream;

  @override
  Stream<CompressionProgress> get progressStream {
    _progressStream ??= _progress.receiveBroadcastStream().map(
          (e) => CompressionProgress.fromMap(
            (e as Map).cast<dynamic, dynamic>(),
          ),
        );
    return _progressStream!;
  }

  /// Invoke [method] and map any platform failure onto a typed exception, so a
  /// raw [PlatformException] never reaches the caller. [wrap] decides whether
  /// this is a video or an image error; `cancelled` always wins.
  Future<T> _invoke<T>(
    String method,
    Map<String, dynamic> args,
    CompressException Function(String code, String? message) wrap, {
    required CompressException Function(String? message) onCancelled,
  }) async {
    try {
      final res = await _method.invokeMethod<T>(method, args);
      if (res == null) {
        // Never synthesise a code: `'${method}_failed'` would produce strings
        // that aren't in CompressErrorCode and don't match any native code.
        throw wrap(
            CompressErrorCode.badArguments, '$method returned no result');
      }
      return res;
    } on PlatformException catch (e, stackTrace) {
      // Preserve the original stack — without this, a failure's origin in the
      // native/JS layer is lost (CLAUDE.md §3.4).
      Error.throwWithStackTrace(
        e.code == CompressErrorCode.cancelled
            ? onCancelled(e.message)
            : wrap(e.code, e.message),
        stackTrace,
      );
    }
  }

  Future<Map<dynamic, dynamic>> _invokeVideoMap(
          String method, Map<String, dynamic> args) =>
      _invoke<Map<dynamic, dynamic>>(method, args, VideoCompressException.new,
          onCancelled: VideoCompressCancelledException.new);

  @override
  Future<VideoInfo> getVideoInfo(String path) async =>
      VideoInfo.fromMap(await _invokeVideoMap('getVideoInfo', {'path': path}));

  @override
  Future<CompressionEstimate> estimate(
    String path,
    VideoCompressConfig config,
  ) async =>
      CompressionEstimate.fromMap(await _invokeVideoMap(
        'estimate',
        {'path': path, 'config': config.toMap()},
      ));

  @override
  Future<VideoCompressResult> compress(
    String id,
    String path,
    VideoCompressConfig config,
    String? outputDir,
    String? outputName,
  ) async =>
      VideoCompressResult.fromMap(await _invokeVideoMap('compress', {
        'id': id,
        'path': path,
        'config': config.toMap(),
        'outputDir': outputDir,
        'outputName': outputName,
      }));

  @override
  Future<void> cancel(String? id) =>
      _method.invokeMethod<void>('cancel', {'id': id});

  @override
  Future<bool> isCompressing() async =>
      (await _method.invokeMethod<bool>('isCompressing')) ?? false;

  @override
  Future<String> getThumbnail(
    String path, {
    required int positionMs,
    required int quality,
    int? maxWidth,
  }) =>
      _invoke<String>(
        'getThumbnail',
        {
          'path': path,
          'positionMs': positionMs,
          'quality': quality,
          'maxWidth': maxWidth,
        },
        VideoCompressException.new,
        onCancelled: VideoCompressCancelledException.new,
      );

  @override
  Future<void> clearCache() => _method.invokeMethod<void>('clearCache');

  @override
  Future<String> saveToDownloads(String path, String? fileName) =>
      _invoke<String>(
        'saveToDownloads',
        {'path': path, 'fileName': fileName},
        VideoCompressException.new,
        onCancelled: VideoCompressCancelledException.new,
      );

  // ---- images ------------------------------------------------------------

  @override
  Future<ImageMeta> getImageInfo(String path) async => ImageMeta.fromMap(
        await _invoke<Map<dynamic, dynamic>>(
          'getImageInfo',
          {'path': path},
          ImageCompressException.new,
          onCancelled: ImageCompressCancelledException.new,
        ),
      );

  @override
  Future<ImageCompressResult> compressImage(
    String path,
    ImageCompressConfig config,
    String? outputDir,
    String? outputName,
  ) async =>
      ImageCompressResult.fromMap(
        await _invoke<Map<dynamic, dynamic>>(
          'compressImage',
          {
            'path': path,
            'config': config.toMap(),
            'outputDir': outputDir,
            'outputName': outputName,
          },
          ImageCompressException.new,
          onCancelled: ImageCompressCancelledException.new,
        ),
      );
}
