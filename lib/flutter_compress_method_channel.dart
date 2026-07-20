import 'package:flutter/services.dart';

import 'flutter_compress_platform_interface.dart';
import 'src/models.dart';

/// MethodChannel + EventChannel implementation of [FlutterCompressPlatform].
///
/// Channel keys are centralized in [_Keys] so the Dart and native sides have a
/// single source of truth. (If this plugin grows, these hand-written maps are
/// the natural point to migrate to Pigeon for compile-time-checked messages.)
class MethodChannelFlutterCompress extends FlutterCompressPlatform {
  final MethodChannel _method =
      const MethodChannel('flutter_compress/methods');
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

  @override
  Future<VideoInfo> getVideoInfo(String path) async {
    final res = await _method.invokeMethod<Map<dynamic, dynamic>>(
      'getVideoInfo',
      {'path': path},
    );
    return VideoInfo.fromMap(res!);
  }

  @override
  Future<CompressionEstimate> estimate(
    String path,
    VideoCompressConfig config,
  ) async {
    final res = await _method.invokeMethod<Map<dynamic, dynamic>>(
      'estimate',
      {'path': path, 'config': config.toMap()},
    );
    return CompressionEstimate.fromMap(res!);
  }

  @override
  Future<VideoCompressResult> compress(
    String id,
    String path,
    VideoCompressConfig config,
    String? outputPath,
  ) async {
    try {
      final res = await _method.invokeMethod<Map<dynamic, dynamic>>(
        'compress',
        {
          'id': id,
          'path': path,
          'config': config.toMap(),
          'outputPath': outputPath,
        },
      );
      return VideoCompressResult.fromMap(res!);
    } on PlatformException catch (e) {
      if (e.code == 'cancelled') {
        throw VideoCompressCancelledException(e.message);
      }
      throw VideoCompressException(e.code, e.message);
    }
  }

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
  }) async {
    final res = await _method.invokeMethod<String>('getThumbnail', {
      'path': path,
      'positionMs': positionMs,
      'quality': quality,
      'maxWidth': maxWidth,
    });
    return res!;
  }

  @override
  Future<void> clearCache() => _method.invokeMethod<void>('clearCache');

  @override
  Future<String> saveToDownloads(String path, String? fileName) async {
    final res = await _method.invokeMethod<String>('saveToDownloads', {
      'path': path,
      'fileName': fileName,
    });
    return res!;
  }
}
