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
 * Pick a safe destination: [outputPath] only when it's a real writable
 * filesystem path, otherwise the plugin cache with [fallbackName].
 */
internal fun Context.resolveOutput(outputPath: String?, fallbackName: String): File {
    val fallback = File(compressCacheDir(), fallbackName)
    if (outputPath == null || !outputPath.startsWith("/")) return fallback
    val target = File(outputPath).also { it.parentFile?.mkdirs() }
    return if (target.parentFile?.canWrite() == true) target else fallback
}
