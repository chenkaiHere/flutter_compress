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

/**
 * Bridges Flutter <-> the native pieces: [CompressionEngine] (transcode),
 * [MediaProbe], [Thumbnailer], [DownloadSaver].
 *
 * Everything runs on the main looper because Media3's `Transformer` must be
 * created and driven from a thread that has a [android.os.Looper].
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
        val eng = engine ?: return result.error("no_engine", "Engine not initialized", null)
        when (call.method) {
            "getVideoInfo" ->
                dispatch(result, "info_failed") { MediaProbe.videoInfo(call.str("path")) }

            "estimate" ->
                dispatch(result, "estimate_failed") { eng.estimate(call.str("path"), call.config()) }

            "compress" -> dispatch(result, "compress_failed") {
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

            "getThumbnail" -> dispatch(result, "thumbnail_failed") {
                Thumbnailer.generate(
                    context.compressCacheDir(), call.str("path"),
                    call.long("positionMs", 0), call.int("quality", 80),
                    call.argument<Number>("maxWidth")?.toInt(),
                )
            }

            "clearCache" -> {
                context.clearCompressCache()
                result.success(null)
            }

            "saveToDownloads" -> dispatch(result, "save_failed") {
                DownloadSaver.save(context, call.str("path"), call.argument<String>("fileName"))
            }

            // ---- images ----
            "getImageInfo" -> dispatch(result, "image_info_failed") {
                imageEngine!!.info(call.str("path"))
            }

            "compressImage" -> dispatch(result, "image_compress_failed") {
                imageEngine!!.compress(
                    call.str("path"),
                    ImageConfig.fromMap(call.argument<Map<String, Any?>>("config")!!),
                    call.argument<String>("outputDir"),
                    call.argument<String>("outputName"),
                )
            }

            else -> result.notImplemented()
        }
    }

    /** Run [block] off the main call, forwarding its value or a typed error. */
    private fun dispatch(result: Result, errorCode: String, block: suspend () -> Any?) {
        scope.launch {
            runCatching { block() }
                .onSuccess { result.success(it) }
                .onFailure { e ->
                    if (e is CompressionCancelledException) result.error("cancelled", e.message, null)
                    else result.error(errorCode, e.message, null)
                }
        }
    }

    // ---- argument accessors ------------------------------------------------

    private fun MethodCall.str(key: String): String = argument<String>(key)!!
    private fun MethodCall.int(key: String, default: Int): Int =
        (argument<Number>(key) ?: default).toInt()
    private fun MethodCall.long(key: String, default: Long): Long =
        (argument<Number>(key) ?: default).toLong()

    private fun MethodCall.config(): CompressionConfig =
        CompressionConfig.fromMap(argument<Map<String, Any?>>("config")!!)
}
