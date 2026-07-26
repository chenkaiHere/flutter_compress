import Foundation

/// The plugin's private scratch directory for intermediate outputs/thumbnails.
enum PluginFiles {
  static func cacheDir() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("flutter_compress")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  static func clearCache() {
    let items =
      (try? FileManager.default.contentsOfDirectory(at: cacheDir(), includingPropertiesForKeys: nil))
      ?? []
    for item in items { try? FileManager.default.removeItem(at: item) }
  }

  /// Compose the output URL. The name is `outputName` (extension stripped — the
  /// caller's contract is "base name only") or the source's base name plus a
  /// timestamp; `ext` (without dot) is always appended so it matches the bytes
  /// written. Writes into `outputDir` when it's a real writable directory,
  /// otherwise the plugin cache.
  static func resolveOutput(
    outputDir: String?, outputName: String?, sourcePath: String, ext: String
  ) -> URL {
    let base: String
    if let name = outputName, !name.isEmpty {
      base = ((name as NSString).lastPathComponent as NSString).deletingPathExtension
    } else {
      let srcBase = ((sourcePath as NSString).lastPathComponent as NSString).deletingPathExtension
      base = "\(srcBase)_\(Int(Date().timeIntervalSince1970 * 1000))"
    }
    let fileName = "\(base).\(ext)"
    if let dir = outputDir, dir.hasPrefix("/") {
      let dirURL = URL(fileURLWithPath: dir, isDirectory: true)
      try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
      if FileManager.default.isWritableFile(atPath: dir) {
        return dirURL.appendingPathComponent(fileName)
      }
    }
    return cacheDir().appendingPathComponent(fileName)
  }
}
