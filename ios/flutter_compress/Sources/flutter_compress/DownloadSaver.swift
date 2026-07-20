import Foundation

/// iOS apps are sandboxed and have no shared "Downloads" folder — copy into the
/// app's Documents directory instead. With `UIFileSharingEnabled` /
/// `LSSupportsOpeningDocumentsInPlace` in Info.plist the file is then visible in
/// the Files app under "On My iPhone / <App>".
enum DownloadSaver {
  static func save(path: String, fileName: String?) throws -> String {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dest = docs.appendingPathComponent(fileName ?? (path as NSString).lastPathComponent)
    try? FileManager.default.removeItem(at: dest)
    try FileManager.default.copyItem(atPath: path, toPath: dest.path)
    return dest.path
  }
}
