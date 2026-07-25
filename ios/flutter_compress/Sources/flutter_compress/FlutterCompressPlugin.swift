import Flutter
import UIKit

/// Bridges Flutter <-> the native pieces: `CompressionEngine` (transcode),
/// `MediaProbe`, `Thumbnailer`, `DownloadSaver`.
public class FlutterCompressPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

  private let engine = CompressionEngine()
  private var eventSink: FlutterEventSink?
  private let workQueue = DispatchQueue(label: "flutter_compress.work", qos: .userInitiated)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "flutter_compress/methods", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(
      name: "flutter_compress/progress", binaryMessenger: registrar.messenger())
    let instance = FlutterCompressPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
    instance.engine.onProgress = { [weak instance] payload in
      DispatchQueue.main.async { instance?.eventSink?(payload) }
    }
  }

  public func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments _: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let a = call.arguments as? [String: Any] ?? [:]
    func str(_ k: String) -> String { a[k] as! String }

    switch call.method {
    case "getVideoInfo":
      dispatch(result, "info_failed") { try MediaProbe.videoInfo(path: str("path")) }

    case "estimate":
      dispatch(result, "estimate_failed") {
        try self.engine.estimate(
          path: str("path"), config: CompressionConfig(map: a["config"] as! [String: Any]))
      }

    case "compress":
      let config = CompressionConfig(map: a["config"] as! [String: Any])
      let id = str("id"), path = str("path"), outputPath = a["outputPath"] as? String
      workQueue.async {
        self.engine.compress(id: id, path: path, config: config, outputPath: outputPath) { outcome in
          switch outcome {
          case .success(let map): result(map)
          case .cancelled:
            result(FlutterError(code: "cancelled", message: "Compression cancelled", details: nil))
          case .failure(let message):
            result(FlutterError(code: "compress_failed", message: message, details: nil))
          }
        }
      }

    case "cancel":
      engine.cancel(id: a["id"] as? String)
      result(nil)

    case "isCompressing":
      result(engine.isCompressing())

    case "getThumbnail":
      dispatch(result, "thumbnail_failed") {
        try Thumbnailer.generate(
          dir: PluginFiles.cacheDir(), path: str("path"),
          positionMs: (a["positionMs"] as? NSNumber)?.int64Value ?? 0,
          quality: (a["quality"] as? NSNumber)?.intValue ?? 80,
          maxWidth: (a["maxWidth"] as? NSNumber)?.intValue)
      }

    case "clearCache":
      PluginFiles.clearCache()
      result(nil)

    case "saveToDownloads":
      dispatch(result, "save_failed") {
        try DownloadSaver.save(path: str("path"), fileName: a["fileName"] as? String)
      }

    // ---- images ----
    case "getImageInfo":
      dispatch(result, "image_info_failed") { try ImageEngine.info(path: str("path")) }

    case "compressImage":
      dispatch(result, "image_compress_failed") {
        try ImageEngine.compress(
          path: str("path"),
          config: ImageConfig(map: a["config"] as! [String: Any]),
          outputPath: a["outputPath"] as? String)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Run a throwing [block] off the main thread, forwarding its value or a typed error.
  private func dispatch(
    _ result: @escaping FlutterResult, _ errorCode: String, _ block: @escaping () throws -> Any?
  ) {
    workQueue.async {
      do { result(try block()) }
      catch {
        result(FlutterError(code: errorCode, message: error.localizedDescription, details: nil))
      }
    }
  }
}
