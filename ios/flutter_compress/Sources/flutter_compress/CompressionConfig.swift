import Foundation

/// Parsed mirror of the Dart `VideoCompressConfig`.
struct CompressionConfig {
  let quality: String
  let qualityPercent: Int?
  let targetSizeMB: Int?
  let videoBitrateKbps: Int?
  let codec: String
  let maxWidth: Int?
  let maxHeight: Int?
  let frameRate: Double?
  let removeAudio: Bool
  let audioBitrateKbps: Int?
  let trimStartMs: Int64?
  let trimEndMs: Int64?
  let alignment: String
  let keepOriginalIfLarger: Bool

  init(map: [String: Any]) {
    quality = map["quality"] as? String ?? "medium"
    qualityPercent = (map["qualityPercent"] as? NSNumber)?.intValue
    targetSizeMB = (map["targetSizeMB"] as? NSNumber)?.intValue
    videoBitrateKbps = (map["videoBitrateKbps"] as? NSNumber)?.intValue
    codec = map["codec"] as? String ?? "h265"
    maxWidth = (map["maxWidth"] as? NSNumber)?.intValue
    maxHeight = (map["maxHeight"] as? NSNumber)?.intValue
    frameRate = (map["frameRate"] as? NSNumber)?.doubleValue
    removeAudio = map["removeAudio"] as? Bool ?? false
    audioBitrateKbps = (map["audioBitrateKbps"] as? NSNumber)?.intValue
    let trim = map["trim"] as? [String: Any]
    trimStartMs = (trim?["startMs"] as? NSNumber)?.int64Value
    trimEndMs = (trim?["endMs"] as? NSNumber)?.int64Value
    alignment = map["alignment"] as? String ?? "auto16"
    keepOriginalIfLarger = map["keepOriginalIfLarger"] as? Bool ?? true
  }
}

/// The three ways a `compress` call can end.
enum CompressionOutcome {
  case success([String: Any])
  case cancelled
  case failure(String)
}
