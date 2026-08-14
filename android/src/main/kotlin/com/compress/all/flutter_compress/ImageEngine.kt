package com.compress.all.flutter_compress

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Build
import android.util.Log
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Native image compression via the Android imaging stack (BitmapFactory +
 * Bitmap.compress). No FFmpeg, no Dart software decode. For a target size it
 * searches the quality (and downscales if needed) — images encode in
 * milliseconds, so this lands accurately at/under the target.
 *
 * Runs on a background dispatcher (see `FlutterCompressPlugin.dispatch`); every
 * intermediate bitmap is recycled so batches don't accumulate native heap.
 */
class ImageEngine(private val context: Context) {

    fun info(path: String): Map<String, Any?> {
        val src = probe(path)
        return mapOf(
            "path" to path,
            "width" to src.width,
            "height" to src.height,
            "sizeBytes" to File(path).length(),
            "format" to src.format,
        )
    }

    fun compress(
        path: String,
        config: ImageConfig,
        outputDir: String?,
        outputName: String?,
    ): Map<String, Any?> {
        val originalSize = File(path).length()
        val src = probe(path)

        // A null format keeps the source's format.
        val effective = resolveFormat(config.format ?: src.format)
        // PNG is inherently lossless; lossless mode also disables quality search.
        val lossy = !config.lossless && (effective == "jpeg" || effective == "webp")
        // A target size can't be honored losslessly — ignore it in that case.
        val targetBytes = if (config.lossless) null else config.targetSizeKB?.let { it * 1024 }

        var bmp = decodeUpright(path, src, config.maxWidth, config.maxHeight)
        try {
            val bytes: ByteArray
            if (targetBytes == null) {
                bytes = encode(bmp, effective, if (lossy) config.quality else MAX_QUALITY, config.lossless)
            } else {
                var fit = fitToTarget(bmp, effective, lossy, targetBytes, MIN_QUALITY)
                var tries = 0
                while (fit.bytes.size > targetBytes && tries < MAX_DOWNSCALES && bmp.width > MIN_SIDE) {
                    bmp = bmp.scaledTo(bmp.width * 3 / 4, bmp.height * 3 / 4)
                    // A smaller image fits at least the quality the last round
                    // reached, so the search can start from there.
                    fit = fitToTarget(bmp, effective, lossy, targetBytes, fit.quality)
                    tries++
                }
                bytes = fit.bytes
            }

            // Re-encoding can end up larger than the source (already-compressed
            // input, or lossless). If so, hand back the untouched original.
            if (config.keepOriginalIfLarger && bytes.size >= originalSize) {
                return mapOf(
                    "outputPath" to path,
                    "originalSizeBytes" to originalSize,
                    "compressedSizeBytes" to originalSize,
                    "width" to src.width,
                    "height" to src.height,
                    "format" to src.format,
                    "skipped" to true,
                )
            }

            val out = context.resolveOutput(outputDir, outputName, path, ext(effective))
            out.writeBytes(bytes)
            // EXIF is appended after the size search, so it can add a few hundred
            // bytes on top of targetSizeKB; the size reported below is the real one.
            if (config.keepExif && effective == "jpeg") copyExif(path, out.absolutePath)

            return mapOf(
                "outputPath" to out.absolutePath,
                "originalSizeBytes" to originalSize,
                "compressedSizeBytes" to out.length(),
                "width" to bmp.width,
                "height" to bmp.height,
                "format" to effective,
                "skipped" to false,
            )
        } finally {
            bmp.recycle()
        }
    }

    // ---- source inspection -------------------------------------------------

    /** Source dimensions (already oriented), format and raw EXIF orientation. */
    private class Probe(
        val width: Int,
        val height: Int,
        val format: String,
        val orientation: Int,
    )

    /**
     * One bounds-only decode for everything we need up front. Dimensions are
     * reported **oriented** (a portrait photo stored as landscape + rotate-90
     * reads as portrait), matching what the user sees.
     */
    private fun probe(path: String): Probe {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, opts)
        if (opts.outWidth <= 0 || opts.outHeight <= 0) error("Could not read image: $path")
        val orientation = runCatching {
            ExifInterface(path)
                .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
        val swap = orientation == ExifInterface.ORIENTATION_ROTATE_90 ||
            orientation == ExifInterface.ORIENTATION_ROTATE_270 ||
            orientation == ExifInterface.ORIENTATION_TRANSPOSE ||
            orientation == ExifInterface.ORIENTATION_TRANSVERSE
        val format = when (opts.outMimeType?.removePrefix("image/")?.lowercase()) {
            "png" -> "png"
            "webp" -> "webp"
            "heic", "heif" -> "heic"
            else -> "jpeg"
        }
        return Probe(
            width = if (swap) opts.outHeight else opts.outWidth,
            height = if (swap) opts.outWidth else opts.outHeight,
            format = format,
            orientation = orientation,
        )
    }

    /**
     * The format actually encoded. The request is always kept — JPEG stays JPEG,
     * PNG stays PNG, WebP stays WebP — except HEIC, which Android's Bitmap stack
     * can't encode, so it falls back to JPEG. (JPEG has no lossless mode; in
     * lossless mode it is simply encoded at maximum quality.)
     */
    private fun resolveFormat(requested: String): String =
        if (requested == "heic") "jpeg" else requested

    // ---- decode ------------------------------------------------------------

