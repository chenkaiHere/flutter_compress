import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'flutter_compress_platform_interface.dart';
import 'src/error_codes.dart';
import 'src/exceptions.dart';
import 'src/image_models.dart';
import 'src/size_math.dart';
import 'src/models.dart';

// ---- JS bindings to assets/flutter_compress_web.js -----------------------

@JS('flutterCompressWeb.isSupported')
external bool _jsIsSupported();

@JS('flutterCompressWeb.getInfo')
external JSPromise<JSObject> _jsGetInfo(String url);

@JS('flutterCompressWeb.thumbnail')
external JSPromise<JSString> _jsThumbnail(
    String url, int positionMs, int quality, int maxWidth);

@JS('flutterCompressWeb.compress')
external JSPromise<JSObject> _jsCompress(
    String url, JSObject cfg, JSFunction onProgress);

@JS('flutterCompressWeb.cancel')
external void _jsCancel(String id);

@JS('flutterCompressWeb.cancelAll')
external void _jsCancelAll();

@JS('flutterCompressWeb.download')
external JSPromise<JSString> _jsDownload(String url, String? fileName);

@JS('flutterCompressWeb.revoke')
external void _jsRevoke(String url);

@JS('flutterCompressWeb.revokeAll')
external void _jsRevokeAll();

@JS('flutterCompressWeb.getImageInfo')
external JSPromise<JSObject> _jsGetImageInfo(String url);

@JS('flutterCompressWeb.compressImage')
external JSPromise<JSObject> _jsCompressImage(String url, JSObject cfg);

/// Web implementation backed by WebCodecs (VideoDecoder/VideoEncoder) with
/// mp4box.js demuxing and mp4-muxer muxing — the browser-native parallel to
/// Media3 (Android) and AVFoundation (iOS). No FFmpeg.
///
/// v1 transcodes video only (audio is dropped); trim is not yet applied on web.
class FlutterCompressWeb extends FlutterCompressPlatform {
  static void registerWith(Registrar registrar) {
    FlutterCompressPlatform.instance = FlutterCompressWeb();
  }

  final _progressCtrl = StreamController<CompressionProgress>.broadcast();
  Future<void>? _loaded;
  bool _busy = false;

  @override
  Stream<CompressionProgress> get progressStream => _progressCtrl.stream;

  // ---- script loading ----------------------------------------------------

  static const _base = 'assets/packages/flutter_compress/assets/';
  Future<void>? _imgLoaded;

  Future<void> _ensureLoaded() async {
    // Don't cache a failed load: one transient network error would otherwise
    // disable video for the rest of the session.
    final pending = _loaded ??= _load();
    try {
      await pending;
    } catch (_) {
      if (identical(_loaded, pending)) _loaded = null;
      rethrow;
    }
  }

  /// True once `flutter_compress_web.js` has actually run, i.e. the
  /// `flutterCompressWeb` namespace exists. A pending `_loaded` future is not
  /// enough — calling into the namespace before then throws.
  bool _engineReady = false;

  Future<void> _loadEngine() async {
    await _loadScript('${_base}flutter_compress_web.js');
    _engineReady = true;
  }

  Future<void> _load() async {
    await _loadScript('${_base}mp4box.all.min.js');
    await _loadScript('${_base}mp4-muxer.js');
    await _loadEngine();
    if (!_jsIsSupported()) {
      throw VideoCompressException(CompressErrorCode.unsupported,
          'WebCodecs / MP4 tooling not available in this browser');
    }
  }

  /// Images only need the engine file (canvas-based) — skip the heavier
  /// demux/mux libs and the WebCodecs support gate.
  Future<void> _ensureImageLoaded() async {
    final pending = _imgLoaded ??= _loadEngine();
    try {
      await pending;
    } catch (_) {
      if (identical(_imgLoaded, pending)) _imgLoaded = null;
      rethrow;
    }
  }

  /// Tracks in-flight//completed script loads by URL. Both lazy loaders pull in
  /// `flutter_compress_web.js`; without this the second one appends a duplicate
  /// `<script>` (the engine guards against re-running, but the fetch is waste).
  static final Map<String, Future<void>> _scripts = {};

