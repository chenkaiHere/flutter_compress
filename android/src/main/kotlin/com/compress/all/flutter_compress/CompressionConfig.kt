package com.compress.all.flutter_compress

/** Parsed mirror of the Dart [VideoCompressConfig]. */
data class CompressionConfig(
    val quality: String,
    val qualityPercent: Int?,
    val targetSizeMB: Int?,
    val videoBitrateKbps: Int?,
    val codec: String,
    val maxWidth: Int?,
    val maxHeight: Int?,
    val frameRate: Double?,
    val removeAudio: Boolean,
    val audioBitrateKbps: Int?,
    val trimStartMs: Long?,
    val trimEndMs: Long?,
    val alignment: String,
    val keepOriginalIfLarger: Boolean,
) {
    companion object {
        fun fromMap(m: Map<String, Any?>): CompressionConfig {
            @Suppress("UNCHECKED_CAST")
            val trim = m["trim"] as? Map<String, Any?>
            return CompressionConfig(
                quality = m["quality"] as? String ?: "medium",
                qualityPercent = (m["qualityPercent"] as? Number)?.toInt(),
                targetSizeMB = (m["targetSizeMB"] as? Number)?.toInt(),
                videoBitrateKbps = (m["videoBitrateKbps"] as? Number)?.toInt(),
                codec = m["codec"] as? String ?: "h265",
                maxWidth = (m["maxWidth"] as? Number)?.toInt(),
                maxHeight = (m["maxHeight"] as? Number)?.toInt(),
                frameRate = (m["frameRate"] as? Number)?.toDouble(),
                removeAudio = m["removeAudio"] as? Boolean ?: false,
                audioBitrateKbps = (m["audioBitrateKbps"] as? Number)?.toInt(),
                trimStartMs = (trim?.get("startMs") as? Number)?.toLong(),
                trimEndMs = (trim?.get("endMs") as? Number)?.toLong(),
                alignment = m["alignment"] as? String ?: "auto16",
                keepOriginalIfLarger = m["keepOriginalIfLarger"] as? Boolean ?: true,
            )
        }
    }
}

/** Thrown when a job is cancelled. */
class CompressionCancelledException(message: String = "Compression cancelled") :
    Exception(message)
