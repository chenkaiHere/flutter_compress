# flutter_compress

[![pub package](https://img.shields.io/pub/v/flutter_compress.svg)](https://pub.dev/packages/flutter_compress)
[![platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-blue.svg)](https://pub.dev/packages/flutter_compress)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**One plugin to compress both video and images — on Android, iOS *and* Web — with no FFmpeg.**

Every platform uses its own hardware-accelerated encoder, so output is fast,
small, and native-quality — with **no 20 MB FFmpeg binary, no GPL, and nothing
extra to ship**. And the API speaks *intent* — "make it ~10 MB", "half the
bitrate", "under 200 KB" — instead of making you guess at opaque quality knobs.

> 中文文档见 [README.zh-CN.md](README.zh-CN.md)。

**🌐 [Try the live web demo in your browser →](https://flutter-compress.ckdgdgdg.workers.dev/)**

| | |
|:---:|:---:|
| ![Preview 1](https://flutter-compress.ckdgdgdg.workers.dev/img/compress_en_1.jpeg) | ![Preview 2](https://flutter-compress.ckdgdgdg.workers.dev/img/compress_en_2.jpeg) |

## Why flutter_compress?

- 🪶 **No FFmpeg, no GPL, no bloat** — nothing to bundle beyond the OS encoders your users already have. Your app stays small and license-clean.
- 🌍 **One API, three platforms** — the same Dart code runs on Android, iOS **and** the browser (via WebCodecs). Most alternatives skip Web entirely.
- 🎯 **Hit a target size, precisely** — ask for a size and the plugin derives the bitrate with identical math on every platform.
- 🎬🖼️ **Video *and* images** — two dedicated, non-overlapping APIs (`compress` vs `compressImage`), each tuned for its medium.
- 📡 **Production-ready** — live progress, cancellation, sequential batching, background-safe on mobile, and a keep-original-if-larger guard.

## Under the hood

| Platform | Video engine | Image engine |
|---|---|---|
| **Android** | Media3 `Transformer` (Google-maintained, HW-accelerated) | `Bitmap` |
| **iOS** | explicit `AVAssetReader`/`AVAssetWriter` (real bitrate control) | ImageIO |
| **Web** | WebCodecs + `mp4box.js` / `mp4-muxer` (~0.2 MB, no FFmpeg) | Canvas |

## Features

### 🎬 Video — `compress`

- 🎯 **Target size**, or explicit **bitrate**, **quality %**, or **preset tiers**.
- 🧬 **HEVC (H.265) with automatic H.264 fallback** on all platforms.
- 📉 Resolution cap, frame-rate cap, audio removal, trim, `÷16` alignment.
- 🖼️ Thumbnails, media info, and a pre-flight **size estimate** (no encoding).
- 📡 Live progress, cancellation, and sequential batch.

### 🖼️ Image — `compressImage`

- 🎯 **Target size** (precise — the engine iterates on quality, then downscales) **or quality**.
- 🎞️ Formats: **JPEG · PNG · WebP · HEIC** (auto-fallback where unsupported).
- 📐 Resolution cap and optional **EXIF** keep (orientation, GPS…).
- ⚡ Millisecond-fast, single-image or batch.

## Platform support

### 🎬 Video

| Capability                                 |       Android        |        iOS        |       Web        |
|--------------------------------------------|:--------------------:|:-----------------:|:----------------:|
| Compress (target size / bitrate / quality) |          ✅           |         ✅         |        ✅         |
| HEVC (H.265) with H.264 fallback           |          ✅           |         ✅         |        ✅         |
| Resolution cap (`maxWidth`/`maxHeight`)    |          ✅           |         ✅         |        ✅         |
| Frame-rate cap (`frameRate`)               |          ⚠️          |         ✅         |        ✅         |
| Audio: remove / bitrate                    |          ✅           |         ✅         |        ⚠️        |
| Trim (`trim`)                              |          ✅           |         ✅         |        ❌         |
| Thumbnail / info / estimate                |          ✅           |         ✅         |        ✅         |
| Progress / cancel / batch                  |          ✅           |         ✅         |        ✅         |
| Background compression                     | ✅ foreground service | ✅ background task |       n/a        |
| `saveToDownloads`                          |      MediaStore      |     Documents     | browser download |

¹ Web uses HEVC only where the browser supports WebCodecs HEVC encoding
(e.g. Safari, Chrome with HW HEVC); otherwise it falls back to H.264.

### 🖼️ Image

| Capability                              |  Android   |    iOS    |       Web        |
|-----------------------------------------|:----------:|:---------:|:----------------:|
| Compress (target size / quality)        |     ✅      |     ✅     |        ✅         |
| JPEG / PNG / WebP                       |     ✅      |     ✅     |        ✅         |
| HEIC                                    |     ⚠️     |     ✅     |        ❌         |
| Resolution cap (`maxWidth`/`maxHeight`) |     ✅      |     ✅     |        ✅         |
| Keep EXIF (`keepExif`)                  |     ✅      |     ✅     |        ❌         |
| `saveToDownloads`                       | MediaStore | Documents | browser download |

¹ Android only writes HEIC when a device HEIC encoder is present; otherwise the
engine falls back to JPEG (the actual format is reported on the result).

## Install

```yaml
dependencies:
  flutter_compress: ^1.1.0
```

## Quick start

```dart
import 'package:flutter_compress/flutter_compress.dart';

final result = await FlutterCompress.instance.compress(
  inputPath,
  const VideoCompressConfig(
    targetSizeMB: 10,          // highest-priority size control
    codec: VideoCodec.h265,    // auto-falls-back to H.264
    maxWidth: 1280,            // downscale-only
    maxHeight: 1280,
  ),
  onProgress: (p) => debugPrint('${(p.progress * 100).toStringAsFixed(0)}%'),
);

print('saved ${result.savedPercent.toStringAsFixed(1)}% → ${result.outputPath}');
```

## Configuration

`VideoCompressConfig` — set **one** size/quality control; priority is:

`targetSizeMB` → `videoBitrateKbps` → `qualityPercent` → `quality`

| Field                              | Meaning                                                        |
|------------------------------------|----------------------------------------------------------------|
| `targetSizeMB`                     | Desired output size; the plugin derives the bitrate.           |
| `videoBitrateKbps`                 | Explicit average video bitrate.                                |
| `qualityPercent`                   | Output bitrate = `percent%` of the **source** bitrate (1–100). |
| `quality`                          | Preset tier: `high` / `medium` / `low` / `veryLow`.            |
| `codec`                            | `h265` (default, auto-fallback) or `h264`.                     |
| `maxWidth` / `maxHeight`           | Cap dimensions; aspect kept, only ever scales down.            |
| `frameRate`                        | Cap the fps.                                                   |
| `removeAudio` / `audioBitrateKbps` | Drop or re-encode audio.                                       |
| `trim`                             | `TrimRange(startMs, endMs)`.                                   |
| `alignment`                        | `auto16` (default) rounds to `÷16` to avoid edge artifacts.    |
| `keepOriginalIfLarger`             | Return the original if compression wouldn't help.              |
| `container`                        | `auto` (default) keeps the source container where the platform can (iOS `.mov`/`.mp4`; Android/Web → `.mp4`), or `mp4` to force it. |

## API

```dart
final api = FlutterCompress.instance;

// Probe & estimate (no encoding)
final VideoInfo info = await api.getVideoInfo(path);
final CompressionEstimate est = await api.estimate(path, config);

// Compress (single)
final token = CancellationToken();
final result = await api.compress(
  path, config,
  onProgress: (p) => print(p.progress),   // 0.0–1.0
  cancellationToken: token,
  outputDirectory: dir,                    // optional
  outputName: 'my_clip',                   // optional; no extension → auto-added
);
await token.cancel();                      // aborts the job above

// Batch (sequential), thumbnails, housekeeping
await api.compressAll(paths, config);
final String thumb = await api.getThumbnail(path, positionMs: 1000, maxWidth: 320);
final String saved = await api.saveToDownloads(result.outputPath);
await api.clearCache();

// Global progress feed (e.g. for a batch UI)
api.progressStream.listen((p) => print('${p.id} ${p.progress}'));
```

## Images

The image API is fully separate from the video one.

```dart
final api = FlutterCompress.instance;

// Probe (no encoding)
final ImageMeta meta = await api.getImageInfo(path);

// Compress to a target size (precise — images encode fast, so the engine
// binary-searches quality, then downscales if needed to land under it).
// With no `format`, the output keeps the source's format.
final ImageCompressResult r = await api.compressImage(
  path,
  const ImageCompressConfig(
    targetSizeKB: 200,          // highest-priority size control
    maxWidth: 2560,             // downscale-only
    maxHeight: 2560,
  ),
  outputDirectory: dir,         // optional; null → plugin cache
  outputName: 'my_photo',       // optional; no extension → auto-added
);
print('${r.format} ${r.width}x${r.height} • saved ${r.savedPercent.toStringAsFixed(1)}%');

// Convert format, control quality, go lossless, or batch:
await api.compressImage(path, const ImageCompressConfig(format: ImageFormat.webp, quality: 80));
await api.compressImageLossless(path);   // keep source format, pixel-for-pixel
await api.compressImages(paths, const ImageCompressConfig(targetSizeKB: 300));
```

`ImageCompressConfig` — priority is `lossless` → `targetSizeKB` → `quality`:

| Field                    | Meaning                                                       |
|--------------------------|---------------------------------------------------------------|
| `format`                 | `null` (default) keeps the **source** format; or `jpeg` / `png` / `webp` / `heic`. |
| `targetSizeKB`           | Desired output size; the engine iterates to land at/under it. |
| `quality`                | 1–100, used when `targetSizeKB` is null (ignored for PNG).    |
| `lossless`               | Encode losslessly (PNG truly lossless; JPEG stays JPEG at max quality). Ignores `quality`/`targetSizeKB`. |
| `maxWidth` / `maxHeight` | Cap dimensions; aspect kept, only scales down.                |
| `keepExif`               | Keep EXIF (orientation, GPS, …); default strips it.           |
| `keepOriginalIfLarger`   | Return the original (marked `skipped`) if compression wouldn't shrink it. Default on. |

## Platform setup

- **Android** — min SDK 24, `compileSdk 36`. The plugin declares
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `POST_NOTIFICATIONS`,
  and (for `saveToDownloads` on API ≤ 28) `WRITE_EXTERNAL_STORAGE`.
- **iOS** — min 13.0. Uses `beginBackgroundTask` for a short background grace
  period. To make `saveToDownloads` files visible in the Files app, add
  `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` to `Info.plist`.
- **Web** — needs WebCodecs (Chrome/Edge 94+, Safari 16.4+). Inputs/outputs are
  `blob:` URLs; the vendored demux/mux JS (~0.2 MB) loads lazily on first use.
  Pick a file via `file_picker` and pass `xFile.path` (a `blob:` URL on web).
  Try the [live demo](https://flutter-compress.ckdgdgdg.workers.dev/) to see it in action.

## Known limitations

- **Web (v1):** audio is dropped and `trim` is not yet applied.

## License

MIT — see [LICENSE](LICENSE).
