package com.compress.all.flutter_compress

import android.media.MediaMetadataRetriever
import java.io.File

/** Reads source video metadata. Kept separate so it can be reused (e.g. by a
 * future image pipeline) and unit-reasoned about on its own. */
object MediaProbe {
    fun videoInfo(path: String): Map<String, Any?> {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            return mapOf(
                "path" to path,
                "width" to r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH),
                "height" to r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT),
                "durationMs" to r.long(MediaMetadataRetriever.METADATA_KEY_DURATION),
                "sizeBytes" to File(path).length(),
                "bitrateKbps" to r.int(MediaMetadataRetriever.METADATA_KEY_BITRATE) / 1000,
                "frameRate" to r.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_CAPTURE_FRAMERATE,
                )?.toDoubleOrNull(),
                "codec" to null,
                "rotation" to r.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION),
            )
        } finally {
            r.release()
        }
    }

    private fun MediaMetadataRetriever.int(key: Int) = extractMetadata(key)?.toIntOrNull() ?: 0
    private fun MediaMetadataRetriever.long(key: Int) = extractMetadata(key)?.toLongOrNull() ?: 0L
}
