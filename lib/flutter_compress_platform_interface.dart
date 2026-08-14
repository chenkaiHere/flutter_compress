import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_compress_method_channel.dart';
import 'src/image_models.dart';
import 'src/models.dart';

/// The interface that platform implementations of flutter_compress implement.
///
/// Kept federated-style so an alternate implementation (e.g. a future macOS or
/// desktop backend) can be swapped in without touching the app-facing API.
abstract class FlutterCompressPlatform extends PlatformInterface {
  FlutterCompressPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterCompressPlatform _instance = MethodChannelFlutterCompress();

  static FlutterCompressPlatform get instance => _instance;

  static set instance(FlutterCompressPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Broadcast stream of progress events for all in-flight jobs.
  Stream<CompressionProgress> get progressStream =>
      throw UnimplementedError('progressStream has not been implemented.');

  Future<VideoInfo> getVideoInfo(String path) =>
      throw UnimplementedError('getVideoInfo() has not been implemented.');

  Future<CompressionEstimate> estimate(
    String path,
    VideoCompressConfig config,
  ) =>
      throw UnimplementedError('estimate() has not been implemented.');

  /// Compress [path] using [config]. [id] identifies the job (for progress
  /// correlation and cancellation). When [outputPath] is non-null the encoded
  /// file is written there; otherwise it lands in the plugin cache.
  Future<VideoCompressResult> compress(
    String id,
    String path,
    VideoCompressConfig config,
    String? outputDir,
    String? outputName,
  ) =>
      throw UnimplementedError('compress() has not been implemented.');

  Future<void> cancel(String? id) =>
      throw UnimplementedError('cancel() has not been implemented.');

  Future<bool> isCompressing() =>
      throw UnimplementedError('isCompressing() has not been implemented.');

  Future<String> getThumbnail(
    String path, {
    required int positionMs,
    required int quality,
    int? maxWidth,
  }) =>
      throw UnimplementedError('getThumbnail() has not been implemented.');

  /// Whether this platform can compress video at all. Always true on native;
  /// on web it reports WebCodecs + demux/mux availability.
  Future<bool> isSupported() async => true;

  Future<void> clearCache() =>
      throw UnimplementedError('clearCache() has not been implemented.');

  /// Release a single output. No-op on native (files live until [clearCache]);
  /// on web it revokes the blob: URL so the browser can free the bytes.
  Future<void> releaseOutput(String path) async {}

  Future<String> saveToDownloads(String path, String? fileName) =>
      throw UnimplementedError('saveToDownloads() has not been implemented.');

  // ---- images (separate from the video API above) -----------------------

  Future<ImageMeta> getImageInfo(String path) =>
      throw UnimplementedError('getImageInfo() has not been implemented.');

  Future<ImageCompressResult> compressImage(
    String path,
    ImageCompressConfig config,
    String? outputDir,
    String? outputName,
  ) =>
      throw UnimplementedError('compressImage() has not been implemented.');
}
