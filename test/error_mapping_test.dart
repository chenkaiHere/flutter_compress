// The channel -> typed-exception boundary (CLAUDE.md §3.4).
//
// This layer had no coverage at all, and it is exactly where cross-language
// mistakes hide: a raw PlatformException escaping, a cancel surfacing as the
// wrong type, or a synthesised error code that no platform actually sends.

import 'package:flutter/services.dart';
import 'package:flutter_compress/flutter_compress.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter_compress/methods');

/// Make the platform channel answer [handler] for every call; null clears it.
void _stub(Future<Object?>? Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
}

/// Reply with a PlatformException carrying [code].
void _stubError(String code, {String message = 'boom'}) =>
    _stub((_) async => throw PlatformException(code: code, message: message));

/// Reply with null, which every typed call must reject rather than crash on.
void _stubNull() => _stub((_) async => null);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = FlutterCompress.instance;

  tearDown(() => _stub(null));

  group('video errors are typed', () {
    test('a platform failure becomes VideoCompressException with its code', () {
      _stubError(CompressErrorCode.infoFailed);
      expect(
        () => api.getVideoInfo('a.mp4'),
        throwsA(isA<VideoCompressException>()
            .having((e) => e.code, 'code', CompressErrorCode.infoFailed)
            .having((e) => e.message, 'message', 'boom')),
      );
    });

    test('cancelled becomes VideoCompressCancelledException', () {
      _stubError(CompressErrorCode.cancelled);
      expect(
        () => api.compress('a.mp4', const VideoCompressConfig()),
        throwsA(isA<VideoCompressCancelledException>()),
      );
    });

    test('a cancel is catchable as CompressCancelled', () {
      _stubError(CompressErrorCode.cancelled);
      expect(
        () => api.estimate('a.mp4', const VideoCompressConfig()),
        throwsA(isA<CompressCancelled>()),
      );
    });

    test('estimate, thumbnail and saveToDownloads are all wrapped', () async {
      for (final code in [
        CompressErrorCode.estimateFailed,
        CompressErrorCode.thumbnailFailed,
        CompressErrorCode.saveFailed,
      ]) {
        _stubError(code);
        await expectLater(
          switch (code) {
            CompressErrorCode.estimateFailed =>
              api.estimate('a.mp4', const VideoCompressConfig()),
            CompressErrorCode.thumbnailFailed => api.getThumbnail('a.mp4'),
            _ => api.saveToDownloads('a.mp4'),
          },
          throwsA(isA<VideoCompressException>()
              .having((e) => e.code, 'code', code)),
        );
      }
    });
  });

  group('image errors are typed separately', () {
    test('a platform failure becomes ImageCompressException', () {
      _stubError(CompressErrorCode.imageCompressFailed);
      expect(
        () => api.compressImage('a.jpg', const ImageCompressConfig()),
        throwsA(isA<ImageCompressException>().having(
            (e) => e.code, 'code', CompressErrorCode.imageCompressFailed)),
      );
    });

    test('an image cancel raises the image cancel type, not the video one', () {
      // Regression: the shared cancel branch always threw the Video variant, so
      // `on ImageCompressCancelledException` could never match.
      _stubError(CompressErrorCode.cancelled);
      expect(
        () => api.compressImage('a.jpg', const ImageCompressConfig()),
        throwsA(isA<ImageCompressCancelledException>()),
      );
    });

    test('getImageInfo failures are image-typed', () {
      _stubError(CompressErrorCode.imageInfoFailed);
      expect(
        () => api.getImageInfo('a.jpg'),
        throwsA(isA<ImageCompressException>()),
      );
    });
  });

  group('no raw PlatformException escapes', () {
    test('an unknown code is still wrapped, not passed through', () {
      _stubError('something_the_dart_side_never_heard_of');
      expect(
        () => api.getVideoInfo('a.mp4'),
        throwsA(
            allOf(isA<CompressException>(), isNot(isA<PlatformException>()))),
      );
    });
  });

  group('a null reply is rejected, not crashed on', () {
    test('video calls throw a typed error instead of a null-check failure', () {
      _stubNull();
      expect(
        () => api.getVideoInfo('a.mp4'),
        throwsA(isA<VideoCompressException>()),
      );
    });

    test('image calls likewise', () {
      _stubNull();
      expect(
        () => api.getImageInfo('a.jpg'),
        throwsA(isA<ImageCompressException>()),
      );
    });

    test('the synthesised code is a real CompressErrorCode value', () {
      // Regression: this used to build '${method}_failed', producing codes like
      // `getVideoInfo_failed` that appear in no platform and no constant.
      _stubNull();
      expect(
        () => api.getVideoInfo('a.mp4'),
        throwsA(isA<CompressException>().having(
          (e) => e.code,
          'code',
          CompressErrorCode.badArguments,
        )),
      );
    });
  });

  group('success paths decode correctly', () {
    test('getVideoInfo maps a channel reply onto VideoInfo', () async {
      _stub((_) async => {
            'path': 'a.mp4',
            'width': 1080,
            'height': 1920,
            'durationMs': 5000,
            'sizeBytes': 1024,
            'bitrateKbps': 8000,
          });
      final info = await api.getVideoInfo('a.mp4');
      expect(info.width, 1080);
      expect(info.height, 1920);
      expect(info.durationMs, 5000);
    });

    test('isCompressing defaults to false when the platform says nothing',
        () async {
      _stubNull();
      expect(await api.isCompressing(), isFalse);
    });

    test('cancel and cancelAll reach the channel with the right argument',
        () async {
      final seen = <String, Object?>{};
      _stub((call) async {
        seen[call.method] = (call.arguments as Map)['id'];
        return null;
      });
      await api.cancel('job_1');
      expect(seen['cancel'], 'job_1');
      await api.cancelAll();
      expect(seen['cancel'], isNull);
    });
  });
}
