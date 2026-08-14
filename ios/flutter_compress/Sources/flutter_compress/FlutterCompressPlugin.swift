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
    // publish() is what earns us `detachFromEngine(for:)`, so an engine teardown
    // can stop an in-flight export instead of leaving it running.
    registrar.publish(instance)
    instance.engine.onProgress = { [weak instance] payload in
      DispatchQueue.main.async { instance?.eventSink?(payload) }
    }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    engine.cancelAll()
    eventSink = nil
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
    // Throwing (rather than force-unwrapping) keeps a malformed call from
    // crashing the host app — it surfaces as a FlutterError instead.
    func str(_ k: String) throws -> String {
      guard let v = a[k] as? String else { throw Self.badArg(k) }
      return v
    }
    func map(_ k: String) throws -> [String: Any] {
      guard let v = a[k] as? [String: Any] else { throw Self.badArg(k) }
      return v
    }

    switch call.method {
    case "getVideoInfo":
      dispatch(result, ErrorCode.infoFailed) { try MediaProbe.videoInfo(path: try str("path")) }

    case "estimate":
      dispatch(result, ErrorCode.estimateFailed) {
        try self.engine.estimate(
          path: try str("path"), config: CompressionConfig(map: try map("config")))
      }

    case "compress":
      guard let config = try? CompressionConfig(map: map("config")),
        let id = try? str("id"), let path = try? str("path")
      else {
        result(
          FlutterError(
            code: ErrorCode.badArguments,
            message: "compress: missing id/path/config", details: nil))
        return
      }
      let outputDir = a["outputDir"] as? String, outputName = a["outputName"] as? String
      workQueue.async {
        self.engine.compress(
          id: id, path: path, config: config, outputDir: outputDir, outputName: outputName
        ) { outcome in
          // The engine finishes on its own queue; reply on the platform thread.
          DispatchQueue.main.async {
            switch outcome {
            case .success(let map): result(map)
            case .cancelled:
              result(
                FlutterError(
                  code: ErrorCode.cancelled, message: "Compression cancelled", details: nil))
            case .failure(let message):
              result(FlutterError(code: ErrorCode.compressFailed, message: message, details: nil))
            }
          }
        }
      }

    case "cancel":
      engine.cancel(id: a["id"] as? String)
      result(nil)

    case "isCompressing":
      result(engine.isCompressing())

    case "getThumbnail":
      dispatch(result, ErrorCode.thumbnailFailed) {
        try Thumbnailer.generate(
          dir: PluginFiles.cacheDir(), path: try str("path"),
          positionMs: (a["positionMs"] as? NSNumber)?.int64Value ?? 0,
          quality: (a["quality"] as? NSNumber)?.intValue ?? 80,
          maxWidth: (a["maxWidth"] as? NSNumber)?.intValue)
      }

    case "clearCache":
      PluginFiles.clearCache()
      result(nil)

    case "saveToDownloads":
      dispatch(result, ErrorCode.saveFailed) {
        try DownloadSaver.save(path: try str("path"), fileName: a["fileName"] as? String)
      }

    // ---- images ----
    case "getImageInfo":
      dispatch(result, ErrorCode.imageInfoFailed) { try ImageEngine.info(path: try str("path")) }

    case "compressImage":
      dispatch(result, ErrorCode.imageCompressFailed) {
        try ImageEngine.compress(
          path: try str("path"),
          config: ImageConfig(map: try map("config")),
          outputDir: a["outputDir"] as? String,
          outputName: a["outputName"] as? String)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Run a throwing [block] off the main thread, then deliver its value (or a
  /// typed error) **on the main queue** — a `FlutterResult` must be invoked from
  /// the platform thread, and replying from a background queue is the kind of
  /// race that only shows up as a rare crash on user devices.
  private func dispatch(
    _ result: @escaping FlutterResult, _ errorCode: String, _ block: @escaping () throws -> Any?
  ) {
    workQueue.async {
      let outcome: Result<Any?, Error>
      do { outcome = .success(try block()) } catch { outcome = .failure(error) }
      DispatchQueue.main.async {
        switch outcome {
        case .success(let value):
          result(value)
        case .failure(let error):
          result(FlutterError(code: errorCode, message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private static func badArg(_ key: String) -> NSError {
    NSError(
      domain: "flutter_compress", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Missing or invalid argument: \(key)"])
  }
}
