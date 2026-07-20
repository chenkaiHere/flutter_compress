package com.compress.all.flutter_compress

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import java.io.File
import java.io.FileOutputStream

/** Extracts a single JPEG thumbnail frame from a video. */
object Thumbnailer {
    fun generate(
        dir: File,
        path: String,
        positionMs: Long,
        quality: Int,
        maxWidth: Int?,
    ): String {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            var bmp = r.getFrameAtTime(positionMs * 1000)
                ?: error("Could not extract frame")
            if (maxWidth != null && bmp.width > maxWidth) {
                val h = (bmp.height * maxWidth.toFloat() / bmp.width).toInt()
                bmp = Bitmap.createScaledBitmap(bmp, maxWidth, h, true)
            }
            val out = File(dir, "thumb_${System.nanoTime()}.jpg")
            FileOutputStream(out).use { bmp.compress(Bitmap.CompressFormat.JPEG, quality, it) }
            return out.absolutePath
        } finally {
            r.release()
        }
    }
}
