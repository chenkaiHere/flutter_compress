package com.compress.all.flutter_compress

import android.content.Context
import android.media.MediaCodecInfo
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.DefaultMuxer
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.EncoderUtil
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.TransformationRequest
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Media3-Transformer video transcoder. Owns only the encode pipeline (bitrate,
 * scaling, codec fallback, progress, cancellation); metadata, thumbnails and
 * saving live in their own classes ([MediaProbe], [Thumbnailer], [DownloadSaver]).
 *
 * One [Transformer] runs at a time — the Dart layer calls compress sequentially.
 * All Transformer interaction happens on the main looper (see the plugin).
 */
class CompressionEngine(
    private val context: Context,
    private val onProgress: (Map<String, Any?>) -> Unit,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val progressHolder = ProgressHolder()
    private var activeTransformer: Transformer? = null
    private var activeId: String? = null
    private var cancelledId: String? = null
    private var pollRunnable: Runnable? = null

    /**
     * The suspended `runTransformer` call for the active job.
     *
     * `Transformer.cancel()` tears the pipeline down **without** invoking
     * `Transformer.Listener` (Media3 logs "Export error after export ended" and
     * swallows any late codec error), so cancellation has to resume this itself
     * or the caller's future would hang forever.
     */
    private var activeCont: CancellableContinuation<ExportResult>? = null

    /**
     * A cancel that arrived before its job registered.
     *
     * Dart binds the job id to its token before the channel call lands, so a
     * cancel in that window would otherwise be dropped and the job would run to
     * completion despite the token reading cancelled. Dart issues one compress at
     * a time, so remembering the latest id is enough.
     */
    private var preCancelledId: String? = null

    // ---- estimate ----------------------------------------------------------

    fun estimate(path: String, config: CompressionConfig): Map<String, Any?> {
        val info = MediaProbe.videoInfo(path)
        val durationMs = clampDuration(info["durationMs"] as Long, config)
        val (tw, th) = SizeMath.targetDimensions(info["width"] as Int, info["height"] as Int, config)
        val videoBps = SizeMath.videoBitrateBps(config, durationMs, info["bitrateKbps"] as Int, th)
        val audioBps = if (config.removeAudio) 0 else (config.audioBitrateKbps ?: 128) * 1000
        val totalBits = (videoBps + audioBps).toLong() * durationMs / 1000
        return mapOf(
            "estimatedSizeBytes" to totalBits / 8,
            "estimatedBitrateKbps" to (videoBps + audioBps) / 1000,
            "targetWidth" to tw,
            "targetHeight" to th,
        )
    }

    // ---- compress ----------------------------------------------------------

    suspend fun compress(
        id: String,
        path: String,
        config: CompressionConfig,
        outputDir: String? = null,
        outputName: String? = null,
    ): Map<String, Any?> {
        // A cancel may have landed before this call did.
        if (preCancelledId == id) {
            preCancelledId = null
            throw CompressionCancelledException()
        }
        val info = MediaProbe.videoInfo(path)
        val srcW = info["width"] as Int
        val srcH = info["height"] as Int
        val originalSize = File(path).length()
        val durationMs = clampDuration(info["durationMs"] as Long, config)
        val (tw, th) = SizeMath.targetDimensions(srcW, srcH, config)
        val videoMime = resolveVideoMime(config.codec)
        val usedCodec = if (videoMime == MimeTypes.VIDEO_H265) "h265" else "h264"
        val videoBps = SizeMath.videoBitrateBps(config, durationMs, info["bitrateKbps"] as Int, th)
        // Android's Media3 muxer only produces mp4, so the extension is always
        // mp4 regardless of the requested container.
        val outFile = context.resolveOutput(outputDir, outputName, path, "mp4")

        // What the encode actually produced, as opposed to what we asked for
        // (CLAUDE.md §12.1). Callers can only trust a request if we report back.
        var actualFrameRate: Double? = null
        var actualHasAudio: Boolean? = null
        var outDurationMs = durationMs
        try {
            val export = runTransformer(
                id, buildEditedItem(path, config, srcW, srcH, tw, th), outFile, videoMime,
                encoderSettings(config, videoMime, videoBps), config.keepAliveInBackground,
            )
            if (export.durationMs > 0) outDurationMs = export.durationMs
            if (export.videoFrameCount > 0 && export.durationMs > 0) {
                actualFrameRate = export.videoFrameCount * 1000.0 / export.durationMs
            }
            actualHasAudio = export.audioMimeType != null

            // A large gap here means the encoder ignored the requested bitrate, so
            // a target size won't be met — worth surfacing, but only when it's bad.
            val achieved = export.averageVideoBitrate
            if (achieved > 0 && achieved < videoBps / 2) {
                Log.w(
                    TAG,
                    "encoder delivered ${achieved / 1000}kbps of ${videoBps / 1000}kbps " +
                        "requested (${export.videoEncoderName}); output will undershoot the target",
                )
            }
        } catch (e: Throwable) {
            // Cancellation and export errors both leave a partially muxed file
            // behind; don't let it accumulate in the cache.
            outFile.delete()
            throw e
        }

        val compressedSize = outFile.length()
        val skipped = config.keepOriginalIfLarger && compressedSize >= originalSize
        if (skipped) outFile.delete()
        return mapOf(
            "id" to id,
            "outputPath" to if (skipped) path else outFile.absolutePath,
            "originalSizeBytes" to originalSize,
            "compressedSizeBytes" to if (skipped) originalSize else compressedSize,
            "width" to if (skipped) srcW else tw,
            "height" to if (skipped) srcH else th,
            // The *output* duration: a muxer told the wrong duration truncates
            // the file, and reporting the source length would hide that.
            "durationMs" to if (skipped) durationMs else outDurationMs,
            "codec" to usedCodec,
            "skipped" to skipped,
            "frameRate" to actualFrameRate,
            "hasAudio" to if (skipped) null else actualHasAudio,
        )
    }

    private fun buildEditedItem(
        path: String, config: CompressionConfig, srcW: Int, srcH: Int, tw: Int, th: Int,
    ): EditedMediaItem {
        val item = MediaItem.Builder().setUri(Uri.fromFile(File(path)))
        if (config.trimStartMs != null && config.trimEndMs != null) {
            item.setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(config.trimStartMs)
                    .setEndPositionMs(config.trimEndMs)
                    .build(),
            )
        }
        // Only attach a scaling effect when the size actually changes. Attaching
        // it unconditionally runs every frame through the GL pipeline, which on
        // slower devices produces frames faster than the encoder drains them —
        // the surface runs out of buffers and frames are silently dropped.
        val effects = if (tw == srcW && th == srcH) {
            Effects(emptyList(), emptyList())
        } else {
            Effects(
                emptyList(),
                listOf(Presentation.createForWidthAndHeight(tw, th, Presentation.LAYOUT_SCALE_TO_FIT)),
            )
        }
        return EditedMediaItem.Builder(item.build())
            .setRemoveAudio(config.removeAudio)
            .setEffects(effects)
            .build()
    }

    /**
     * Encoder settings for this job.
     *
     * Target-size mode pins **CBR**. With the default VBR the bitrate is only a
     * soft average: the rate controller spends what it thinks the content needs,
     * and re-encoding already-compressed footage looks "easy" to it (the first
     * encode already discarded the fine detail), so it undershoots hard — an
     * 80 MB target could land near 20 MB. Quality modes stay VBR, where letting
     * the bitrate float with content is exactly the point.
     *
     * Falls back to VBR when no encoder for [videoMime] advertises CBR.
     */
    private fun encoderSettings(
        config: CompressionConfig,
        videoMime: String,
        videoBps: Int,
    ): VideoEncoderSettings {
        val builder = VideoEncoderSettings.Builder().setBitrate(videoBps)
        val cbrSupported = supportsCbr(videoMime)
        val useCbr = config.targetSizeMB != null && cbrSupported
        if (useCbr) {
            builder.setBitrateMode(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR)
        }
        // Media3 defaults `operating-rate` to Integer.MAX_VALUE. MediaCodec's
        // documented sentinel for "as fast as possible" is Short.MAX_VALUE, so
        // INT_MAX is out of contract; older Qualcomm OMX encoders can react to it
        // by dropping input frames. Priority 1 = non-realtime, correct for a
        // transcode (and what Media3 already requests).
        builder.setEncoderPerformanceParameters(OPERATING_RATE_MAX, PRIORITY_NON_REALTIME)
        return builder.build()
    }

    private fun supportsCbr(videoMime: String): Boolean =
        EncoderUtil.getSupportedEncoders(videoMime).any { encoder ->
            EncoderUtil.isBitrateModeSupported(
                encoder, videoMime, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR,
            )
        }

    private suspend fun runTransformer(
        id: String,
        editedItem: EditedMediaItem,
        outFile: File,
        videoMime: String,
        videoEncoderSettings: VideoEncoderSettings,
        keepAliveInBackground: Boolean,
    ): ExportResult = suspendCancellableCoroutine { cont ->
        val encoderFactory = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(videoEncoderSettings)
            .setEnableFallback(true) // let Media3 downgrade unsupported settings
            .build()

        val transformer = Transformer.Builder(context)
            .setVideoMimeType(videoMime)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoderFactory)
            // Use the default muxer factory. Its `long` overload is NOT a timeout:
            // in Media3 1.4.x that parameter is `videoDurationMs`, so passing a
            // "generous timeout" told the muxer the video was that many ms long
            // and truncated every longer input to it. The no-arg constructor
            // passes C.TIME_UNSET, i.e. "use the real duration".
            .setMuxerFactory(DefaultMuxer.Factory())
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, result: ExportResult) {
                    finishJob()
                    if (cont.isActive) cont.resume(result)
                }

                override fun onFallbackApplied(
                    composition: Composition,
                    original: TransformationRequest,
                    fallback: TransformationRequest,
                ) {
                    // Media3 silently downgraded what we asked for.
                    Log.w(TAG, "fallback applied: $original -> $fallback")
                }

                override fun onError(c: Composition, r: ExportResult, e: ExportException) {
                    // Read before finishJob(), which clears the flag.
                    val wasCancelled = cancelledId == id
                    finishJob()
                    if (!cont.isActive) return
                    if (wasCancelled) cont.resumeWithException(CompressionCancelledException())
                    else cont.resumeWithException(RuntimeException(describe(e), e))
                }
            })
            .build()

        activeTransformer = transformer
        activeId = id
        activeCont = cont
        if (keepAliveInBackground) CompressionForegroundService.start(context)
        transformer.start(editedItem, outFile.absolutePath)
        startProgressPolling(id, outFile)
        cont.invokeOnCancellation { mainHandler.post { runCatching { transformer.cancel() } } }
    }

    /** Tear down the active job's bookkeeping. Must run on the main looper. */
    private fun finishJob() {
        stopProgressPolling()
        activeTransformer = null
        activeId = null
        activeCont = null
        cancelledId = null
        CompressionForegroundService.stop(context)
    }

    // ---- progress / cancel -------------------------------------------------

    private fun startProgressPolling(id: String, out: File) {
        val start = System.nanoTime()
        pollRunnable = object : Runnable {
            override fun run() {
                val t = activeTransformer ?: return
                if (t.getProgress(progressHolder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    val fraction = progressHolder.progress / 100.0
                    val elapsedMs = (System.nanoTime() - start) / 1_000_000
                    onProgress(
                        mapOf(
                            "id" to id,
                            "progress" to fraction,
                            "estimatedRemainingMs" to
                                if (fraction > 0.01) ((elapsedMs / fraction) - elapsedMs).toLong() else null,
                            "currentOutputBytes" to if (out.exists()) out.length() else null,
                        ),
                    )
                }
                mainHandler.postDelayed(this, 250)
            }
        }.also { mainHandler.post(it) }
    }

    private fun stopProgressPolling() {
        pollRunnable?.let { mainHandler.removeCallbacks(it) }
        pollRunnable = null
    }

    /** Cancel [id], or the active job when [id] is null. */
    fun cancel(id: String?) {
        val requested = id ?: activeId ?: return
        mainHandler.post { abort(requested) }
    }

    fun cancelAll() {
        mainHandler.post { abort(activeId) }
    }

    /**
     * Stop the active job and complete its caller with a cancellation.
     *
     * `Transformer.cancel()` never calls back into [Transformer.Listener], so
     * resuming the continuation here is what keeps `compress()` from hanging.
     * Runs on the main looper, where all job state is mutated.
     */
    private fun abort(id: String?) {
        if (id == null) return
        if (id != activeId) {
            // Either already finished, or it hasn't registered yet — remember it
            // so compress() can refuse to start.
            preCancelledId = id
            return
        }
        cancelledId = id
        runCatching { activeTransformer?.cancel() }
        val cont = activeCont
        finishJob()
        // A racing onError may already have resumed it; isActive guards that.
        if (cont != null && cont.isActive) {
            cont.resumeWithException(CompressionCancelledException())
        }
    }

    fun isCompressing(): Boolean = activeTransformer != null

    // ---- helpers -----------------------------------------------------------

    private fun clampDuration(fullDurationMs: Long, config: CompressionConfig): Long {
        val s = config.trimStartMs
        val e = config.trimEndMs
        return if (s != null && e != null) (e - s).coerceAtLeast(1) else fullDurationMs
    }

    /** Requested codec → mime, falling back to H.264 when there's no HEVC encoder. */
    private fun resolveVideoMime(codec: String): String {
        val hasHevc = EncoderUtil.getSupportedEncoders(MimeTypes.VIDEO_H265).isNotEmpty()
        return if (codec == "h265" && hasHevc) MimeTypes.VIDEO_H265 else MimeTypes.VIDEO_H264
    }

    private fun describe(e: ExportException): String = buildString {
        append("code=").append(e.errorCode)
        e.message?.let { append("; ").append(it) }
        e.cause?.let { append("; cause=").append(it.message ?: it.toString()) }
    }

    private companion object {
        const val TAG = "FlutterCompress"

        /** MediaCodec's documented "as fast as possible" operating rate. */
        const val OPERATING_RATE_MAX = 32767 // Short.MAX_VALUE
        const val PRIORITY_NON_REALTIME = 1
    }
}
