import 'package:flutter_compress/flutter_compress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoCompressConfig', () {
    test('serializes intent to a channel map', () {
      const config = VideoCompressConfig(
        targetSizeMB: 10,
        codec: VideoCodec.h265,
        maxWidth: 1280,
        removeAudio: true,
        trim: TrimRange(startMs: 1000, endMs: 5000),
      );
      final map = config.toMap();
      expect(map['targetSizeMB'], 10);
      expect(map['codec'], 'h265');
      expect(map['maxWidth'], 1280);
      expect(map['removeAudio'], true);
      expect(map['trim'], {'startMs': 1000, 'endMs': 5000});
      expect(map['alignment'], 'auto16');
      expect(map['keepOriginalIfLarger'], true);
      expect(map['container'], 'auto');
    });

    test('defaults are sensible', () {
      const config = VideoCompressConfig();
      final map = config.toMap();
      expect(map['quality'], 'medium');
      expect(map['codec'], 'h265');
      expect(map['targetSizeMB'], isNull);
      expect(map['container'], 'auto');
    });

    test('container can be forced to mp4', () {
      expect(
        const VideoCompressConfig(container: VideoContainer.mp4)
            .toMap()['container'],
        'mp4',
      );
    });
  });

  group('VideoCompressResult', () {
    test('computes savings from sizes', () {
      final result = VideoCompressResult.fromMap({
        'id': 'j1',
        'outputPath': '/tmp/out.mp4',
        'originalSizeBytes': 1000,
        'compressedSizeBytes': 250,
        'width': 640,
        'height': 360,
        'durationMs': 5000,
        'codec': 'h265',
        'skipped': false,
      });
      expect(result.compressionRatio, 0.25);
      expect(result.savedPercent, 75);
    });
  });

  test('CompressionProgress parses partial payloads', () {
    final p = CompressionProgress.fromMap({'id': 'j1', 'progress': 0.5});
    expect(p.id, 'j1');
    expect(p.progress, 0.5);
    expect(p.estimatedRemainingMs, isNull);
  });

  // ---- images (separate API) --------------------------------------------

  group('ImageCompressConfig', () {
    test('serializes intent to a channel map', () {
      const config = ImageCompressConfig(
        format: ImageFormat.webp,
        targetSizeKB: 200,
        maxWidth: 1920,
        keepExif: true,
      );
      final map = config.toMap();
      expect(map['format'], 'webp');
      expect(map['targetSizeKB'], 200);
      expect(map['maxWidth'], 1920);
      expect(map['keepExif'], true);
    });

    test('defaults are sensible', () {
      const config = ImageCompressConfig();
      final map = config.toMap();
      // Null format = keep the source's format.
      expect(map['format'], isNull);
      expect(map['quality'], 85);
      expect(map['targetSizeKB'], isNull);
      expect(map['keepExif'], false);
      expect(map['lossless'], false);
      expect(map['keepOriginalIfLarger'], true);
    });

    test('carries the lossless flag', () {
      const config = ImageCompressConfig(format: ImageFormat.png, lossless: true);
      final map = config.toMap();
      expect(map['lossless'], true);
      expect(map['format'], 'png');
    });

    test('keepOriginalIfLarger defaults on and serializes', () {
      expect(const ImageCompressConfig().keepOriginalIfLarger, true);
      expect(const ImageCompressConfig().toMap()['keepOriginalIfLarger'], true);
      expect(
        const ImageCompressConfig(keepOriginalIfLarger: false)
            .toMap()['keepOriginalIfLarger'],
        false,
      );
    });

    test('result exposes the skipped flag', () {
      final skipped = ImageCompressResult.fromMap({
        'outputPath': '/tmp/a.jpg',
        'originalSizeBytes': 1000,
        'compressedSizeBytes': 1000,
        'width': 10,
        'height': 10,
        'format': 'jpeg',
        'skipped': true,
      });
      expect(skipped.skipped, true);
      // Missing key defaults to false.
      final normal = ImageCompressResult.fromMap({
        'outputPath': '/tmp/a.jpg',
        'originalSizeBytes': 1000,
        'compressedSizeBytes': 500,
        'width': 10,
        'height': 10,
        'format': 'jpeg',
      });
      expect(normal.skipped, false);
    });

    test('rejects out-of-range quality', () {
      expect(() => ImageCompressConfig(quality: 0), throwsA(isA<AssertionError>()));
      expect(
          () => ImageCompressConfig(quality: 101), throwsA(isA<AssertionError>()));
    });
  });

  group('ImageCompressResult', () {
    test('computes savings from sizes', () {
      final r = ImageCompressResult.fromMap({
        'outputPath': '/tmp/out.jpg',
        'originalSizeBytes': 1000,
        'compressedSizeBytes': 200,
        'width': 800,
        'height': 600,
        'format': 'jpeg',
      });
      expect(r.compressionRatio, 0.2);
      expect(r.savedPercent, 80);
      expect(r.format, 'jpeg');
    });
  });

  test('ImageMeta parses a channel map', () {
    final m = ImageMeta.fromMap({
      'path': '/tmp/a.png',
      'width': 1200,
      'height': 800,
      'sizeBytes': 345678,
      'format': 'png',
    });
    expect(m.width, 1200);
    expect(m.height, 800);
    expect(m.format, 'png');
  });
}
