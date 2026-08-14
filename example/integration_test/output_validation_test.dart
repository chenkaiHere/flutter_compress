// Output validation on a real device (CLAUDE.md §12.4).
//
// This is the layer that was missing when a muxer misconfiguration truncated
// every video to 30 seconds: it compiled, unit tests passed, analysis was clean,
// and all three platform builds were green — because nothing ever looked at the
// *output*. Asserting duration, dimensions and re-decodability is what catches
// that entire class of bug.
//
// Run on a device or simulator:
//   cd example && flutter test integration_test/output_validation_test.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_compress/flutter_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// §12.4's tolerance: the output may differ slightly from the source because of
/// keyframe placement and container rounding, but not materially.
const _durationTolerance = 0.05; // 5%

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final api = FlutterCompress.instance;
  late String sourcePath;
  late VideoInfo source;

  setUpAll(() async {
    sourcePath = await _materializeSampleVideo();
    source = await api.getVideoInfo(sourcePath);
    // A fixture that fails these makes every assertion below meaningless.
    expect(
      source.durationMs,
      greaterThan(1000),
      reason: 'fixture must be longer than a second to detect truncation',
    );
    expect(source.width, greaterThan(0));
  });

  tearDownAll(() async => api.clearCache());

  group('video output is valid', () {
    test('duration is preserved within 5%', () async {
      final result = await api.compress(
        sourcePath,
        const VideoCompressConfig(targetSizeMB: 2),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));

      // The regression this exists for: a 2-minute source came back as 30s.
      final drift =
          (result.durationMs - source.durationMs).abs() / source.durationMs;
      expect(
        drift,
        lessThan(_durationTolerance),
        reason:
            'output ${result.durationMs}ms vs source ${source.durationMs}ms '
            '— a large shortfall means the encode was truncated, not compressed',
      );
    });

    test('the file on disk can be decoded again', () async {
      final result = await api.compress(
        sourcePath,
        const VideoCompressConfig(quality: CompressQuality.low),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));

      // Probing the output is the cheapest proof that we wrote a valid container
      // rather than a plausible-looking pile of bytes.
      final reread = await api.getVideoInfo(result.outputPath);
      expect(reread.width, greaterThan(0));
      expect(reread.height, greaterThan(0));
      expect(reread.durationMs, greaterThan(0));
    });

    test('reported size matches the bytes actually written', () async {
      final result = await api.compress(
        sourcePath,
        const VideoCompressConfig(quality: CompressQuality.medium),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));

      final onDisk = await File(result.outputPath).length();
      expect(result.compressedSizeBytes, onDisk);
    });

    test('a resolution cap is respected and never upscales', () async {
      const cap = 640;
      final result = await api.compress(
        sourcePath,
        const VideoCompressConfig(maxWidth: cap, maxHeight: cap),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));

      final reread = await api.getVideoInfo(result.outputPath);
      expect(math.max(reread.width, reread.height), lessThanOrEqualTo(cap));
      // Regression: ÷16 alignment used to round 1080 *up* to 1088.
      expect(reread.width, lessThanOrEqualTo(source.width));
      expect(reread.height, lessThanOrEqualTo(source.height));
    });

    test('a target size lands in the right ballpark', () async {
      const targetMB = 2;
      final result = await api.compress(
        sourcePath,
        const VideoCompressConfig(targetSizeMB: targetMB),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));
      if (result.skipped) return; // source was already smaller

      final actualMB = result.compressedSizeBytes / 1024 / 1024;
      // Deliberately loose: hardware rate control varies by device. The point is
      // to catch order-of-magnitude misses, which is what a wrong duration or an
      // ignored bitrate produces.
      expect(
        actualMB,
        lessThan(targetMB * 2.0),
        reason: 'overshot the target by more than 2x',
      );
      expect(
        actualMB,
        greaterThan(targetMB * 0.25),
        reason:
            'undershot by more than 4x — usually a truncated output or an '
            'encoder ignoring the requested bitrate',
      );
    });

    test('progress reaches completion and never goes backwards', () async {
      final seen = <double>[];
      final result = await api.compress(
        sourcePath,
        const VideoCompressConfig(quality: CompressQuality.low),
        onProgress: (p) => seen.add(p.progress),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));

      expect(seen, isNotEmpty, reason: 'no progress events arrived');
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
    });
  });

  group('cancellation completes the future', () {
    test('cancelling mid-encode throws instead of hanging', () async {
      final token = CancellationToken();
      final pending = api.compress(
        sourcePath,
        const VideoCompressConfig(targetSizeMB: 1),
        cancellationToken: token,
      );
      // Regression: Transformer.cancel() never calls the listener, so nothing
      // completed the future and the caller waited forever.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await token.cancel();

      await expectLater(
        pending.timeout(const Duration(seconds: 20)),
        throwsA(isA<CompressCancelled>()),
      );
    });
  });

  group('image output is valid', () {
    test('a target size is met and the format follows the source', () async {
      final png = await _materializeSamplePng();
      final result = await api.compressImage(
        png,
        const ImageCompressConfig(targetSizeKB: 40),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));

      expect(result.format, 'png', reason: 'no format requested → keep source');
      final reread = await api.getImageInfo(result.outputPath);
      expect(reread.width, greaterThan(0));
      expect(reread.height, greaterThan(0));
      if (!result.skipped) {
        expect(
          result.compressedSizeBytes,
          await File(result.outputPath).length(),
        );
      }
    });

    test('never returns something larger than the source', () async {
      final png = await _materializeSamplePng();
      final srcBytes = await File(png).length();
      final result = await api.compressImage(
        png,
        // Lossless on an already-compact PNG is the classic "grows the file" case.
        const ImageCompressConfig(lossless: true),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));
      expect(result.compressedSizeBytes, lessThanOrEqualTo(srcBytes));
    });
  });
}

/// Copies the bundled sample video out of the asset bundle onto disk, where the
/// native engines can open it by path.
///
/// The fixture is **not** in the repo — a checked-in video would bloat the
/// package. Drop a short clip (a few seconds, ideally >1080p so the resolution
/// cap has something to do) at `example/assets/sample.mp4`, declare it under
/// `flutter: assets:` in example/pubspec.yaml, and this suite runs.
Future<String> _materializeSampleVideo() async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/sample.mp4');
  if (!file.existsSync()) {
    final data = await rootBundle.load('assets/sample.mp4');
    await file.writeAsBytes(data.buffer.asUint8List());
  }
  return file.path;
}

/// A 64x64 PNG written from bytes, so the image suite needs no fixture at all.
Future<String> _materializeSamplePng() async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/sample.png');
  if (!file.existsSync()) {
    final image = await _solidPng(64, 64);
    await file.writeAsBytes(image);
  }
  return file.path;
}

/// Encode a solid-colour PNG via dart:ui — avoids shipping a binary fixture.
Future<Uint8List> _solidPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // A gradient rather than a flat fill: a single colour compresses to almost
  // nothing, which makes size assertions meaningless.
  final paint = Paint()
    ..shader = ui.Gradient.linear(
      Offset.zero,
      Offset(width.toDouble(), height.toDouble()),
      const [Color(0xFFE33322), Color(0xFF3366CC)],
    );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
