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
        var bmp: Bitmap? = null
        try {
            r.setDataSource(path)
            bmp = r.getFrameAtTime(positionMs * 1000) ?: error("Could not extract frame")
            if (maxWidth != null && bmp.width > maxWidth) {
                val h = (bmp.height * maxWidth.toFloat() / bmp.width).toInt().coerceAtLeast(1)
                val scaled = Bitmap.createScaledBitmap(bmp, maxWidth, h, true)
                if (scaled !== bmp) bmp.recycle()
                bmp = scaled
            }
            val out = File(dir, "thumb_${System.nanoTime()}.jpg")
            val ok = FileOutputStream(out).use {
                bmp.compress(Bitmap.CompressFormat.JPEG, quality, it)
            }
            if (!ok) {
                out.delete()
                error("Could not encode thumbnail")
            }
            return out.absolutePath
        } finally {
            bmp?.recycle()
            r.release()
        }
    }
}
