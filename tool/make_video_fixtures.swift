// Generates the video fixtures for example/integration_test (CLAUDE.md §12.4).
//
//   swiftc -O tool/make_video_fixtures.swift -o /tmp/mkfix && \
//     /tmp/mkfix example/integration_test/fixtures
//
// macOS only (AVFoundation). The outputs are committed, so this only needs
// re-running if the fixtures themselves have to change.
//
// Every frame is four solid quadrants — red, green, blue, yellow (TL, TR, BL,
// BR in *stored* coordinates). That makes the picture itself checkable: a
// correctly downscaled output still shows all four colours in their quadrants,
// while a crop collapses to a single colour. Checking dimensions alone cannot
// tell those apart, which is how an iOS crop-instead-of-scale bug shipped (#5).
import AVFoundation
import CoreVideo
import Foundation

let width = 1920, height = 1080
let fps: Int32 = 30, seconds = 6   // long enough for the cancel/progress tests

func makeVideo(_ url: URL, transform: CGAffineTransform) throws {
  try? FileManager.default.removeItem(at: url)
  let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
  let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
  ])
  input.expectsMediaDataInRealTime = false
  // Stored as the track's preferredTransform — exactly what a phone writes for
  // portrait footage.
  input.transform = transform
  let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: width,
      kCVPixelBufferHeightKey as String: height,
    ])
  writer.add(input)
  guard writer.startWriting() else { throw writer.error ?? NSError(domain: "fixture", code: 1) }
  writer.startSession(atSourceTime: .zero)

  for frame in 0..<(Int(fps) * seconds) {
    while !input.isReadyForMoreMediaData { usleep(1_000) }
    var out: CVPixelBuffer?
    guard let pool = adaptor.pixelBufferPool,
          CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out) == kCVReturnSuccess,
          let buffer = out else { throw NSError(domain: "fixture", code: 2) }
    CVPixelBufferLockBaseAddress(buffer, [])
    let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
    let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
    for y in 0..<height {
      let row = base + y * rowBytes
      let bottom = y >= height / 2
      for x in 0..<width {
        let right = x >= width / 2
        let (r, g, b): (UInt8, UInt8, UInt8) =
          !right && !bottom ? (230, 20, 20)     // TL red
          : right && !bottom ? (20, 200, 20)    // TR green
          : !right && bottom ? (20, 20, 230)    // BL blue
          : (230, 220, 20)                      // BR yellow
        let p = row + x * 4                     // BGRA
        p[0] = b; p[1] = g; p[2] = r; p[3] = 255
      }
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])
    adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: fps))
  }
  input.markAsFinished()
  let done = DispatchSemaphore(value: 0)
  writer.finishWriting { done.signal() }
  done.wait()
  if writer.status != .completed { throw writer.error ?? NSError(domain: "fixture", code: 3) }
}

let dir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
try makeVideo(dir.appendingPathComponent("quadrants_landscape.mp4"), transform: .identity)
// iPhone-style portrait: stored landscape, rotated 90° for display (with the
// translation phones include). Displays as 1080x1920.
try makeVideo(
  dir.appendingPathComponent("quadrants_portrait.mp4"),
  transform: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: CGFloat(height), ty: 0))
print("wrote fixtures to \(dir.path)")
