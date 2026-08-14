package com.compress.all.flutter_compress

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Boundary coverage for the Kotlin half of the three-way SizeMath port
 * (CLAUDE.md §12.2).
 *
 * These cases intentionally mirror `test/size_math_test.dart` one for one: the
 * algorithm is duplicated across Kotlin, Swift and Dart, so the only way to
 * catch drift is to assert the same numbers on each side. If you change a case
 * here, change it there too.
 */
class SizeMathTest {

    private fun config(
        quality: String = "medium",
        qualityPercent: Int? = null,
        targetSizeMB: Int? = null,
        videoBitrateKbps: Int? = null,
        maxWidth: Int? = null,
        maxHeight: Int? = null,
        removeAudio: Boolean = false,
        audioBitrateKbps: Int? = null,
        alignment: String = "auto16",
    ) = CompressionConfig(
        quality = quality,
        qualityPercent = qualityPercent,
        targetSizeMB = targetSizeMB,
        videoBitrateKbps = videoBitrateKbps,
        codec = "h265",
        maxWidth = maxWidth,
        maxHeight = maxHeight,
        frameRate = null,
        removeAudio = removeAudio,
        audioBitrateKbps = audioBitrateKbps,
        trimStartMs = null,
        trimEndMs = null,
        alignment = alignment,
        keepOriginalIfLarger = true,
        keepAliveInBackground = true,
    )

    private fun bitrate(
        config: CompressionConfig,
        durationMs: Long = 60_000,
        sourceBitrateKbps: Int = 9_000,
        targetHeight: Int = 1080,
    ) = SizeMath.videoBitrateBps(config, durationMs, sourceBitrateKbps, targetHeight)

    // ---- priority chain ----------------------------------------------------

    @Test
    fun `targetSizeMB wins over every other control`() {
        val bps = bitrate(
            config(targetSizeMB = 10, videoBitrateKbps = 99_999, qualityPercent = 10),
        )
        val expected = (10L * 8 * 1024 * 1024 * 0.95 - 128_000 * 60.0) / 60.0
        assertEquals(expected.toInt(), bps)
    }

    @Test
    fun `videoBitrateKbps wins over quality controls`() {
        assertEquals(
            2_500_000,
            bitrate(config(videoBitrateKbps = 2_500, qualityPercent = 10)),
        )
    }

    @Test
    fun `qualityPercent wins over the preset tier`() {
        assertEquals(
            9_000 * 1000 * 25 / 100,
            bitrate(config(quality = "high", qualityPercent = 25)),
        )
    }

    @Test
    fun `preset tiers map to their documented percentages`() {
        val src = 10_000
        fun forTier(tier: String) = bitrate(config(quality = tier), sourceBitrateKbps = src)
        assertEquals(src * 1000 * 80 / 100, forTier("high"))
        assertEquals(src * 1000 * 50 / 100, forTier("medium"))
        assertEquals(src * 1000 * 30 / 100, forTier("low"))
        assertEquals(src * 1000 * 15 / 100, forTier("veryLow"))
    }

    // ---- edges -------------------------------------------------------------

    @Test
    fun `never re-inflates above the source bitrate`() {
        val bps = bitrate(config(qualityPercent = 100), sourceBitrateKbps = 4_000)
        assertTrue(bps <= 4_000 * 1000, "expected <= source, got $bps")
    }

    @Test
    fun `a source bitrate below the floor clamps up instead of failing`() {
        assertEquals(100_000, bitrate(config(), sourceBitrateKbps = 50))
    }

    @Test
    fun `an absurdly small target size still clears the floor`() {
        assertEquals(
            100_000,
            bitrate(config(targetSizeMB = 1), durationMs = 3_600_000),
        )
    }

    @Test
    fun `a zero-length source does not divide by zero`() {
        // coerceAtLeast(0.001) on the duration keeps this finite.
        assertTrue(bitrate(config(targetSizeMB = 10), durationMs = 0) > 0)
    }

    @Test
    fun `unknown source bitrate falls back to a resolution baseline`() {
        val bps = bitrate(config(), sourceBitrateKbps = 0, targetHeight = 720)
        val width = 720 * 16 / 9
        assertEquals((width * 720 * 30 * 0.12).toInt(), bps)
    }

    @Test
    fun `removeAudio hands the whole target budget to video`() {
        val withAudio = bitrate(config(targetSizeMB = 10))
        val without = bitrate(config(targetSizeMB = 10, removeAudio = true))
        assertTrue(without > withAudio, "$without should exceed $withAudio")
    }

    @Test
    fun `a custom audio bitrate changes the video budget`() {
        val low = bitrate(config(targetSizeMB = 10, audioBitrateKbps = 64))
        val high = bitrate(config(targetSizeMB = 10, audioBitrateKbps = 256))
        assertTrue(low > high)
    }

    // ---- dimensions --------------------------------------------------------

    @Test
    fun `no cap keeps the source exactly, without aligning`() {
        // Regression: auto16 used to round 1080 *up* to 1088, which broke
        // "downscale only" and forced a needless full-frame GL rescale.
        assertEquals(1080 to 2160, SizeMath.targetDimensions(1080, 2160, config()))
    }

    @Test
    fun `alignment never rounds up`() {
        val (w, _) = SizeMath.targetDimensions(2000, 1000, config(maxWidth = 1000))
        assertTrue(w <= 1000, "alignment upscaled to $w")
        assertEquals(0, w % 16)
    }

    @Test
    fun `only ever scales down - a cap above the source is a no-op`() {
        assertEquals(
            640 to 480,
            SizeMath.targetDimensions(640, 480, config(maxWidth = 4000, maxHeight = 4000)),
        )
    }

    @Test
    fun `caps each axis independently, preserving aspect`() {
        val (w, h) = SizeMath.targetDimensions(
            4000, 2000, config(maxWidth = 1920, alignment = "none"),
        )
        assertTrue(w <= 1920)
        assertTrue(kotlin.math.abs(w.toDouble() / h - 2) < 0.05, "aspect drifted: ${w}x$h")
    }

    @Test
    fun `alignment none still yields even dimensions`() {
        val (w, h) = SizeMath.targetDimensions(
            1001, 667, config(maxWidth = 1000, alignment = "none"),
        )
        assertEquals(0, w % 2)
        assertEquals(0, h % 2)
    }

    @Test
    fun `degenerate source dimensions pass through instead of throwing`() {
        assertEquals(0 to 0, SizeMath.targetDimensions(0, 0, config()))
        assertEquals(-1 to -1, SizeMath.targetDimensions(-1, -1, config(maxWidth = 100)))
    }

    @Test
    fun `never returns a zero side for a tiny cap`() {
        val (w, h) = SizeMath.targetDimensions(1920, 1080, config(maxWidth = 8))
        assertTrue(w > 0 && h > 0, "got ${w}x$h")
    }
}
