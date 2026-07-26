package com.compress.all.flutter_compress

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.os.Build
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Native image compression via the Android imaging stack (BitmapFactory +
 * Bitmap.compress). No FFmpeg, no Dart software decode. For a target size it
 * binary-searches the quality (and downscales if needed) — images encode in
 * milliseconds, so this lands accurately at/under the target.
 */
class ImageEngine(private val context: Context) {

    fun info(path: String): Map<String, Any?> {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, opts)
        return mapOf(
            "path" to path,
            "width" to opts.outWidth,
            "height" to opts.outHeight,
            "sizeBytes" to File(path).length(),
            "format" to (opts.outMimeType?.removePrefix("image/")),
        )
    }

    fun compress(
        path: String,
        config: ImageConfig,
        outputDir: String?,
        outputName: String?,
    ): Map<String, Any?> {
        val originalSize = File(path).length()
        var bmp = decodeScaled(path, config.maxWidth, config.maxHeight)

        // A null format keeps the source's format.
        val effective = resolveFormat(config.format ?: sourceFormat(path))
        // PNG is inherently lossless; lossless mode also disables quality search.
        val lossy = !config.lossless && (effective == "jpeg" || effective == "webp")

        // A target size can't be honored losslessly — ignore it in that case.
        val targetBytes = if (config.lossless) null else config.targetSizeKB?.let { it * 1024 }
        var bytes: ByteArray
        if (targetBytes == null) {
            bytes = encode(bmp, effective, if (lossy) config.quality else 100, config.lossless)
        } else {
            // Fit to target: search quality (lossy), then downscale if still over.
            bytes = fitToTarget(bmp, effective, lossy, targetBytes)
            var tries = 0
            while (bytes.size > targetBytes && tries < 5 && bmp.width > 32) {
                bmp = Bitmap.createScaledBitmap(bmp, bmp.width * 3 / 4, bmp.height * 3 / 4, true)
                bytes = fitToTarget(bmp, effective, lossy, targetBytes)
                tries++
            }
        }

        // Re-encoding can end up larger than the source (already-compressed
        // input, or lossless). If so, hand back the untouched original.
        if (config.keepOriginalIfLarger && bytes.size >= originalSize) {
            val src = info(path)
            return mapOf(
                "outputPath" to path,
                "originalSizeBytes" to originalSize,
                "compressedSizeBytes" to originalSize,
                "width" to (src["width"] ?: bmp.width),
                "height" to (src["height"] ?: bmp.height),
                "format" to (src["format"] ?: effective),
                "skipped" to true,
            )
        }

        val out = context.resolveOutput(outputDir, outputName, path, ext(effective))
        out.writeBytes(bytes)
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
    }

    /**
     * The format actually encoded. The request is always kept — JPEG stays JPEG,
     * PNG stays PNG, WebP stays WebP — except HEIC, which Android's Bitmap stack
     * can't encode, so it falls back to JPEG. (JPEG has no lossless mode; in
     * lossless mode it is simply encoded at maximum quality.)
     */
    private fun resolveFormat(requested: String): String =
        if (requested == "heic") "jpeg" else requested

    /** Detect the source image's format (used when no format is requested). */
    private fun sourceFormat(path: String): String {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, opts)
        return when (opts.outMimeType?.removePrefix("image/")?.lowercase()) {
            "png" -> "png"
            "webp" -> "webp"
            "heic", "heif" -> "heic"
            else -> "jpeg"
        }
    }

    // ---- helpers -----------------------------------------------------------

    /** Memory-safe decode: `inSampleSize` for coarse downscale, then exact scale. */
    private fun decodeScaled(path: String, maxW: Int?, maxH: Int?): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        val srcW = bounds.outWidth
        val srcH = bounds.outHeight
        val (tw, th) = targetDimensions(srcW, srcH, maxW, maxH)

        var sample = 1
        while (srcW / (sample * 2) >= tw && srcH / (sample * 2) >= th) sample *= 2
        val bmp = BitmapFactory.decodeFile(
            path, BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: error("Could not decode image")
        return if (bmp.width != tw || bmp.height != th) {
            Bitmap.createScaledBitmap(bmp, tw, th, true)
        } else {
            bmp
        }
    }

    private fun targetDimensions(w: Int, h: Int, maxW: Int?, maxH: Int?): Pair<Int, Int> {
        var fw = w.toDouble()
        var fh = h.toDouble()
        if (maxW != null && fw > maxW) { val s = maxW / fw; fw *= s; fh *= s }
        if (maxH != null && fh > maxH) { val s = maxH / fh; fw *= s; fh *= s }
        return fw.toInt().coerceAtLeast(1) to fh.toInt().coerceAtLeast(1)
    }

    /** Binary-search the quality for lossy formats; PNG is just encoded once. */
    private fun fitToTarget(bmp: Bitmap, format: String, lossy: Boolean, target: Int): ByteArray {
        if (!lossy) return encode(bmp, format, 100, lossless = false)
        var lo = 1
        var hi = 100
        var best: ByteArray? = null
        while (lo <= hi) {
            val q = (lo + hi) / 2
            val bytes = encode(bmp, format, q, lossless = false)
            if (bytes.size <= target) { best = bytes; lo = q + 1 } else hi = q - 1
        }
        return best ?: encode(bmp, format, 1, lossless = false)
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

    /** Copy the common EXIF tags from source into the JPEG output. */
    private fun copyExif(src: String, dst: String) {
        runCatching {
            val from = ExifInterface(src)
            val to = ExifInterface(dst)
            for (tag in EXIF_TAGS) from.getAttribute(tag)?.let { to.setAttribute(tag, it) }
            to.saveAttributes()
        }
    }

    private companion object {
        val EXIF_TAGS = listOf(
            ExifInterface.TAG_ORIENTATION,
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
