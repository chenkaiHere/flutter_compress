/// The `code` values carried by every [CompressException] this plugin throws.
///
/// These strings are part of the public contract: they are what callers switch
/// on, so changing one is a breaking change. The same set is mirrored in
/// `ErrorCode.kt` (Android) and `ErrorCode.swift` (iOS) — keep all three in sync.
abstract final class CompressErrorCode {
  /// The job was cancelled by the caller. Prefer catching `CompressCancelled`.
  static const String cancelled = 'cancelled';

  // ---- video ----
  static const String infoFailed = 'info_failed';
  static const String estimateFailed = 'estimate_failed';
  static const String compressFailed = 'compress_failed';
  static const String thumbnailFailed = 'thumbnail_failed';
  static const String saveFailed = 'save_failed';

  // ---- images ----
  static const String imageInfoFailed = 'image_info_failed';
  static const String imageCompressFailed = 'image_compress_failed';

  // ---- plumbing ----
  /// A required channel argument was missing or the wrong type.
  static const String badArguments = 'bad_arguments';

  /// The native engine wasn't initialised (plugin detached from the engine).
  static const String noEngine = 'no_engine';

  /// The platform can't do this at all — e.g. a browser without WebCodecs.
  static const String unsupported = 'unsupported';
}
