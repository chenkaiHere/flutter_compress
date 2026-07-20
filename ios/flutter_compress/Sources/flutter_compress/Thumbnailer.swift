import AVFoundation
import UIKit

/// Extracts a single JPEG thumbnail frame from a video.
enum Thumbnailer {
  static func generate(
    dir: URL, path: String, positionMs: Int64, quality: Int, maxWidth: Int?
  ) throws -> String {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: path)))
    generator.appliesPreferredTrackTransform = true
    if let maxWidth = maxWidth {
      generator.maximumSize = CGSize(width: maxWidth, height: 0)
    }
    let cg = try generator.copyCGImage(
      at: CMTime(value: positionMs, timescale: 1000), actualTime: nil)
    guard let data = UIImage(cgImage: cg).jpegData(compressionQuality: CGFloat(quality) / 100.0)
    else {
      throw NSError(
        domain: "flutter_compress", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "JPEG encode failed"])
    }
    let out = dir.appendingPathComponent("thumb_\(Int(Date().timeIntervalSince1970 * 1000)).jpg")
    try data.write(to: out)
    return out.path
  }
}
