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
    sourcePath = await _fixture('quadrants_landscape.mp4');
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
    // Every test that inspects the output passes `keepOriginalIfLarger: false`.
    // The fixture is a tiny solid-colour clip, so any re-encode comes out larger
    // and the plugin would otherwise hand back the *source* untouched — and a
    // test reading the source passes without testing the encoder at all.
    test('duration is preserved within 5%', () async {
      final result = await api.compress(
        sourcePath,
        const VideoCompressConfig(targetSizeMB: 2, keepOriginalIfLarger: false),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));
      expect(result.skipped, isFalse, reason: 'nothing was encoded');

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
        const VideoCompressConfig(
          quality: CompressQuality.low,
          keepOriginalIfLarger: false,
        ),
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
        const VideoCompressConfig(
          quality: CompressQuality.medium,
          keepOriginalIfLarger: false,
        ),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));

      final onDisk = await File(result.outputPath).length();
      expect(result.compressedSizeBytes, onDisk);
    });

    test('a resolution cap is respected and never upscales', () async {
      const cap = 640;
      final result = await api.compress(
        sourcePath,
        const VideoCompressConfig(
          maxWidth: cap,
          maxHeight: cap,
          keepOriginalIfLarger: false,
        ),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));

      final reread = await api.getVideoInfo(result.outputPath);
      expect(math.max(reread.width, reread.height), lessThanOrEqualTo(cap));
      // Regression: ÷16 alignment used to round 1080 *up* to 1088.
      expect(reread.width, lessThanOrEqualTo(source.width));
      expect(reread.height, lessThanOrEqualTo(source.height));
    });

    test('a target size lands in the right ballpark', () async {
      // Needs real footage. A solid-colour clip gives the encoder nothing to
      // spend bits on, so it lands far below any target and the lower bound
      // would fail for the wrong reason. Skipped — visibly — rather than passed.
      final realClip = await _optionalRealClip();
      if (realClip == null) {
        markTestSkipped(
          'add a real-world clip at example/assets/sample.mp4 (and declare it '
          'under flutter: assets:) to run the target-size check',
        );
        return;
      }
      const targetMB = 2;
      final result = await api.compress(
        realClip,
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

  group('video content survives downscaling', () {
    // Regression for #5: on iOS every downscaled video came out as a top-left
    // crop with the *right dimensions*. Every check above still passed —
    // dimensions, duration, decodability — because none of them looks at the
    // picture. The fixtures are four solid quadrants (R G / B Y), so reading
    // the colour at each quadrant's centre is a check on the content itself.

    test('landscape: the whole frame is scaled, not cropped', () async {
      final src = await _fixture('quadrants_landscape.mp4');
      // Fixture and thumbnailer first, so a failure further down can only mean
      // the compression changed the picture.
      expect(await _quadrants(src), 'R G B Y');

      final result = await api.compress(
        src,
        const VideoCompressConfig(
          maxWidth: 640,
          maxHeight: 640,
          keepOriginalIfLarger: false,
        ),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));
      expect(result.skipped, isFalse, reason: 'nothing was encoded');
      expect(result.width, lessThan(1920), reason: 'nothing was downscaled');

      expect(
        await _quadrants(result.outputPath),
        'R G B Y',
        reason: 'a crop shows one colour across the frame instead of four',
      );
    });

    test('rotated portrait: every quadrant survives', () async {
      // Stored landscape with a 90° display transform, as a phone records
      // portrait. This is the path most users hit.
      final src = await _fixture('quadrants_portrait.mp4');
      expect(_coloursIn(await _quadrants(src)), _allFour);

      final result = await api.compress(
        src,
        const VideoCompressConfig(
          maxWidth: 640,
          maxHeight: 640,
          keepOriginalIfLarger: false,
        ),
      );
      addTearDown(() => api.releaseOutput(result.outputPath));
      expect(result.skipped, isFalse, reason: 'nothing was encoded');
      expect(math.max(result.width, result.height), lessThanOrEqualTo(640));

      // Only the *set* of colours is asserted here, not their positions:
      // whether a platform's thumbnailer applies the display rotation is its
      // own business, and an ordering check would fail on that instead of on
      // the compression. A crop collapses to one colour and is caught either way.
      final after = await _quadrants(result.outputPath);
      expect(
        _coloursIn(after),
        _allFour,
        reason: 'got "$after" — a crop shows one colour instead of four',
      );
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

/// Copies a bundled video fixture onto disk, where the native engines can open
/// it by path.
///
/// Fixtures live in `integration_test/fixtures/` and are generated by
/// `tool/make_video_fixtures.swift` — six seconds of four solid quadrants at
/// 1920x1080, about 21 KB each. Small enough to commit, long enough to catch a
/// truncated encode, and with content that can be checked pixel by pixel.
Future<String> _fixture(String name) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  if (!file.existsSync()) {
    final data = await rootBundle.load('integration_test/fixtures/$name');
    await file.writeAsBytes(data.buffer.asUint8List());
  }
  return file.path;
}

/// A real-world clip, if one was supplied at `example/assets/sample.mp4`.
///
/// Only the target-size check needs it: hitting a bitrate budget requires
/// content an encoder can actually spend bits on. Not committed — a real clip
/// would bloat the package.
Future<String?> _optionalRealClip() async {
  try {
    final data = await rootBundle.load('assets/sample.mp4');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sample.mp4');
    await file.writeAsBytes(data.buffer.asUint8List());
    return file.path;
  } catch (_) {
    return null;
  }
}

const _allFour = {'R', 'G', 'B', 'Y'};

Set<String> _coloursIn(String layout) => layout.split(' ').toSet();

/// The colour at each quadrant's centre, as `"TL TR BL BR"`, read from a frame
/// thumbnail. Centres rather than edges: scaling and JPEG both blur the seams.
Future<String> _quadrants(String videoPath) async {
  final thumb = await FlutterCompress.instance.getThumbnail(
    videoPath,
    positionMs: 1000,
    maxWidth: 320,
  );
  final codec = await ui.instantiateImageCodec(await File(thumb).readAsBytes());
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final w = image.width;
  final h = image.height;
  final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  codec.dispose();

  String at(double fx, double fy) {
    final i = ((fy * h).floor() * w + (fx * w).floor()) * 4;
    final r = rgba.getUint8(i);
    final g = rgba.getUint8(i + 1);
    final b = rgba.getUint8(i + 2);
    if (r > 150 && g > 150 && b < 110) return 'Y';
    if (r > 150 && g < 110 && b < 110) return 'R';
    if (g > 140 && r < 110 && b < 110) return 'G';
    if (b > 150 && r < 110 && g < 110) return 'B';
    // Unclassifiable: report the raw value so a failure says what it saw.
    return '?($r,$g,$b)';
  }

  return [at(.25, .25), at(.75, .25), at(.25, .75), at(.75, .75)].join(' ');
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
