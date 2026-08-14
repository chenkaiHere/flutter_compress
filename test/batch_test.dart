// Batch semantics against a fake platform (CLAUDE.md §8.1 "Dart 桥接测").
//
// The platform interface is abstract, so the whole facade can be exercised
// without a device: ordering, cancellation, progress and per-item error
// tolerance are all pure Dart decisions made in flutter_compress.dart.

import 'package:flutter_compress/flutter_compress.dart';
import 'package:flutter_compress/flutter_compress_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records calls and fails whichever paths the test asks it to.
class _FakePlatform extends FlutterCompressPlatform {
  _FakePlatform({this.failOn = const {}});

  /// Source paths that should throw instead of succeeding.
  final Set<String> failOn;

  final List<String> videoCalls = [];
  final List<String> imageCalls = [];
  final List<String> released = [];

  @override
  Future<VideoCompressResult> compress(
    String id,
    String path,
    VideoCompressConfig config,
    String? outputDir,
    String? outputName,
  ) async {
    videoCalls.add(path);
    if (failOn.contains(path)) {
      throw VideoCompressException(CompressErrorCode.compressFailed, path);
    }
    return VideoCompressResult.fromMap({
      'id': id,
      'outputPath': '$path.out.mp4',
      'originalSizeBytes': 1000,
      'compressedSizeBytes': 400,
      'width': 640,
      'height': 360,
      'durationMs': 1000,
      'codec': 'h265',
      'skipped': false,
    });
  }

  @override
  Future<ImageCompressResult> compressImage(
    String path,
    ImageCompressConfig config,
    String? outputDir,
    String? outputName,
  ) async {
    imageCalls.add(path);
    if (failOn.contains(path)) {
      throw ImageCompressException(CompressErrorCode.imageCompressFailed, path);
    }
    return ImageCompressResult.fromMap({
      'outputPath': '$path.out.jpg',
      'originalSizeBytes': 1000,
      'compressedSizeBytes': 300,
      'width': 100,
      'height': 100,
      'format': 'jpeg',
    });
  }

  @override
  Future<void> releaseOutput(String path) async => released.add(path);

  @override
  Future<void> cancel(String? id) async {}
}

/// Install [p] as the active platform for the test.
void _use(_FakePlatform p) => FlutterCompressPlatform.instance = p;

void main() {
  final api = FlutterCompress.instance;

  group('compressAll', () {
    test('processes every path in order', () async {
      final fake = _FakePlatform();
      _use(fake);
      final out = await api.compressAll(
          ['a.mp4', 'b.mp4', 'c.mp4'], const VideoCompressConfig());
      expect(fake.videoCalls, ['a.mp4', 'b.mp4', 'c.mp4']);
      expect(out, hasLength(3));
    });

    test('without continueOnError the first failure aborts', () async {
      final fake = _FakePlatform(failOn: {'b.mp4'});
      _use(fake);
      await expectLater(
        api.compressAll(
            ['a.mp4', 'b.mp4', 'c.mp4'], const VideoCompressConfig()),
        throwsA(isA<VideoCompressException>()),
      );
      // 'c' never ran — this is the data-loss behaviour continueOnError fixes.
      expect(fake.videoCalls, ['a.mp4', 'b.mp4']);
    });

    test('continueOnError keeps going and reports the failure', () async {
      final fake = _FakePlatform(failOn: {'b.mp4'});
      _use(fake);
      final errors = <String>[];
      final out = await api.compressAll(
        ['a.mp4', 'b.mp4', 'c.mp4'],
        const VideoCompressConfig(),
        continueOnError: true,
        onItemError: (i, path, e) => errors.add('$i:$path'),
      );
      expect(fake.videoCalls, ['a.mp4', 'b.mp4', 'c.mp4']);
      expect(out, hasLength(2)); // the failed item is omitted
      expect(errors, ['1:b.mp4']);
    });

    test('a cancel aborts the batch even with continueOnError', () async {
      _use(_FakePlatform());
      final token = CancellationToken();
      await token.cancel();
      await expectLater(
        api.compressAll(['a.mp4'], const VideoCompressConfig(),
            continueOnError: true, cancellationToken: token),
        throwsA(isA<CompressCancelled>()),
      );
    });

    test('an already-cancelled token stops before any work', () async {
      final fake = _FakePlatform();
      _use(fake);
      final token = CancellationToken();
      await token.cancel();
      await expectLater(
        api.compressAll(['a.mp4', 'b.mp4'], const VideoCompressConfig(),
            cancellationToken: token),
        throwsA(isA<VideoCompressCancelledException>()),
      );
      expect(fake.videoCalls, isEmpty);
    });
  });

  group('compressImages', () {
    test('reports per-item completion with a running total', () async {
      _use(_FakePlatform());
      final seen = <String>[];
      await api.compressImages(
        ['a.jpg', 'b.jpg', 'c.jpg'],
        const ImageCompressConfig(),
        onItemDone: (i, total) => seen.add('$i/$total'),
      );
      expect(seen, ['0/3', '1/3', '2/3']);
    });

    test('continueOnError omits the failure and keeps the rest', () async {
      final fake = _FakePlatform(failOn: {'a.jpg'});
      _use(fake);
      final errors = <int>[];
      final out = await api.compressImages(
        ['a.jpg', 'b.jpg'],
        const ImageCompressConfig(),
        continueOnError: true,
        onItemError: (i, path, e) => errors.add(i),
      );
      expect(out, hasLength(1));
      expect(errors, [0]);
      expect(fake.imageCalls, ['a.jpg', 'b.jpg']);
    });

    test('without continueOnError it rethrows the image error type', () async {
      _use(_FakePlatform(failOn: {'a.jpg'}));
      await expectLater(
        api.compressImages(['a.jpg'], const ImageCompressConfig()),
        throwsA(isA<ImageCompressException>()),
      );
    });

    test('a cancelled token raises the image cancel type', () async {
      final fake = _FakePlatform();
      _use(fake);
      final token = CancellationToken();
      await token.cancel();
      await expectLater(
        api.compressImages(['a.jpg'], const ImageCompressConfig(),
            cancellationToken: token),
        throwsA(isA<ImageCompressCancelledException>()),
      );
      expect(fake.imageCalls, isEmpty);
    });
  });

  group('lossless convenience wrapper', () {
    test('sets lossless and leaves format to the source', () async {
      ImageCompressConfig? captured;
      final fake = _CapturingPlatform((c) => captured = c);
      _use(fake);
      await api.compressImageLossless('a.png');
      expect(captured!.lossless, isTrue);
      expect(captured!.format, isNull);
    });
  });

  group('releaseOutput', () {
    test('forwards the path to the platform', () async {
      final fake = _FakePlatform();
      _use(fake);
      await api.releaseOutput('blob:abc');
      expect(fake.released, ['blob:abc']);
    });
  });
}

/// Captures the config an image call receives.
class _CapturingPlatform extends _FakePlatform {
  _CapturingPlatform(this.onConfig);
  final void Function(ImageCompressConfig) onConfig;

  @override
  Future<ImageCompressResult> compressImage(
    String path,
    ImageCompressConfig config,
    String? outputDir,
    String? outputName,
  ) {
    onConfig(config);
    return super.compressImage(path, config, outputDir, outputName);
  }
}
