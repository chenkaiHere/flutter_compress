import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'flutter_compress_platform_interface.dart';
import 'src/exceptions.dart';
import 'src/image_models.dart';
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

  Future<void> _ensureLoaded() => _loaded ??= _load();

  Future<void> _load() async {
    await _loadScript('${_base}mp4box.all.min.js');
    await _loadScript('${_base}mp4-muxer.js');
    await _loadScript('${_base}flutter_compress_web.js');
    if (!_jsIsSupported()) {
      throw VideoCompressException('unsupported',
          'WebCodecs / MP4 tooling not available in this browser');
    }
  }

  /// Images only need the engine file (canvas-based) — skip the heavier
  /// demux/mux libs and the WebCodecs support gate.
  Future<void> _ensureImageLoaded() =>
      _imgLoaded ??= _loadScript('${_base}flutter_compress_web.js');

  Future<void> _loadScript(String src) {
    final completer = Completer<void>();
    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.src = src;
    script.type = 'text/javascript';
    script.addEventListener(
        'load', ((web.Event _) => completer.complete()).toJS);
    script.addEventListener('error',
        ((web.Event _) => completer.completeError('failed: $src')).toJS);
    web.document.head!.appendChild(script);
    return completer.future;
  }

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
    final (tw, th) = _SizeMath.targetDimensions(srcW, srcH, config);
    final videoBps = _SizeMath.videoBitrateBps(config, durationMs, srcKbps, th);
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
      final durationMs = _clampDuration((m['durationMs'] as num).toInt(), config);
      final srcKbps = (m['bitrateKbps'] as num).toInt();
      final srcBytes = (m['sizeBytes'] as num).toInt();
      final (tw, th) = _SizeMath.targetDimensions(srcW, srcH, config);
      final videoBps =
          _SizeMath.videoBitrateBps(config, durationMs, srcKbps, th);

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
    if (id != null) _jsCancel(id);
  }

  @override
  Future<bool> isCompressing() async => _busy;

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
    await _ensureImageLoaded();
    _jsRevokeAll();
  }

  @override
  Future<void> releaseOutput(String path) async {
    await _ensureImageLoaded();
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

/// Dart port of the native SizeMath — kept in sync so web hits the same targets.
class _SizeMath {
  static const _safety = 0.95;
  static const _minBps = 100000;

  static int videoBitrateBps(
      VideoCompressConfig c, int durationMs, int srcKbps, int targetHeight) {
    final target = c.targetSizeMB;
    if (target != null) {
      final totalBits = target * 8 * 1024 * 1024;
      final durSec = (durationMs / 1000).clamp(0.001, double.infinity);
      // Web v1 drops audio, so the whole budget goes to video.
      final videoBits = totalBits * _safety;
      return (videoBits / durSec).round().clamp(_minBps, 1 << 30);
    }
    final explicit = c.videoBitrateKbps;
    if (explicit != null) return explicit * 1000;

    final percent =
        (c.qualityPercent ?? _presetPercent(c.quality)).clamp(1, 100);
    final srcBps = srcKbps * 1000;
    if (srcBps > 0) {
      return (srcBps * percent / 100).round().clamp(_minBps, srcBps);
    }
    final width = targetHeight * 16 ~/ 9;
    final baseline = width * targetHeight * 30 * 0.12;
    return (baseline * percent / 50).round().clamp(_minBps, 1 << 30);
  }

  static int _presetPercent(CompressQuality q) {
    switch (q) {
      case CompressQuality.high:
        return 80;
      case CompressQuality.medium:
        return 50;
      case CompressQuality.low:
        return 30;
      case CompressQuality.veryLow:
        return 15;
    }
  }

  static (int, int) targetDimensions(
      int srcW, int srcH, VideoCompressConfig c) {
    if (srcW <= 0 || srcH <= 0) return (srcW, srcH);
    final maxW = c.maxWidth;
    final maxH = c.maxHeight;
    // No cap requested → keep the source exactly. Aligning here would round 1080
    // *up* to 1088, breaking the "only ever scale down" promise and forcing a
    // needless full-frame rescale.
    if (maxW == null && maxH == null) return (srcW, srcH);

    final m = c.alignment == DimensionAlignment.auto16 ? 16 : 2;
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
    return (_align(w.toInt(), m), _align(h.toInt(), m));
  }

  /// Always rounds *down* so alignment can never upscale.
  static int _align(int v, int m) {
    final r = (v ~/ m) * m;
    return r < m ? m : r;
  }
}
