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
 * [mimeType] is a parameter so images can reuse this later.
 */
object DownloadSaver {
    fun save(
        context: Context,
        path: String,
        fileName: String?,
        mimeType: String = "video/mp4",
    ): String {
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
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, pending)
            ?: error("Could not create Downloads entry")
        resolver.openOutputStream(uri)?.use { out -> src.inputStream().use { it.copyTo(out) } }
            ?: error("Could not open output stream")
        resolver.update(
            uri, ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) }, null, null,
        )
        return uri.toString()
    }
}
