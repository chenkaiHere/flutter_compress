import AVFoundation
import UIKit

/// AVAssetReader/Writer transcoding pipeline.
///
/// Unlike an `AVAssetExportSession` preset, this lets us set an *explicit*
/// average bitrate (`AVVideoAverageBitRateKey`), which is what makes precise
/// target-size compression possible on iOS.
final class CompressionEngine {

  /// Minimum gap between progress events, matching Android's 250ms polling.
  fileprivate static let progressIntervalSec: TimeInterval = 0.25

  private static let probeError = NSError(
    domain: "flutter_compress", code: 2,
    userInfo: [NSLocalizedDescriptionKey: "Unexpected media metadata types"])

  var onProgress: (([String: Any]) -> Void)?

  private let lock = NSLock()
  private var reader: AVAssetReader?
  private var writer: AVAssetWriter?
  private var activeId: String?
  private var cancelled = false
  /// Set when a cancel arrives for a job that hasn't registered itself yet.
  private var preCancelledId: String?
  private var bgTask: UIBackgroundTaskIdentifier = .invalid

  private let videoQueue = DispatchQueue(label: "flutter_compress.video")
  private let audioQueue = DispatchQueue(label: "flutter_compress.audio")

  func isCompressing() -> Bool {
    lock.lock(); defer { lock.unlock() }
    return activeId != nil
  }

  // MARK: - Estimate

  func estimate(path: String, config: CompressionConfig) throws -> [String: Any] {
    let info = try MediaProbe.videoInfo(path: path)
    // Read defensively rather than force-casting: the probe's value types are an
    // implicit cross-file contract, and a force cast would crash the host app
    // instead of surfacing as an `estimate_failed` error.
    guard let srcW = info["width"] as? Int,
      let srcH = info["height"] as? Int,
      let fullDuration = info["durationMs"] as? Int64,
      let srcKbps = info["bitrateKbps"] as? Int
    else { throw Self.probeError }
    let durationMs = clampDuration(fullDuration, config)
    let (tw, th) = SizeMath.targetDimensions(srcW: srcW, srcH: srcH, config: config)
    let videoBps = SizeMath.videoBitrateBps(
      config: config, durationMs: durationMs,
      sourceBitrateKbps: srcKbps, targetHeight: th)
    let audioBps = config.removeAudio ? 0 : (config.audioBitrateKbps ?? 128) * 1000
    let totalBits = Int64(videoBps + audioBps) * durationMs / 1000
    return [
      "estimatedSizeBytes": totalBits / 8,
      "estimatedBitrateKbps": (videoBps + audioBps) / 1000,
      "targetWidth": tw,
      "targetHeight": th,
    ]
  }

  // MARK: - Compress

  func compress(
    id: String, path: String, config: CompressionConfig,
    outputDir: String? = nil, outputName: String? = nil,
    completion: @escaping (CompressionOutcome) -> Void
  ) {
    lock.lock()
    activeId = id
    // A cancel may have landed while this call was still queued on the work
    // queue. Honour it instead of clearing the flag, or the export runs to
    // completion while the caller's token reads cancelled.
    cancelled = (preCancelledId == id)
    preCancelledId = nil
    lock.unlock()

    beginBackgroundTask()
    // The de-dup state lives outside `self` on purpose: if the engine is torn
    // down mid-export, `finish` must still deliver `completion`, or the caller's
    // future never resolves.
    let finishLock = NSLock()
    var didFinish = false
    let finish: (CompressionOutcome) -> Void = { [weak self] outcome in
      finishLock.lock()
      if didFinish {
        finishLock.unlock()
        return
      }
      didFinish = true
      finishLock.unlock()
      self?.clearActiveJob()
      self?.endBackgroundTask()
      completion(outcome)
    }

    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
        finish(.failure("No video track")); return
      }
      let originalSize =
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0

