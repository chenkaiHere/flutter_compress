import CoreGraphics
import Foundation
import ImageIO

/// Native image compression via ImageIO (CGImageSource/Destination). No FFmpeg,
/// no Dart software decode. For a target size it searches the quality and
/// downscales if needed — fast, so it lands accurately at/under the target.
enum ImageEngine {

  private static let minQuality = 1
  private static let maxQuality = 100
  private static let maxDownscales = 5
  private static let minSide = 32

  static func info(path: String) throws -> [String: Any] {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
      throw err("Cannot read image")
    }
    let meta = try probe(src)
    let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
    return [
      "path": path,
      "width": meta.width,
      "height": meta.height,
      "sizeBytes": size,
      "format": meta.format,
    ]
  }

  static func compress(
    path: String, config: ImageConfig, outputDir: String?, outputName: String?
  ) throws -> [String: Any] {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
      throw err("Cannot read image")
    }
    let originalSize =
      (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
    let source = try probe(src)

    // A nil format keeps the source's format. ImageIO can't encode WebP → JPEG;
    // JPEG stays JPEG, PNG stays PNG. (JPEG/HEIC have no lossless mode, so
    // lossless just encodes them at max quality below.)
    let requested = config.format ?? source.format
    var effective = requested == "webp" ? "jpeg" : requested
    var uti = self.uti(for: effective)
    if effective == "heic"
      && CGImageDestinationCreateWithData(NSMutableData(), uti as CFString, 1, nil) == nil
    {
      effective = "jpeg"
      uti = self.uti(for: "jpeg")
    }
    let lossy = effective != "png"
    // Lossless: PNG is truly lossless; JPEG/HEIC keep their format at max quality.
    let quality = config.lossless ? maxQuality : config.quality
    let exif = config.keepExif ? metadata(from: src) : nil
    // A target size can't be honored losslessly — ignore it in that case.
    let target = config.lossless ? nil : config.targetSizeKB.map { $0 * 1024 }

    // Per-axis caps, matching the Android engine: `maxWidth` bounds the width,
    // not the longest side. Aspect ratio is preserved, so asking the decoder for
    // a longest side of max(tw, th) yields exactly tw x th.
    let (tw, th) = targetDimensions(source.width, source.height, config.maxWidth, config.maxHeight)
    var image = try thumbnail(src, max(tw, th))
    var fitted = try fit(image, uti, lossy, quality, target, exif, minQuality)
    var tries = 0
    while let limit = target, fitted.data.count > limit, tries < maxDownscales, image.width > minSide {
      // Resample the image we already decoded instead of re-decoding the file.
      image = try resized(image, image.width * 3 / 4, image.height * 3 / 4)
      // A smaller image fits at least the quality the last round reached.
      fitted = try fit(image, uti, lossy, quality, target, exif, fitted.quality)
      tries += 1
    }
    let data = fitted.data

    // Re-encoding can end up larger than the source (already-compressed input,
    // or lossless). If so, hand back the untouched original.
    if config.keepOriginalIfLarger && Int64(data.count) >= originalSize {
      return [
        "outputPath": path,
        "originalSizeBytes": originalSize,
        "compressedSizeBytes": originalSize,
        "width": source.width,
        "height": source.height,
        "format": source.format,
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

  // MARK: - Source inspection

  /// Source dimensions (already oriented) and format.
  private struct Probe {
    let width: Int
    let height: Int
    let format: String
  }

  private static func probe(_ src: CGImageSource) throws -> Probe {
    guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
      throw err("Cannot read image properties")
    }
    let w = (props[kCGImagePropertyPixelWidth] as? Int) ?? 0
    let h = (props[kCGImagePropertyPixelHeight] as? Int) ?? 0
    guard w > 0, h > 0 else { throw err("Cannot read image dimensions") }
    // EXIF orientations 5–8 swap the axes; report what the user actually sees.
    let orientation = (props[kCGImagePropertyOrientation] as? Int) ?? 1
    let swap = orientation >= 5 && orientation <= 8
    return Probe(
      width: swap ? h : w, height: swap ? w : h, format: sourceFormat(src))
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

  // MARK: - Decode & resize

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

  /// Resample an already-decoded image — far cheaper than decoding the file again.
  private static func resized(_ image: CGImage, _ w: Int, _ h: Int) throws -> CGImage {
    let space =
      (image.colorSpace?.model == .rgb ? image.colorSpace : nil) ?? CGColorSpaceCreateDeviceRGB()
    guard
      let ctx = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw err("Could not create resize context") }
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let out = ctx.makeImage() else { throw err("Could not resize image") }
    return out
  }

  private static func targetDimensions(
    _ w: Int, _ h: Int, _ maxW: Int?, _ maxH: Int?
  ) -> (Int, Int) {
    var fw = Double(w)
    var fh = Double(h)
    if let maxW = maxW, fw > Double(maxW) {
      let scale = Double(maxW) / fw
      fw *= scale
      fh *= scale
    }
    if let maxH = maxH, fh > Double(maxH) {
      let scale = Double(maxH) / fh
      fw *= scale
      fh *= scale
    }
    return (max(1, Int(fw)), max(1, Int(fh)))
  }

  // MARK: - Encode

  private struct Encoded {
    let data: Data
    let quality: Int
  }

  /// The highest-quality encode that fits `target`.
  ///
  /// Tries the ceiling first: an image that already fits costs a **single**
  /// encode instead of a full binary search. Otherwise binary-searches
  /// `[minQuality, maxQuality)`. If even `minQuality` overflows, the oversized
  /// result comes back so the caller can downscale and retry.
  // Seven positional parameters is over SwiftLint's threshold. They are the
  // complete input to one quality search and are only ever passed together from
  // two call sites; bundling them into a struct would add a type that exists
  // solely to satisfy a counter.
  // swiftlint:disable:next function_parameter_count
  private static func fit(
    _ image: CGImage, _ uti: String, _ lossy: Bool, _ quality: Int, _ target: Int?,
    _ exif: [CFString: Any]?, _ minQuality: Int
  ) throws -> Encoded {
    guard lossy, let target = target else {
      let q = lossy ? quality : maxQuality
      return Encoded(data: try encode(image, uti, q, exif), quality: q)
    }
    let ceiling = try encode(image, uti, maxQuality, exif)
    if ceiling.count <= target { return Encoded(data: ceiling, quality: maxQuality) }

    var lo = minQuality
    var hi = maxQuality - 1
    var best: Data?
    var bestQuality = minQuality
    while lo <= hi {
      let q = (lo + hi) / 2
      let encoded = try encode(image, uti, q, exif)
      if encoded.count <= target {
        best = encoded
        bestQuality = q
        lo = q + 1
      } else {
        hi = q - 1
      }
    }
    if let best = best { return Encoded(data: best, quality: bestQuality) }
    return Encoded(data: try encode(image, uti, minQuality, exif), quality: minQuality)
  }

  private static func encode(
    _ image: CGImage, _ uti: String, _ quality: Int, _ exif: [CFString: Any]?
  ) throws -> Data {
    let out = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(out, uti as CFString, 1, nil) else {
      throw err("No encoder available for \(uti)")
    }
    var props: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: Double(quality) / 100.0
    ]
    if let exif = exif { props.merge(exif) { a, _ in a } }
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    // Never return empty data: that would be written out as a 0-byte file and
    // reported as a successful 100% compression.
    guard CGImageDestinationFinalize(dest), out.length > 0 else {
      throw err("Image encoding failed")
    }
    return out as Data
  }

  private static func metadata(from src: CGImageSource) -> [CFString: Any] {
    let all = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] ?? [:]
    var out: [CFString: Any] = [:]
    if var exif = all[kCGImagePropertyExifDictionary] as? [CFString: Any] {
      // These describe the *source* pixel size; after a resize they'd be stale.
      exif.removeValue(forKey: kCGImagePropertyExifPixelXDimension)
      exif.removeValue(forKey: kCGImagePropertyExifPixelYDimension)
      out[kCGImagePropertyExifDictionary] = exif
    }
    if let gps = all[kCGImagePropertyGPSDictionary] { out[kCGImagePropertyGPSDictionary] = gps }
    // Make/Model/DateTime live here — keep them so the tag set matches Android's.
    if let tiff = all[kCGImagePropertyTIFFDictionary] { out[kCGImagePropertyTIFFDictionary] = tiff }
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
