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

  var onProgress: (([String: Any]) -> Void)?

  private let lock = NSLock()
  private var reader: AVAssetReader?
  private var writer: AVAssetWriter?
  private var activeId: String?
  private var cancelled = false
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
    let srcW = info["width"] as! Int
    let srcH = info["height"] as! Int
    let durationMs = clampDuration(info["durationMs"] as! Int64, config)
    let (tw, th) = SizeMath.targetDimensions(srcW: srcW, srcH: srcH, config: config)
    let videoBps = SizeMath.videoBitrateBps(
      config: config, durationMs: durationMs,
      sourceBitrateKbps: info["bitrateKbps"] as! Int, targetHeight: th)
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
    cancelled = false
    lock.unlock()

    beginBackgroundTask()
    var didFinish = false
    let finish: (CompressionOutcome) -> Void = { [weak self] outcome in
      guard let self = self else { return }
      self.lock.lock()
      if didFinish { self.lock.unlock(); return }
      didFinish = true
      self.activeId = nil
      self.reader = nil
      self.writer = nil
      self.lock.unlock()
      self.endBackgroundTask()
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
        finish(.failure("Reader failed to start: \(reader.error?.localizedDescription ?? "")")); return
      }
      guard writer.startWriting() else {
        finish(.failure("Writer failed to start: \(writer.error?.localizedDescription ?? "")")); return
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
      videoWriterInput.requestMediaDataWhenReady(on: videoQueue) {
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
        aIn.requestMediaDataWhenReady(on: audioQueue) {
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

      group.notify(queue: self.videoQueue) {
        if self.isCancelled() {
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
              finish(.success([
                "id": id, "outputPath": outURL.path,
                "originalSizeBytes": originalSize, "compressedSizeBytes": compressedSize,
                "width": tw, "height": th, "durationMs": durationMs,
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
    }
    lock.unlock()
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

  private func beginBackgroundTask() {
    DispatchQueue.main.async {
      self.bgTask = UIApplication.shared.beginBackgroundTask(withName: "flutter_compress") {
        self.endBackgroundTask()
      }
    }
  }

  private func endBackgroundTask() {
    DispatchQueue.main.async {
      if self.bgTask != .invalid {
        UIApplication.shared.endBackgroundTask(self.bgTask)
        self.bgTask = .invalid
      }
    }
  }
}