    /**
     * Memory-safe decode: `inSampleSize` for a coarse downscale, then bake in the
     * EXIF orientation, then scale to the exact target. Orientation is applied
     * unconditionally so output is upright even when `keepExif` is off.
     */
    private fun decodeUpright(path: String, src: Probe, maxW: Int?, maxH: Int?): Bitmap {
        val (tw, th) = targetDimensions(src.width, src.height, maxW, maxH)
        var sample = 1
        while (src.width / (sample * 2) >= tw && src.height / (sample * 2) >= th) sample *= 2
        var bmp = BitmapFactory.decodeFile(
            path, BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: error("Could not decode image: $path")
        bmp = bmp.oriented(src.orientation)
        return if (bmp.width != tw || bmp.height != th) bmp.scaledTo(tw, th) else bmp
    }

    private fun targetDimensions(w: Int, h: Int, maxW: Int?, maxH: Int?): Pair<Int, Int> {
        var fw = w.toDouble()
        var fh = h.toDouble()
        if (maxW != null && fw > maxW) { val s = maxW / fw; fw *= s; fh *= s }
        if (maxH != null && fh > maxH) { val s = maxH / fh; fw *= s; fh *= s }
        return fw.toInt().coerceAtLeast(1) to fh.toInt().coerceAtLeast(1)
    }

    /** Scale to [w]x[h], recycling the receiver. */
    private fun Bitmap.scaledTo(w: Int, h: Int): Bitmap {
        val out = Bitmap.createScaledBitmap(this, w, h, true)
        if (out !== this) recycle()
        return out
    }

    /** Bake an EXIF [orientation] into the pixels, recycling the receiver. */
    private fun Bitmap.oriented(orientation: Int): Bitmap {
        val m = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> m.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> m.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> m.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> m.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> m.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { m.postRotate(90f); m.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_TRANSVERSE -> { m.postRotate(270f); m.postScale(-1f, 1f) }
            else -> return this
        }
        val out = Bitmap.createBitmap(this, 0, 0, width, height, m, true)
        if (out !== this) recycle()
        return out
    }

    // ---- encode ------------------------------------------------------------

    private class Encoded(val bytes: ByteArray, val quality: Int)

    /**
     * The highest-quality encode that fits [target].
     *
     * Tries the ceiling first: an image that already fits costs a **single**
     * encode instead of a full binary search. Otherwise binary-searches
     * `[minQuality, MAX_QUALITY)`. If even [minQuality] overflows, the oversized
     * result comes back so the caller can downscale and retry.
     */
    private fun fitToTarget(
        bmp: Bitmap,
        format: String,
        lossy: Boolean,
        target: Int,
        minQuality: Int,
    ): Encoded {
        if (!lossy) return Encoded(encode(bmp, format, MAX_QUALITY, lossless = false), MAX_QUALITY)

        val ceiling = encode(bmp, format, MAX_QUALITY, lossless = false)
        if (ceiling.size <= target) return Encoded(ceiling, MAX_QUALITY)

        var lo = minQuality
        var hi = MAX_QUALITY - 1
        var best: ByteArray? = null
        var bestQuality = minQuality
        while (lo <= hi) {
            val q = (lo + hi) / 2
            val bytes = encode(bmp, format, q, lossless = false)
            if (bytes.size <= target) {
                best = bytes
                bestQuality = q
                lo = q + 1
            } else {
                hi = q - 1
            }
        }
        return Encoded(
            best ?: encode(bmp, format, minQuality, lossless = false),
            bestQuality,
        )
    }

    private fun encode(bmp: Bitmap, format: String, quality: Int, lossless: Boolean): ByteArray {
        val bos = ByteArrayOutputStream()
        bmp.compress(compressFormat(format, lossless), quality, bos)
        return bos.toByteArray()
    }

    @Suppress("DEPRECATION")
    private fun compressFormat(format: String, lossless: Boolean): Bitmap.CompressFormat = when (format) {
        "png" -> Bitmap.CompressFormat.PNG
        "webp" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (lossless) Bitmap.CompressFormat.WEBP_LOSSLESS else Bitmap.CompressFormat.WEBP_LOSSY
        } else {
            Bitmap.CompressFormat.WEBP
        }
        else -> Bitmap.CompressFormat.JPEG
    }

    private fun ext(format: String) = when (format) {
        "png" -> "png"; "webp" -> "webp"; else -> "jpg"
    }

    /**
     * Copy the common EXIF tags into the JPEG output. Orientation is reset to
     * normal because the rotation is already baked into the pixels — copying the
     * source tag would rotate the image a second time.
     */
    private fun copyExif(src: String, dst: String) {
        runCatching {
            val from = ExifInterface(src)
            val to = ExifInterface(dst)
            for (tag in EXIF_TAGS) from.getAttribute(tag)?.let { to.setAttribute(tag, it) }
            to.setAttribute(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL.toString(),
            )
            to.saveAttributes()
        }.onFailure {
            // Best-effort by design — a photo without its EXIF is still a valid
            // result, so this must not fail the compression. But swallowing it
            // silently left `keepExif: true` looking like it worked, with no way
            // to tell why the metadata vanished.
            Log.w(TAG, "keepExif: could not copy EXIF from $src", it)
        }
    }

    private companion object {
        const val TAG = "FlutterCompress"
        const val MIN_QUALITY = 1
        const val MAX_QUALITY = 100
        const val MAX_DOWNSCALES = 5
        const val MIN_SIDE = 32

        val EXIF_TAGS = listOf(
            ExifInterface.TAG_DATETIME,
            ExifInterface.TAG_MAKE,
            ExifInterface.TAG_MODEL,
            ExifInterface.TAG_GPS_LATITUDE,
            ExifInterface.TAG_GPS_LATITUDE_REF,
            ExifInterface.TAG_GPS_LONGITUDE,
            ExifInterface.TAG_GPS_LONGITUDE_REF,
        )
    }
}
