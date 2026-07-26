package com.compress.all.flutter_compress

/** Parsed mirror of the Dart [ImageCompressConfig]. */
data class ImageConfig(
    /** Requested output format, or null to keep the source's. */
    val format: String?,
    val quality: Int,
    val targetSizeKB: Int?,
    val maxWidth: Int?,
    val maxHeight: Int?,
    val keepExif: Boolean,
    val lossless: Boolean,
    val keepOriginalIfLarger: Boolean,
) {
    companion object {
        fun fromMap(m: Map<String, Any?>) = ImageConfig(
            format = m["format"] as? String,
            quality = (m["quality"] as? Number)?.toInt() ?: 85,
            targetSizeKB = (m["targetSizeKB"] as? Number)?.toInt(),
            maxWidth = (m["maxWidth"] as? Number)?.toInt(),
            maxHeight = (m["maxHeight"] as? Number)?.toInt(),
            keepExif = m["keepExif"] as? Boolean ?: false,
            lossless = m["lossless"] as? Boolean ?: false,
            keepOriginalIfLarger = m["keepOriginalIfLarger"] as? Boolean ?: true,
        )
    }
}
