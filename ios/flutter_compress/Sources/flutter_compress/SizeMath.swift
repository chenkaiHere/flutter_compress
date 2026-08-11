import Foundation

/// Turns a `CompressionConfig` intent into concrete encoder numbers. Mirrors
/// the Android `SizeMath` so both platforms hit the same target sizes.
enum SizeMath {

  private static let sizeSafety = 0.95
  private static let minVideoBps = 100_000

  /// Target video bitrate in bits/sec.
  static func videoBitrateBps(
    config: CompressionConfig,
    durationMs: Int64,
    sourceBitrateKbps: Int,
    targetHeight: Int
  ) -> Int {
    if let mb = config.targetSizeMB {
      let totalBits = Double(mb) * 8.0 * 1024.0 * 1024.0
      let durationSec = max(Double(durationMs) / 1000.0, 0.001)
      let audioBps = config.removeAudio ? 0 : (config.audioBitrateKbps ?? 128) * 1000
      let audioBits = Double(audioBps) * durationSec
      let videoBits = totalBits * sizeSafety - audioBits
      return max(Int(videoBits / durationSec), minVideoBps)
    }
    if let kbps = config.videoBitrateKbps {
      return kbps * 1000
    }

    // Quality as a percentage of the SOURCE bitrate. An explicit qualityPercent
    // wins over the preset tier (more specific intent).
    let percent = min(max(config.qualityPercent ?? presetPercent(config.quality), 1), 100)
    let srcBps = sourceBitrateKbps * 1000
    if srcBps > 0 {
      // percent <= 100 guarantees we never re-inflate above the source.
      return max(Int(Double(srcBps) * Double(percent) / 100.0), minVideoBps)
    }
    // Source bitrate unknown: resolution-based baseline (50% == "medium").
    let width = targetHeight * 16 / 9
    let baselineMedium = Double(width * targetHeight * 30) * 0.12
    return max(Int(baselineMedium * Double(percent) / 50.0), minVideoBps)
  }

  /// Preset tier -> percentage of source bitrate.
  private static func presetPercent(_ quality: String) -> Int {
    switch quality {
    case "high": return 80
    case "low": return 30
    case "veryLow": return 15
    default: return 50
    }
  }

  /// Output width/height: preserve aspect, only downscale to caps, then align.
  static func targetDimensions(srcW: Int, srcH: Int, config: CompressionConfig) -> (Int, Int) {
    if srcW <= 0 || srcH <= 0 { return (srcW, srcH) }
    // No cap requested → keep the source exactly. Aligning here would round 1080
    // *up* to 1088, breaking the "only ever scale down" promise and forcing a
    // needless full-frame rescale.
    if config.maxWidth == nil && config.maxHeight == nil { return (srcW, srcH) }

    var w = Double(srcW)
    var h = Double(srcH)
    if let maxW = config.maxWidth, w > Double(maxW) {
      let s = Double(maxW) / w
      w *= s
      h *= s
    }
    if let maxH = config.maxHeight, h > Double(maxH) {
      let s = Double(maxH) / h
      w *= s
      h *= s
    }
    return align(Int(w), Int(h), config.alignment)
  }

  private static func align(_ w: Int, _ h: Int, _ alignment: String) -> (Int, Int) {
    // Always round *down* so alignment can never upscale.
    let m = alignment == "auto16" ? 16 : 2
    func down(_ v: Int) -> Int { max(v / m * m, m) }
    return (down(w), down(h))
  }
}
