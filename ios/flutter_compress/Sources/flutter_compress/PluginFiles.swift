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
}
