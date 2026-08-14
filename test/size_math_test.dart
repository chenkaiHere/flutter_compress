// Boundary coverage for the shared size/bitrate math (CLAUDE.md §12.2).
//
// This is the algorithm all three platforms implement; a regression here is a
// regression everywhere, so the edges matter more than the happy path.

import 'package:flutter_compress/flutter_compress.dart';
import 'package:flutter_test/flutter_test.dart';

/// 60s at 24fps — a realistic clip length for the target-size arithmetic.
const _durationMs = 60000;

int _bitrate(
  VideoCompressConfig config, {
  int durationMs = _durationMs,
  int sourceBitrateKbps = 9000,
  int targetHeight = 1080,
  bool reserveAudio = true,
}) =>
    SizeMath.videoBitrateBps(
      config: config,
      durationMs: durationMs,
      sourceBitrateKbps: sourceBitrateKbps,
      targetHeight: targetHeight,
      reserveAudio: reserveAudio,
    );

void main() {
  group('videoBitrateBps priority chain', () {
    test('targetSizeMB wins over every other control', () {
      final bps = _bitrate(const VideoCompressConfig(
        targetSizeMB: 10,
        videoBitrateKbps: 99999,
        qualityPercent: 10,
        quality: CompressQuality.veryLow,
      ));
      // 10 MiB × 8 × 0.95 − 128kbps×60s, over 60s.
      const expected = (10 * 8 * 1024 * 1024 * 0.95 - 128000 * 60) / 60;
      expect(bps, expected.toInt());
    });

    test('videoBitrateKbps wins over quality controls', () {
      expect(
        _bitrate(const VideoCompressConfig(
          videoBitrateKbps: 2500,
          qualityPercent: 10,
        )),
        2500 * 1000,
      );
    });

    test('qualityPercent wins over the preset tier', () {
      // 25% of a 9000 kbps source, not the 80% that `high` would give.
      expect(
        _bitrate(const VideoCompressConfig(
          qualityPercent: 25,
          quality: CompressQuality.high,
        )),
        9000 * 1000 * 25 ~/ 100,
      );
    });

    test('preset tiers map to their documented percentages', () {
      const srcKbps = 10000;
      int forTier(CompressQuality q) => _bitrate(
            VideoCompressConfig(quality: q),
            sourceBitrateKbps: srcKbps,
          );
      expect(forTier(CompressQuality.high), srcKbps * 1000 * 80 ~/ 100);
      expect(forTier(CompressQuality.medium), srcKbps * 1000 * 50 ~/ 100);
      expect(forTier(CompressQuality.low), srcKbps * 1000 * 30 ~/ 100);
      expect(forTier(CompressQuality.veryLow), srcKbps * 1000 * 15 ~/ 100);
    });
  });

  group('videoBitrateBps edges', () {
    test('never re-inflates above the source bitrate', () {
      // percent caps at 100, so the result can only ever be <= source.
      final bps = _bitrate(
        const VideoCompressConfig(qualityPercent: 100),
        sourceBitrateKbps: 4000,
      );
      expect(bps, lessThanOrEqualTo(4000 * 1000));
    });

    test('a source bitrate below the floor does not throw', () {
      // Regression: a clamp(floor, srcBps) here had lower > upper and threw
      // ArgumentError for any source under 100 kbps.
      expect(
        () => _bitrate(
          const VideoCompressConfig(quality: CompressQuality.medium),
          sourceBitrateKbps: 50,
        ),
        returnsNormally,
      );
      expect(
        _bitrate(
          const VideoCompressConfig(quality: CompressQuality.medium),
          sourceBitrateKbps: 50,
        ),
        SizeMath.minVideoBps,
      );
    });

    test('an absurdly small target size still clears the floor', () {
      expect(
        _bitrate(const VideoCompressConfig(targetSizeMB: 1),
            durationMs: 3600000),
        SizeMath.minVideoBps,
      );
    });

    test('a zero-length source does not divide by zero', () {
      expect(
        () => _bitrate(const VideoCompressConfig(targetSizeMB: 10),
            durationMs: 0),
        returnsNormally,
      );
    });

    test('unknown source bitrate falls back to a resolution baseline', () {
      final bps = _bitrate(
        const VideoCompressConfig(quality: CompressQuality.medium),
        sourceBitrateKbps: 0,
        targetHeight: 720,
      );
      // 1280x720 baseline at the "medium" anchor.
      const width = 720 * 16 ~/ 9;
      expect(bps, (width * 720 * 30 * 0.12).toInt());
    });

    test('removeAudio hands the whole target budget to video', () {
      final withAudio = _bitrate(const VideoCompressConfig(targetSizeMB: 10));
      final without = _bitrate(
          const VideoCompressConfig(targetSizeMB: 10, removeAudio: true));
      expect(without, greaterThan(withAudio));
    });

    test('reserveAudio:false matches removeAudio (the web pipeline)', () {
      final web = _bitrate(const VideoCompressConfig(targetSizeMB: 10),
          reserveAudio: false);
      final native = _bitrate(
          const VideoCompressConfig(targetSizeMB: 10, removeAudio: true));
      expect(web, native);
    });

    test('a custom audio bitrate changes the video budget', () {
      final low = _bitrate(
          const VideoCompressConfig(targetSizeMB: 10, audioBitrateKbps: 64));
      final high = _bitrate(
          const VideoCompressConfig(targetSizeMB: 10, audioBitrateKbps: 256));
      expect(low, greaterThan(high));
    });
  });

  group('targetDimensions', () {
    test('no cap keeps the source exactly, without aligning', () {
      // Regression: auto16 used to round 1080 *up* to 1088, which both broke
      // "downscale only" and forced a needless full-frame rescale.
      expect(
        SizeMath.targetDimensions(1080, 2160, const VideoCompressConfig()),
        (1080, 2160),
      );
    });

    test('alignment never rounds up', () {
      // 1000 -> 992 (÷16), never 1008.
      final (w, _) = SizeMath.targetDimensions(
          2000, 1000, const VideoCompressConfig(maxWidth: 1000));
      expect(w, lessThanOrEqualTo(1000));
      expect(w % 16, 0);
    });

    test('caps each axis independently, preserving aspect', () {
      final (w, h) = SizeMath.targetDimensions(
        4000,
        2000,
        const VideoCompressConfig(
            maxWidth: 1920, alignment: DimensionAlignment.none),
      );
      expect(w, lessThanOrEqualTo(1920));
      // 2:1 source stays 2:1.
      expect((w / h - 2).abs(), lessThan(0.05));
    });

    test('only ever scales down — a cap above the source is a no-op', () {
      expect(
        SizeMath.targetDimensions(640, 480,
            const VideoCompressConfig(maxWidth: 4000, maxHeight: 4000)),
        (640, 480),
      );
    });

    test('alignment none still yields even dimensions', () {
      final (w, h) = SizeMath.targetDimensions(
        1001,
        667,
        const VideoCompressConfig(
            maxWidth: 1000, alignment: DimensionAlignment.none),
      );
      expect(w.isEven, isTrue);
      expect(h.isEven, isTrue);
    });

    test('degenerate source dimensions pass through instead of throwing', () {
      expect(
          SizeMath.targetDimensions(0, 0, const VideoCompressConfig()), (0, 0));
      expect(
        SizeMath.targetDimensions(
            -1, -1, const VideoCompressConfig(maxWidth: 100)),
        (-1, -1),
      );
    });

    test('never returns a zero side for a tiny cap', () {
      final (w, h) = SizeMath.targetDimensions(
          1920, 1080, const VideoCompressConfig(maxWidth: 8));
      expect(w, greaterThan(0));
      expect(h, greaterThan(0));
    });
  });
}
