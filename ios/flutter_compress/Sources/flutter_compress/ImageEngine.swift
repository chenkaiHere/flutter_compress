import Foundation
import ImageIO

/// Native image compression via ImageIO (CGImageSource/Destination). No FFmpeg,
/// no Dart software decode. For a target size it binary-searches the quality and
/// downscales if needed — fast, so it lands accurately at/under the target.
enum ImageEngine {

  static func info(path: String) throws -> [String: Any] {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
    else { throw err("Cannot read image") }
    let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
    var fmt: String?
    if let uti = CGImageSourceGetType(src) as String? { fmt = uti.components(separatedBy: ".").last }
    return [
      "path": path,
      "width": (props[kCGImagePropertyPixelWidth] as? Int) ?? 0,
      "height": (props[kCGImagePropertyPixelHeight] as? Int) ?? 0,
      "sizeBytes": size,
      "format": fmt as Any,
    ]
  }

  static func compress(path: String, config: ImageConfig, outputPath: String?) throws
    -> [String: Any]
  {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
      throw err("Cannot read image")
    }
    let originalSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0

    // ImageIO can't encode WebP; HEIC only where the device supports it.
    var effective = config.format == "webp" ? "jpeg" : config.format
    var uti = self.uti(for: effective)
    if effective == "heic" && CGImageDestinationCreateWithData(
      NSMutableData(), uti as CFString, 1, nil) == nil {
      effective = "jpeg"
      uti = self.uti(for: "jpeg")
    }
    let lossy = effective != "png"

    // Initial max pixel size from the requested caps (0 = keep source size).
    var maxPixel = maxPixelSize(src, config.maxWidth, config.maxHeight)
    let exif = config.keepExif ? metadata(from: src) : nil
    let target = config.targetSizeKB.map { $0 * 1024 }

    var image = try thumbnail(src, maxPixel)
    var data = fit(image, uti, lossy, config.quality, target, exif)
    var tries = 0
    while let t = target, data.count > t, tries < 5, image.width > 32 {
      maxPixel = Int(Double(max(image.width, image.height)) * 0.75)
      image = try thumbnail(src, maxPixel)
      data = fit(image, uti, lossy, config.quality, target, exif)
      tries += 1
    }

    let out = PluginFiles.cacheDir()
      .appendingPathComponent("img_\(Int(Date().timeIntervalSince1970 * 1000)).\(ext(effective))")
    let dest = (outputPath.map { URL(fileURLWithPath: $0) }) ?? out
    try? FileManager.default.createDirectory(
      at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: dest)

    return [
      "outputPath": dest.path,
      "originalSizeBytes": originalSize,
      "compressedSizeBytes": Int64(data.count),
      "width": image.width,
      "height": image.height,
      "format": effective,
    ]
  }

  // MARK: - Helpers

  /// Binary-search the quality for lossy formats; PNG encodes once (lossless).
  private static func fit(
    _ image: CGImage, _ uti: String, _ lossy: Bool, _ quality: Int, _ target: Int?,
    _ exif: [CFString: Any]?
  ) -> Data {
    guard lossy, let target = target else {
      return encode(image, uti, lossy ? quality : 100, exif)
    }
    var lo = 1
    var hi = 100
    var best: Data?
    while lo <= hi {
      let q = (lo + hi) / 2
      let d = encode(image, uti, q, exif)
      if d.count <= target {
        best = d
        lo = q + 1
      } else {
        hi = q - 1
      }
    }
    return best ?? encode(image, uti, 1, exif)
  }

  private static func encode(
    _ image: CGImage, _ uti: String, _ quality: Int, _ exif: [CFString: Any]?
  ) -> Data {
    let out = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(out, uti as CFString, 1, nil) else {
      return Data()
    }
    var props: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: Double(quality) / 100.0
    ]
    if let exif = exif { props.merge(exif) { a, _ in a } }
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    CGImageDestinationFinalize(dest)
    return out as Data
  }

  private static func thumbnail(_ src: CGImageSource, _ maxPixel: Int) throws -> CGImage {
    let opts: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,  // bake in orientation
      kCGImageSourceThumbnailMaxPixelSize: maxPixel,
    ]
    guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
      throw err("Could not decode image")
    }
    return img
  }

  /// The larger output side (capped by maxWidth/maxHeight), or the source's.
  private static func maxPixelSize(_ src: CGImageSource, _ maxW: Int?, _ maxH: Int?) -> Int {
    let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
    let w = (props?[kCGImagePropertyPixelWidth] as? Int) ?? 4096
    let h = (props?[kCGImagePropertyPixelHeight] as? Int) ?? 4096
    var longest = max(w, h)
    if let maxW = maxW { longest = min(longest, max(maxW, maxH ?? maxW)) }
    if let maxH = maxH { longest = min(longest, max(maxH, maxW ?? maxH)) }
    return longest
  }

  private static func metadata(from src: CGImageSource) -> [CFString: Any] {
    let all = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] ?? [:]
    var out: [CFString: Any] = [:]
    if let e = all[kCGImagePropertyExifDictionary] { out[kCGImagePropertyExifDictionary] = e }
    if let g = all[kCGImagePropertyGPSDictionary] { out[kCGImagePropertyGPSDictionary] = g }
    return out
  }

  private static func uti(for format: String) -> String {
    switch format {
    case "png": return "public.png"
    case "heic": return "public.heic"
    default: return "public.jpeg"
    }
  }

  private static func ext(_ format: String) -> String {
    switch format {
    case "png": return "png"
    case "heic": return "heic"
    default: return "jpg"
    }
  }

  private static func err(_ msg: String) -> NSError {
    NSError(domain: "flutter_compress", code: 3, userInfo: [NSLocalizedDescriptionKey: msg])
  }
}
