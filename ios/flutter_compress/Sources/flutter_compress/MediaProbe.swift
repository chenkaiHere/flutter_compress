import AVFoundation

/// Reads source video metadata. Separated for reuse and clarity.
enum MediaProbe {
  static func videoInfo(path: String) throws -> [String: Any] {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .video).first else {
      throw NSError(
        domain: "flutter_compress", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "No video track"])
    }
    let size = track.naturalSize.applying(track.preferredTransform)
    let fileSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
    return [
      "path": path,
      "width": Int(abs(size.width)),
      "height": Int(abs(size.height)),
      "durationMs": Int64(CMTimeGetSeconds(asset.duration) * 1000),
      "sizeBytes": fileSize,
      "bitrateKbps": Int(track.estimatedDataRate / 1000),
      "frameRate": Double(track.nominalFrameRate),
      "codec": NSNull(),
      "rotation": rotationDegrees(track.preferredTransform),
    ]
  }

  static func rotationDegrees(_ t: CGAffineTransform) -> Int {
    let angle = atan2(t.b, t.a) * 180 / .pi
    return (Int(angle.rounded()) + 360) % 360
  }
}
