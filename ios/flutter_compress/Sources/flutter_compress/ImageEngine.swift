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

  static func compress(
    path: String, config: ImageConfig, outputDir: String?, outputName: String?
  ) throws -> [String: Any] {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
      throw err("Cannot read image")
    }
    let originalSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0

    // A nil format keeps the source's format. ImageIO can't encode WebP → JPEG;
    // JPEG stays JPEG, PNG stays PNG. (JPEG/HEIC have no lossless mode, so
    // lossless just encodes them at max quality below.)
    let requested = config.format ?? sourceFormat(src)
    var effective = requested == "webp" ? "jpeg" : requested
    var uti = self.uti(for: effective)
    if effective == "heic" && CGImageDestinationCreateWithData(
      NSMutableData(), uti as CFString, 1, nil) == nil {
      effective = "jpeg"
      uti = self.uti(for: "jpeg")
    }
    let lossy = effective != "png"
    // Lossless: PNG is truly lossless; JPEG/HEIC keep their format at max quality.
    let quality = config.lossless ? 100 : config.quality

    // Initial max pixel size from the requested caps (0 = keep source size).
    var maxPixel = maxPixelSize(src, config.maxWidth, config.maxHeight)
    let exif = config.keepExif ? metadata(from: src) : nil
    // A target size can't be honored losslessly — ignore it in that case.
    let target = config.lossless ? nil : config.targetSizeKB.map { $0 * 1024 }

    var image = try thumbnail(src, maxPixel)
    var data = fit(image, uti, lossy, quality, target, exif)
    var tries = 0
    while let t = target, data.count > t, tries < 5, image.width > 32 {
      maxPixel = Int(Double(max(image.width, image.height)) * 0.75)
      image = try thumbnail(src, maxPixel)
      data = fit(image, uti, lossy, quality, target, exif)
      tries += 1
    }

    // Re-encoding can end up larger than the source (already-compressed input,
    // or lossless). If so, hand back the untouched original.
    if config.keepOriginalIfLarger && Int64(data.count) >= originalSize {
      let src = try? info(path: path)
      return [
        "outputPath": path,
        "originalSizeBytes": originalSize,
        "compressedSizeBytes": originalSize,
        "width": (src?["width"] as? Int) ?? image.width,
        "height": (src?["height"] as? Int) ?? image.height,
        "format": (src?["format"] as? String) ?? effective,
        "skipped": true,
      ]
    }

    let dest = PluginFiles.resolveOutput(
      outputDir: outputDir, outputName: outputName, sourcePath: path, ext: ext(effective))
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
      "skipped": false,
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

  /// Detect the source image's format (used when no format is requested).
  private static func sourceFormat(_ src: CGImageSource) -> String {
    switch (CGImageSourceGetType(src) as String?)?.lowercased() {
    case let t? where t.contains("png"): return "png"
    case let t? where t.contains("webp"): return "webp"
    case let t? where t.contains("heic") || t.contains("heif"): return "heic"
    default: return "jpeg"
    }
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
