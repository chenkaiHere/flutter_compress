package com.compress.all.flutter_compress

/**
 * Channel error codes. Mirrors `lib/src/error_codes.dart` and `ErrorCode.swift` —
 * these strings are the public contract, so keep all three in sync and treat a
 * change to any value as a breaking change.
 */
internal object ErrorCode {
    const val CANCELLED = "cancelled"

    // Video.
    const val INFO_FAILED = "info_failed"
    const val ESTIMATE_FAILED = "estimate_failed"
    const val COMPRESS_FAILED = "compress_failed"
    const val THUMBNAIL_FAILED = "thumbnail_failed"
    const val SAVE_FAILED = "save_failed"

    // Images.
    const val IMAGE_INFO_FAILED = "image_info_failed"
    const val IMAGE_COMPRESS_FAILED = "image_compress_failed"

    // Plumbing.
    const val NO_ENGINE = "no_engine"
    const val BAD_ARGUMENTS = "bad_arguments"
    const val UNSUPPORTED = "unsupported"
}

/** A required channel argument was absent or had the wrong type. */
internal class BadArgumentException(key: String) :
    IllegalArgumentException("Missing or invalid argument: $key")
