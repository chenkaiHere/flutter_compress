package com.compress.all.flutter_compress

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/**
 * Copies a file into the public Downloads collection. MediaStore on Android 10+
 * (no runtime permission); direct file write + WRITE_EXTERNAL_STORAGE below that.
 * The MIME type is inferred from the file name so images aren't mislabeled as
 * video (which would make the system treat a .jpg as a movie).
 */
object DownloadSaver {
    fun save(context: Context, path: String, fileName: String?): String {
        val src = File(path)
        val name = fileName ?: src.name

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            @Suppress("DEPRECATION")
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            dir.mkdirs()
            return src.copyTo(File(dir, name), overwrite = true).absolutePath
        }

        val resolver = context.contentResolver
        val pending = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mimeFor(name))
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, pending)
            ?: error("Could not create Downloads entry")
        try {
            resolver.openOutputStream(uri)?.use { out -> src.inputStream().use { it.copyTo(out) } }
                ?: error("Could not open output stream")
            resolver.update(
                uri, ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }, null, null,
            )
        } catch (e: Throwable) {
            // An entry left IS_PENDING is invisible to the user but still holds
            // disk; drop it rather than leaking an orphan.
            runCatching { resolver.delete(uri, null, null) }
            throw e
        }
        return uri.toString()
    }

    private fun mimeFor(name: String): String = when (name.substringAfterLast('.', "").lowercase()) {
        "jpg", "jpeg" -> "image/jpeg"
        "png" -> "image/png"
        "webp" -> "image/webp"
        "heic", "heif" -> "image/heic"
        "mp4", "m4v" -> "video/mp4"
        "mov" -> "video/quicktime"
        "webm" -> "video/webm"
        else -> "application/octet-stream"
    }
}

