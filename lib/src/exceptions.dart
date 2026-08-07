// Error types shared by the video and image APIs.
//
// Every failure surfaces as one of these — a raw `PlatformException` never
// escapes the plugin, so callers don't have to match on channel error strings.

/// Base type for every error this plugin throws.
///
/// Catch this to handle any failure from either API. Catch
/// [VideoCompressException] / [ImageCompressException] to tell the two apart, or
/// [VideoCompressCancelledException] for a user-initiated cancel.
class CompressException implements Exception {
  CompressException(this.code, this.message);

  /// Stable machine-readable cause, e.g. `compress_failed`, `image_info_failed`.
  final String code;

  final String? message;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// Marker for "the caller cancelled this".
///
/// Implemented by both cancel exceptions, so `on CompressCancelled` catches a
/// cancelled video *or* image job without caring which API it came from.
abstract interface class CompressCancelled {}

/// A video operation failed.
class VideoCompressException extends CompressException {
  VideoCompressException(super.code, super.message);
}

/// Thrown when a video job is cancelled — see `FlutterCompress.cancel` or a
/// `CancellationToken`.
class VideoCompressCancelledException extends VideoCompressException
    implements CompressCancelled {
  VideoCompressCancelledException([String? message])
      : super('cancelled', message ?? 'Compression was cancelled');
}

/// An image operation failed.
class ImageCompressException extends CompressException {
  ImageCompressException(super.code, super.message);
}

/// Thrown when a batch image job is cancelled via a `CancellationToken`.
class ImageCompressCancelledException extends ImageCompressException
    implements CompressCancelled {
  ImageCompressCancelledException([String? message])
      : super('cancelled', message ?? 'Compression was cancelled');
}
