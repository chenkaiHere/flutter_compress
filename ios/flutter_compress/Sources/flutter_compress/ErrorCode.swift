/// Channel error codes. Mirrors `lib/src/error_codes.dart` and `ErrorCode.kt` —
/// these strings are the public contract, so keep all three in sync and treat a
/// change to any value as a breaking change.
enum ErrorCode {
  static let cancelled = "cancelled"

  // Video.
  static let infoFailed = "info_failed"
  static let estimateFailed = "estimate_failed"
  static let compressFailed = "compress_failed"
  static let thumbnailFailed = "thumbnail_failed"
  static let saveFailed = "save_failed"

  // Images.
  static let imageInfoFailed = "image_info_failed"
  static let imageCompressFailed = "image_compress_failed"

  // Plumbing.
  static let badArguments = "bad_arguments"
}