  Future<void> _loadScript(String src) => _scripts.putIfAbsent(src, () {
        final completer = Completer<void>();
        final script =
            web.document.createElement('script') as web.HTMLScriptElement;
        script.src = src;
        script.type = 'text/javascript';
        script.addEventListener(
            'load', ((web.Event _) => completer.complete()).toJS);
        script.addEventListener(
            'error',
            ((web.Event _) => completer.completeError(VideoCompressException(
                CompressErrorCode.unsupported, 'Could not load $src'))).toJS);
        web.document.head!.appendChild(script);
        return completer.future.catchError((Object e) {
          // Let a retry re-attempt the fetch rather than replaying the failure.
          _scripts.remove(src);
          throw e;
        });
      });

  // ---- info / estimate ---------------------------------------------------

  Future<Map<dynamic, dynamic>> _rawInfo(String url) async {
    await _ensureLoaded();
    final obj = await _jsGetInfo(url).toDart;
    return (obj.dartify() as Map).cast<dynamic, dynamic>();
  }

  @override
  Future<VideoInfo> getVideoInfo(String path) async {
    final m = await _rawInfo(path);
    m['path'] = path;
    return VideoInfo.fromMap(m);
  }

  @override
  Future<CompressionEstimate> estimate(
      String path, VideoCompressConfig config) async {
    final m = await _rawInfo(path);
    final srcW = (m['width'] as num).toInt();
    final srcH = (m['height'] as num).toInt();
    final durationMs = _clampDuration((m['durationMs'] as num).toInt(), config);
    final srcKbps = (m['bitrateKbps'] as num).toInt();
    final (tw, th) = SizeMath.targetDimensions(srcW, srcH, config);
    final videoBps = SizeMath.videoBitrateBps(
      config: config,
      durationMs: durationMs,
      sourceBitrateKbps: srcKbps,
      targetHeight: th,
      // Web v1 drops the audio track, so the whole budget goes to video.
      reserveAudio: false,
    );
    final bytes = (videoBps * (durationMs / 1000) / 8).round();
    return CompressionEstimate.fromMap({
      'estimatedSizeBytes': bytes,
      'estimatedBitrateKbps': videoBps ~/ 1000,
      'targetWidth': tw,
      'targetHeight': th,
    });
  }

  // ---- compress ----------------------------------------------------------

