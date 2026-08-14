package com.compress.all.flutter_compress

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.coroutines.CoroutineContext

/**
 * Bridges Flutter <-> the native pieces: [CompressionEngine] (transcode),
 * [MediaProbe], [Thumbnailer], [DownloadSaver].
 *
 * Only video transcoding runs on the main looper — Media3's `Transformer` must be
 * created and driven from a thread that has a [android.os.Looper]. Everything
 * else is dispatched to a background dispatcher and replies on the main thread
 * (see [dispatch]).
 */
class FlutterCompressPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var engine: CompressionEngine? = null
    private var imageEngine: ImageEngine? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "flutter_compress/methods")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "flutter_compress/progress")
        eventChannel.setStreamHandler(this)
        engine = CompressionEngine(context) { eventSink?.success(it) }
        imageEngine = ImageEngine(context)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        engine?.cancelAll()
        scope.cancel()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val eng = engine ?: return result.error(ErrorCode.NO_ENGINE, "Engine not initialized", null)
        when (call.method) {
            "getVideoInfo" ->
                dispatch(result, ErrorCode.INFO_FAILED) { MediaProbe.videoInfo(call.str("path")) }

            "estimate" ->
                dispatch(result, ErrorCode.ESTIMATE_FAILED) { eng.estimate(call.str("path"), call.config()) }

            // Media3's Transformer must be created and driven from a Looper thread.
            "compress" -> dispatch(result, ErrorCode.COMPRESS_FAILED, Dispatchers.Main.immediate) {
                eng.compress(
                    call.str("id"), call.str("path"), call.config(),
                    call.argument<String>("outputDir"),
                    call.argument<String>("outputName"),
                )
            }

            "cancel" -> {
                eng.cancel(call.argument<String>("id"))
                result.success(null)
            }

            "isCompressing" -> result.success(eng.isCompressing())

            "getThumbnail" -> dispatch(result, ErrorCode.THUMBNAIL_FAILED) {
                Thumbnailer.generate(
                    context.compressCacheDir(), call.str("path"),
                    call.long("positionMs", 0), call.int("quality", 80),
                    call.argument<Number>("maxWidth")?.toInt(),
                )
            }

            // Deleting a cache full of multi-hundred-MB transcodes is real IO.
            "clearCache" -> dispatch(result, ErrorCode.SAVE_FAILED, Dispatchers.IO) {
                context.clearCompressCache()
                null
            }

            "saveToDownloads" -> dispatch(result, ErrorCode.SAVE_FAILED, Dispatchers.IO) {
                DownloadSaver.save(context, call.str("path"), call.argument<String>("fileName"))
            }

            // ---- images ----
            "getImageInfo" -> dispatch(result, ErrorCode.IMAGE_INFO_FAILED) {
                requireNotNull(imageEngine).info(call.str("path"))
            }

            "compressImage" -> dispatch(result, ErrorCode.IMAGE_COMPRESS_FAILED) {
                requireNotNull(imageEngine).compress(
                    call.str("path"),
                    call.imageConfig(),
                    call.argument<String>("outputDir"),
                    call.argument<String>("outputName"),
                )
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Run [block] on [ctx], then deliver its value (or a typed error) on the
     * main thread, as `MethodChannel.Result` requires.
     *
     * Defaults to a background dispatcher: only Media3's `Transformer` needs the
     * main looper, and everything else here (image encode, probes, thumbnails,
     * MediaStore copies) is blocking CPU/IO work that would otherwise ANR.
     */
    private fun dispatch(
        result: Result,
        errorCode: String,
        ctx: CoroutineContext = Dispatchers.Default,
        block: suspend () -> Any?,
    ) {
        scope.launch {
            runCatching { withContext(ctx) { block() } }
                .onSuccess { result.success(it) }
                .onFailure { e ->
                    when (e) {
                        is CompressionCancelledException ->
                            result.error(ErrorCode.CANCELLED, e.message, null)
                        is BadArgumentException ->
                            result.error(ErrorCode.BAD_ARGUMENTS, e.message, null)
                        // Keep the native detail: it's the only clue to the origin.
                        else -> result.error(errorCode, e.message, e.stackTraceToString())
                    }
                }
        }
    }

    // ---- argument accessors ------------------------------------------------

    /** Missing/mistyped args must surface as [ErrorCode.BAD_ARGUMENTS], matching
     *  iOS — `!!` here would leak an NPE as whatever the caller's error code is. */
    private fun MethodCall.str(key: String): String =
        argument<String>(key) ?: throw BadArgumentException(key)
    private fun MethodCall.int(key: String, default: Int): Int =
        (argument<Number>(key) ?: default).toInt()
    private fun MethodCall.long(key: String, default: Long): Long =
        (argument<Number>(key) ?: default).toLong()

    private fun MethodCall.config(): CompressionConfig =
        CompressionConfig.fromMap(
            argument<Map<String, Any?>>("config") ?: throw BadArgumentException("config"),
        )

    private fun MethodCall.imageConfig(): ImageConfig =
        ImageConfig.fromMap(
            argument<Map<String, Any?>>("config") ?: throw BadArgumentException("config"),
        )
}
