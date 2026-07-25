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
    });

    test('defaults are sensible', () {
      const config = VideoCompressConfig();
      final map = config.toMap();
      expect(map['quality'], 'medium');
      expect(map['codec'], 'h265');
      expect(map['targetSizeMB'], isNull);
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
      expect(map['format'], 'jpeg');
      expect(map['quality'], 85);
      expect(map['targetSizeKB'], isNull);
      expect(map['keepExif'], false);
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
