package com.compress.all.flutter_compress

import android.content.Context
import java.io.File

/** The plugin's private scratch directory for intermediate outputs/thumbnails. */
internal fun Context.compressCacheDir(): File =
    File(cacheDir, "flutter_compress").apply { mkdirs() }

internal fun Context.clearCompressCache() {
    compressCacheDir().listFiles()?.forEach { it.delete() }
}