      let srcSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
      let srcW = Int(abs(srcSize.width))
      let srcH = Int(abs(srcSize.height))
      let fullDurationMs = Int64(CMTimeGetSeconds(asset.duration) * 1000)
      let durationMs = clampDuration(fullDurationMs, config)
      let (tw, th) = SizeMath.targetDimensions(srcW: srcW, srcH: srcH, config: config)
      let videoBps = SizeMath.videoBitrateBps(
        config: config, durationMs: durationMs,
        sourceBitrateKbps: Int(videoTrack.estimatedDataRate / 1000), targetHeight: th)

      // Output codec + fallback.
      let wantHEVC = config.codec == "h265" && supportsHEVCEncoding()
      let codecType: AVVideoCodecType = wantHEVC ? .hevc : .h264
      let usedCodec = wantHEVC ? "h265" : "h264"

      let fps = min(Double(videoTrack.nominalFrameRate == 0 ? 30 : videoTrack.nominalFrameRate),
        config.frameRate ?? 1_000_000)

      // Trim range.
      let startTime = CMTime(value: config.trimStartMs ?? 0, timescale: 1000)
      let dur = CMTime(value: durationMs, timescale: 1000)
      let timeRange = CMTimeRange(start: startTime, duration: dur)

      // Reader with a video composition — this bakes in rotation and scales to
      // the target render size in one pass.
      let composition = AVMutableVideoComposition(propertiesOf: asset)
      composition.renderSize = CGSize(width: tw, height: th)
      if config.frameRate != nil {
        composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(fps, 1)))
      }

      guard let reader = try? AVAssetReader(asset: asset) else {
        finish(.failure("Could not create reader")); return
      }
      reader.timeRange = timeRange

      let videoReaderOutput = AVAssetReaderVideoCompositionOutput(
        videoTracks: asset.tracks(withMediaType: .video),
        videoSettings: [
          kCVPixelBufferPixelFormatTypeKey as String:
            Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ])
      videoReaderOutput.videoComposition = composition
      guard reader.canAdd(videoReaderOutput) else {
        finish(.failure("Cannot add video output")); return
      }
      reader.add(videoReaderOutput)

      // Writer. Container: `auto` keeps a `.mov` source as `.mov` (AVFoundation
      // supports it), everything else → `.mp4`. `mp4` always forces `.mp4`.
      let srcExt = (path as NSString).pathExtension.lowercased()
      let keepMov = config.container == "auto" && srcExt == "mov"
      let fileType: AVFileType = keepMov ? .mov : .mp4
      let ext = keepMov ? "mov" : "mp4"
      let outURL = PluginFiles.resolveOutput(
        outputDir: outputDir, outputName: outputName, sourcePath: path, ext: ext)
      try? FileManager.default.createDirectory(
        at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try? FileManager.default.removeItem(at: outURL)
      guard let writer = try? AVAssetWriter(outputURL: outURL, fileType: fileType) else {
        finish(.failure("Could not create writer")); return
      }

      var compression: [String: Any] = [
        AVVideoAverageBitRateKey: videoBps,
        AVVideoMaxKeyFrameIntervalKey: Int(max(fps, 1) * 2),
        // Apple recommends declaring the source frame rate: without it the rate
        // controller has to guess the frame cadence, which makes the average
        // bitrate — and therefore a requested target size — less accurate.
        AVVideoExpectedSourceFrameRateKey: Int(max(fps, 1)),
      ]
      if codecType == .h264 {
        compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
      }
      let videoSettings: [String: Any] = [
        AVVideoCodecKey: codecType,
        AVVideoWidthKey: tw,
        AVVideoHeightKey: th,
        AVVideoCompressionPropertiesKey: compression,
      ]
      let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
      videoWriterInput.expectsMediaDataInRealTime = false
      guard writer.canAdd(videoWriterInput) else {
        finish(.failure("Cannot add video input")); return
      }
      writer.add(videoWriterInput)

      // Audio (optional).
      var audioReaderOutput: AVAssetReaderTrackOutput?
      var audioWriterInput: AVAssetWriterInput?
      if !config.removeAudio, let audioTrack = asset.tracks(withMediaType: .audio).first {
        let aOut = AVAssetReaderTrackOutput(
          track: audioTrack,
          outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
        if reader.canAdd(aOut) {
          reader.add(aOut)
          audioReaderOutput = aOut
        }
        let audioSettings: [String: Any] = [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVNumberOfChannelsKey: 2,
          AVSampleRateKey: 44100,
          AVEncoderBitRateKey: (config.audioBitrateKbps ?? 128) * 1000,
        ]
        let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        aIn.expectsMediaDataInRealTime = false
        if writer.canAdd(aIn) {
          writer.add(aIn)
          audioWriterInput = aIn
        }
      }

      self.lock.lock(); self.reader = reader; self.writer = writer; self.lock.unlock()

      guard reader.startReading() else {
        finish(.failure("Reader failed to start: \(reader.error?.localizedDescription ?? "")"))
        return
      }
      guard writer.startWriting() else {
        finish(.failure("Writer failed to start: \(writer.error?.localizedDescription ?? "")"))
        return
      }
      writer.startSession(atSourceTime: startTime)

      let group = DispatchGroup()
      let durationSec = max(CMTimeGetSeconds(dur), 0.001)
      let startSec = CMTimeGetSeconds(startTime)

      // Video pump. Progress is throttled: emitting per frame would mean a file
      // stat + a main-thread hop + a platform-channel message ~1800 times for a
      // 60s/30fps clip, starving the UI. (Android polls every 250ms.)
      var lastEmit = Date.distantPast
      group.enter()
      // `[weak self]` is load-bearing, not hygiene: the writer is a stored
      // property, the writer owns this input, and the input owns this block —
      // capturing `self` strongly closes the ring and pins the engine (plus its
      // encode session) for as long as the input keeps the block. Every exit
      // path must still `markAsFinished()` + `leave()`, or `group.notify` never
      // fires and the caller's future hangs.
      videoWriterInput.requestMediaDataWhenReady(on: videoQueue) { [weak self] in
        guard let self = self else {
          videoWriterInput.markAsFinished()
          group.leave()
          return
        }
        autoreleasepool {
          while videoWriterInput.isReadyForMoreMediaData {
            if self.isCancelled() {
              videoWriterInput.markAsFinished()
              group.leave()
              return
            }
            guard let sample = videoReaderOutput.copyNextSampleBuffer() else {
              videoWriterInput.markAsFinished()
              group.leave()
              return
            }
            let now = Date()
            if now.timeIntervalSince(lastEmit) >= Self.progressIntervalSec {
              lastEmit = now
              let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
              let progress = min(max((pts - startSec) / durationSec, 0), 1)
              let outBytes =
                (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int64)
                ?? 0
              self.onProgress?([
                "id": id,
                "progress": progress,
                "estimatedRemainingMs": NSNull(),
                "currentOutputBytes": outBytes,
              ])
            }
            videoWriterInput.append(sample)
          }
        }
      }

      // Audio pump.
      if let aIn = audioWriterInput, let aOut = audioReaderOutput {
        group.enter()
        aIn.requestMediaDataWhenReady(on: audioQueue) { [weak self] in
          guard let self = self else {
            aIn.markAsFinished()
            group.leave()
            return
          }
          while aIn.isReadyForMoreMediaData {
            if self.isCancelled() {
              aIn.markAsFinished()
              group.leave()
              return
            }
            if let sample = aOut.copyNextSampleBuffer() {
              aIn.append(sample)
            } else {
              aIn.markAsFinished()
              group.leave()
              return
            }
          }
        }
      }

      group.notify(queue: self.videoQueue) { [weak self] in
        // A vanished engine is treated as a cancel: there is nobody left to hand
        // the output to, so tear the writer down instead of finalising a file no
        // one will read.
        guard let self = self, !self.isCancelled() else {
          reader.cancelReading()
          writer.cancelWriting()
          try? FileManager.default.removeItem(at: outURL)
          finish(.cancelled)
          return
        }
        if reader.status == .failed {
          // Abandoning a writing AVAssetWriter leaks its encode session and
          // leaves a half-written file in the cache.
          writer.cancelWriting()
          try? FileManager.default.removeItem(at: outURL)
          finish(.failure(reader.error?.localizedDescription ?? "Reader failed"))
          return
        }
        writer.finishWriting {
          if writer.status == .completed {
            let compressedSize =
              (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int64) ?? 0
            if config.keepOriginalIfLarger && compressedSize >= originalSize {
              try? FileManager.default.removeItem(at: outURL)
              finish(.success([
                "id": id, "outputPath": path,
                "originalSizeBytes": originalSize, "compressedSizeBytes": originalSize,
                "width": srcW, "height": srcH, "durationMs": durationMs,
                "codec": usedCodec, "skipped": true,
              ]))
            } else {
              // Measure the file we wrote rather than echoing the source: a short
              // output is the signature of a truncated encode (CLAUDE.md §12.1).
              let written = AVURLAsset(url: outURL)
              let outDurationMs = Int64(CMTimeGetSeconds(written.duration) * 1000)
              let hasAudio = !written.tracks(withMediaType: .audio).isEmpty
              finish(.success([
                "id": id, "outputPath": outURL.path,
                "originalSizeBytes": originalSize, "compressedSizeBytes": compressedSize,
                "width": tw, "height": th,
                "durationMs": outDurationMs > 0 ? outDurationMs : durationMs,
                "frameRate": fps, "hasAudio": hasAudio,
                "codec": usedCodec, "skipped": false,
              ]))
            }
          } else {
            try? FileManager.default.removeItem(at: outURL)
            finish(.failure(writer.error?.localizedDescription ?? "Writer failed"))
          }
        }
      }
  }

  // MARK: - Cancel

  func cancel(id: String?) {
    lock.lock()
    if id == nil || id == activeId {
      cancelled = true
    } else {
      // Either already finished, or it hasn't registered yet — remember it so
      // `compress` starts out cancelled. Dart issues one compress at a time, so
      // the latest id is enough (matches the Android engine).
      preCancelledId = id
    }
    lock.unlock()
  }

  /// Cancel whatever is running. Used on engine detach, where there is no id to
  /// target — the pumps observe `cancelled` and unwind on their own queues.
  func cancelAll() {
    cancel(id: nil)
  }

  private func isCancelled() -> Bool {
    lock.lock(); defer { lock.unlock() }
    return cancelled
  }

  // MARK: - Helpers

  private func clampDuration(_ full: Int64, _ config: CompressionConfig) -> Int64 {
    if let s = config.trimStartMs, let e = config.trimEndMs { return max(e - s, 1) }
    return full
  }

  private func supportsHEVCEncoding() -> Bool {
    if #available(iOS 11.0, *) {
      return AVAssetExportSession.allExportPresets().contains(AVAssetExportPresetHEVCHighestQuality)
    }
    return false
  }

  /// Release the finished job's reader/writer. Split out of `compress` so
  /// `finish` can call it through an optional `self`.
  private func clearActiveJob() {
    lock.lock()
    activeId = nil
    reader = nil
    writer = nil
    lock.unlock()
  }

  private func beginBackgroundTask() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      // UIKit retains the expiration handler until the task ends, so a strong
      // `self` here would keep the engine alive for the whole export.
      self.bgTask = UIApplication.shared.beginBackgroundTask(withName: "flutter_compress") {
        [weak self] in self?.endBackgroundTask()
      }
    }
  }

  private func endBackgroundTask() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.bgTask != .invalid else { return }
      UIApplication.shared.endBackgroundTask(self.bgTask)
      self.bgTask = .invalid
    }
  }

  deinit {
    // Now that the handlers above are weak, a task outstanding at dealloc would
    // never be ended — and UIKit kills the app when one expires unended. Capture
    // the identifier only, so this doesn't resurrect `self`.
    let outstanding = bgTask
    if outstanding != .invalid {
      DispatchQueue.main.async { UIApplication.shared.endBackgroundTask(outstanding) }
    }
  }
}
