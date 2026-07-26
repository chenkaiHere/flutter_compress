package com.compress.all.flutter_compress

import android.content.Context
import java.io.File

/** The plugin's private scratch directory for intermediate outputs/thumbnails. */
internal fun Context.compressCacheDir(): File =
    File(cacheDir, "flutter_compress").apply { mkdirs() }

internal fun Context.clearCompressCache() {
    compressCacheDir().listFiles()?.forEach { it.delete() }
}

/**
 * Compose the output file. The name is [outputName] (extension stripped — the
 * caller's contract is "base name only") or, when absent, the source's base
 * name plus a timestamp. [ext] (without dot) is always appended so the
 * extension matches the bytes actually written. Writes into [outputDir] when
 * it's a real writable path, otherwise the plugin cache.
 */
internal fun Context.resolveOutput(
    outputDir: String?,
    outputName: String?,
    sourcePath: String,
    ext: String,
): File {
    val base = outputName?.substringAfterLast('/')?.substringAfterLast('\\')
        ?.takeIf { it.isNotBlank() }
        ?: "${File(sourcePath).nameWithoutExtension}_${System.currentTimeMillis()}"
    val fileName = "$base.$ext"
    if (outputDir != null && outputDir.startsWith("/")) {
        val dir = File(outputDir).also { it.mkdirs() }
        if (dir.canWrite()) return File(dir, fileName)
    }
    return File(compressCacheDir(), fileName)
}
