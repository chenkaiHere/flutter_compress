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
}
