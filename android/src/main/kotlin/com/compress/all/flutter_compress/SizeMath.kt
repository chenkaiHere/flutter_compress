package com.compress.all.flutter_compress

/**
 * Turns a [CompressionConfig] intent (target size / bitrate / quality) into
 * concrete encoder numbers. Single source of truth so `estimate()` and
 * `compress()` never disagree.
 */
object SizeMath {

    /** Safety margin — real muxed output tends to run a little over the raw
     * bitrate*duration math (container overhead, keyframes). */
    private const val SIZE_SAFETY = 0.95

    private const val MIN_VIDEO_BPS = 100_000

    /** Compute the target video bitrate (bits/sec) from the config. */
    fun videoBitrateBps(
        config: CompressionConfig,
        durationMs: Long,
        sourceBitrateKbps: Int,
        targetHeight: Int,
    ): Int {
        config.targetSizeMB?.let { mb ->
            val totalBits = mb.toLong() * 8L * 1024L * 1024L
            val durationSec = (durationMs / 1000.0).coerceAtLeast(0.001)
            val audioBps = if (config.removeAudio) 0
            else (config.audioBitrateKbps ?: 128) * 1000
            val audioBits = audioBps * durationSec
            val videoBits = totalBits * SIZE_SAFETY - audioBits
            return (videoBits / durationSec).toInt().coerceAtLeast(MIN_VIDEO_BPS)
        }
        config.videoBitrateKbps?.let { return it * 1000 }

        // Quality as a percentage of the SOURCE bitrate. An explicit
        // qualityPercent wins over the preset tier (more specific intent).
        val percent = (config.qualityPercent ?: presetPercent(config.quality))
            .coerceIn(1, 100)
        val srcBps = sourceBitrateKbps * 1000
        if (srcBps > 0) {
            // percent <= 100 guarantees we never re-inflate above the source.
            return (srcBps * percent / 100.0).toInt().coerceAtLeast(MIN_VIDEO_BPS)
        }
        // Source bitrate unknown: fall back to a resolution-based baseline
        // (anchored so 50% == a reasonable "medium"), scaled by percent.
        val width = targetHeight * 16 / 9
        val baselineMedium = width * targetHeight * 30 * 0.12
        return (baselineMedium * percent / 50.0).toInt().coerceAtLeast(MIN_VIDEO_BPS)
    }

    /** Preset tier -> percentage of source bitrate. */
    private fun presetPercent(quality: String): Int = when (quality) {
        "high" -> 80
        "medium" -> 50
        "low" -> 30
        "veryLow" -> 15
        else -> 50
    }

    /**
     * Compute output width/height: preserve aspect, only ever scale down to the
     * requested caps, then align per [CompressionConfig.alignment].
     */
    fun targetDimensions(srcW: Int, srcH: Int, config: CompressionConfig): Pair<Int, Int> {
        if (srcW <= 0 || srcH <= 0) return align(srcW, srcH, config.alignment)
        var w = srcW.toDouble()
        var h = srcH.toDouble()
        val maxW = config.maxWidth
        val maxH = config.maxHeight
        if (maxW != null && w > maxW) {
            val s = maxW / w; w *= s; h *= s
        }
        if (maxH != null && h > maxH) {
            val s = maxH / h; w *= s; h *= s
        }
        return align(w.toInt(), h.toInt(), config.alignment)
    }

    private fun align(w: Int, h: Int, alignment: String): Pair<Int, Int> {
        // Encoders always require even dimensions; auto16 rounds to /16 to avoid
        // macroblock padding artifacts on the edges.
        val m = if (alignment == "auto16") 16 else 2
        fun round(v: Int): Int = ((v + m / 2) / m * m).coerceAtLeast(m)
        return round(w) to round(h)
    }
}