  @override
  Future<VideoCompressResult> compress(
    String id,
    String path,
    VideoCompressConfig config,
    String? outputDir,
    String? outputName,
  ) async {
    // On the web there is no filesystem: the output is a blob: URL and the
    // download name is chosen at saveToDownloads time, so outputDir/outputName
    // don't apply here. Video is always mp4 (mp4-muxer).
    await _ensureLoaded();
    _busy = true;
    try {
      final m = await _rawInfo(path);
      final srcW = (m['width'] as num).toInt();
      final srcH = (m['height'] as num).toInt();
      // Use the same duration `estimate` does, so the two agree. (Web doesn't
      // apply the trim window yet, but the bitrate budget must still match.)
      final durationMs =
          _clampDuration((m['durationMs'] as num).toInt(), config);
      final srcKbps = (m['bitrateKbps'] as num).toInt();
      final srcBytes = (m['sizeBytes'] as num).toInt();
      final (tw, th) = SizeMath.targetDimensions(srcW, srcH, config);
      final videoBps = SizeMath.videoBitrateBps(
        config: config,
        durationMs: durationMs,
        sourceBitrateKbps: srcKbps,
        targetHeight: th,
        // Web v1 drops the audio track, so the whole budget goes to video.
        reserveAudio: false,
      );

      final cfg = <String, Object?>{
        'id': id,
        'targetWidth': tw,
        'targetHeight': th,
        'videoBitrateBps': videoBps,
        'frameRate': config.frameRate ?? 30,
        // Requested codec; the JS engine encodes HEVC when the browser supports
        // it, otherwise falls back to H.264 (and reports which was used).
        'codec': config.codec.name,
        // Hit the target closely when a size is requested; stay efficient (VBR)
        // for quality/bitrate modes.
        'bitrateMode': config.targetSizeMB != null ? 'constant' : 'variable',
        'keepOriginalIfLarger': config.keepOriginalIfLarger,
        'originalSizeBytes': srcBytes,
      }.jsify()! as JSObject;

      final onProgress = (double fraction, double outBytes) {
        _progressCtrl.add(CompressionProgress(
          id: id,
          progress: fraction,
          currentOutputBytes: outBytes > 0 ? outBytes.toInt() : null,
        ));
      }.toJS;

      final resJs = await _jsCompress(path, cfg, onProgress).toDart;
      final r = (resJs.dartify() as Map).cast<dynamic, dynamic>();
      return VideoCompressResult(
        id: id,
        outputPath: r['outputUrl'] as String,
        originalSizeBytes: srcBytes,
        compressedSizeBytes: (r['sizeBytes'] as num).toInt(),
        width: (r['width'] as num).toInt(),
        height: (r['height'] as num).toInt(),
        durationMs: (r['durationMs'] as num).toInt(),
        codec: r['codec'] as String,
        skipped: r['skipped'] == true,
        frameRate: (r['frameRate'] as num?)?.toDouble(),
        hasAudio: r['hasAudio'] as bool?,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled')) {
        throw VideoCompressCancelledException();
      }
      throw VideoCompressException('compress_failed', msg);
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> cancel(String? id) async {
    // Nothing is loaded until the first compress, so a cancel before that has
    // nothing to target — and touching the JS namespace would throw.
    if (!_engineReady) return;
    if (id != null) {
      _jsCancel(id);
    } else {
      _jsCancelAll();
    }
  }

  @override
  Future<bool> isCompressing() async => _busy;

  @override
  Future<bool> isSupported() async {
    try {
      await _ensureLoaded();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> getThumbnail(
    String path, {
    required int positionMs,
    required int quality,
    int? maxWidth,
  }) async {
    await _ensureLoaded();
    final res =
        await _jsThumbnail(path, positionMs, quality, maxWidth ?? 0).toDart;
    return res.toDart; // a data: URL
  }

  @override
  Future<void> clearCache() async {
    // Outputs are blob: URLs, which the browser keeps alive for the whole page
    // unless revoked. Release every URL this engine handed out.
    //
    // If the engine never loaded it never minted a URL, so there is nothing to
    // free — don't fetch the script just to iterate an empty set.
    if (!_engineReady) return;
    _jsRevokeAll();
  }

  @override
  Future<void> releaseOutput(String path) async {
    if (!_engineReady) return;
    _jsRevoke(path);
  }

  @override
  Future<String> saveToDownloads(String path, String? fileName) async {
    await _ensureImageLoaded(); // only needs the engine's download() helper
    // Never default to .mp4 — this method is shared with the image API, and a
    // JPEG saved as "compressed.mp4" is worse than a generic name. The JS side
    // derives the extension from the blob's MIME type when we pass null.
    return (await _jsDownload(path, fileName).toDart).toDart;
  }

  // ---- images ------------------------------------------------------------

  @override
  Future<ImageMeta> getImageInfo(String path) async {
    await _ensureImageLoaded();
    try {
      final m = (await _jsGetImageInfo(path).toDart).dartify() as Map;
      return ImageMeta.fromMap(m.cast<dynamic, dynamic>());
    } catch (e) {
      throw ImageCompressException('image_info_failed', e.toString());
    }
  }

  @override
  Future<ImageCompressResult> compressImage(
    String path,
    ImageCompressConfig config,
    String? outputDir,
    String? outputName,
  ) async {
    // Web output is a blob: URL; outputDir/outputName don't apply. A null
    // config.format tells the JS engine to keep the source's format.
    await _ensureImageLoaded();
    try {
      final cfg = config.toMap().jsify()! as JSObject;
      final res = (await _jsCompressImage(path, cfg).toDart).dartify() as Map;
      return ImageCompressResult.fromMap(res.cast<dynamic, dynamic>());
    } catch (e) {
      throw ImageCompressException('image_compress_failed', e.toString());
    }
  }

  int _clampDuration(int full, VideoCompressConfig c) {
    final t = c.trim;
    return t != null ? (t.endMs - t.startMs) : full;
  }
}
