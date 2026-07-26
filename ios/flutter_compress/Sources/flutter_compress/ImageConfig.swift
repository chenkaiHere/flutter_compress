import Foundation

/// Parsed mirror of the Dart `ImageCompressConfig`.
struct ImageConfig {
  /// Requested output format, or nil to keep the source's.
  let format: String?
  let quality: Int
  let targetSizeKB: Int?
  let maxWidth: Int?
  let maxHeight: Int?
  let keepExif: Bool
  let lossless: Bool
  let keepOriginalIfLarger: Bool

  init(map: [String: Any]) {
    format = map["format"] as? String
    quality = (map["quality"] as? NSNumber)?.intValue ?? 85
    targetSizeKB = (map["targetSizeKB"] as? NSNumber)?.intValue
    maxWidth = (map["maxWidth"] as? NSNumber)?.intValue
    maxHeight = (map["maxHeight"] as? NSNumber)?.intValue
    keepExif = map["keepExif"] as? Bool ?? false
    lossless = map["lossless"] as? Bool ?? false
    keepOriginalIfLarger = map["keepOriginalIfLarger"] as? Bool ?? true
  }
}
