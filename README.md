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
| Frame-rate cap (`frameRate`)               |        ❌ ²          |         ✅         |       ❌ ²        |
| Audio: remove                              |          ✅           |         ✅         |    ❌ always off   |
| Audio: bitrate (`audioBitrateKbps`)        |        ❌ ³          |         ✅         |        ❌         |
| Trim (`trim`)                              |          ✅           |         ✅         |        ❌         |
| Thumbnail / info / estimate                |          ✅           |         ✅         |        ✅         |
| Progress / cancel / batch                  |          ✅           |         ✅         |        ✅         |
| Background compression                     | ✅ foreground service | ✅ background task |       n/a        |
| `saveToDownloads`                          |      MediaStore      |     Documents     | browser download |

¹ Web uses HEVC only where the browser supports WebCodecs HEVC encoding
(e.g. Safari, Chrome with HW HEVC); otherwise it falls back to H.264.

² Only iOS can decimate frames. Media3 has no frame-dropping effect, and the web
pipeline re-encodes every decoded frame — on both, `frameRate` only influences the
bitrate/keyframe maths. Read `result.frameRate` for what was actually written.

³ Media3 1.4.x exposes no audio-encoder settings, so Android encodes AAC at its
own default. The value still shapes the `targetSizeMB` budget.

Anything marked ❌ is **ignored**, not approximated — the result object reports what
actually happened (`result.frameRate`, `result.hasAudio`, `result.durationMs`).

### 🖼️ Image

| Capability                              |  Android   |    iOS    |       Web        |
|-----------------------------------------|:----------:|:---------:|:----------------:|
| Compress (target size / quality)        |     ✅      |     ✅     |        ✅         |
| JPEG / PNG / WebP                       |     ✅      |     ✅     |        ✅         |
| HEIC                                    |    ⚠️ ¹    |     ✅     |        ❌         |
| Resolution cap (`maxWidth`/`maxHeight`) |     ✅      |     ✅     |        ✅         |
| Keep EXIF (`keepExif`)                  |   ⚠️ JPEG only |  ✅   |        ❌         |
| `saveToDownloads`                       | MediaStore | Documents | browser download |

¹ Android only writes HEIC when a device HEIC encoder is present; otherwise the
engine falls back to JPEG (the actual format is reported on the result).

## Install

```yaml
dependencies:
  flutter_compress: ^1.5.0
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
| `keepAliveInBackground`            | Default on. Android starts a foreground service (with a notification) so the encode survives backgrounding; set `false` for foreground-only flows and no notification appears. Ignored on iOS and web. |

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
await api.releaseOutput(result.outputPath);  // frees one result (see below)
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

// Batch with progress, cancellation, and per-file error tolerance:
final token = CancellationToken();
final results = await api.compressImages(
  paths,
  const ImageCompressConfig(targetSizeKB: 300),
  onItemDone: (i, total) => print('${i + 1}/$total'),
  cancellationToken: token,
  continueOnError: true,                  // a bad file won't discard the rest
  onItemError: (i, path, e) => print('skipped $path: $e'),
);
```

## Errors

Everything throws a typed exception — a raw `PlatformException` never escapes.

```dart
try {
  await api.compressImage(path, config);
} on CompressCancelled {
  // cancelled (video or image)
} on ImageCompressException catch (e) {
  if (e.code == CompressErrorCode.imageCompressFailed) { /* … */ }
} on CompressException catch (e) {
  // any other failure from either API
}
```

Match on `CompressErrorCode` rather than raw strings — the constants are mirrored
on all three platforms, and the values are part of the public contract.

`CompressException` is the base; `VideoCompressException` / `ImageCompressException`
narrow it, and `CompressCancelled` is a marker both cancel types implement.

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

- **Android** — min SDK 24, `compileSdk 36`. Declares four permissions; see
  [Android permissions](#android-permissions) below — none of them are runtime
  permissions the plugin requests on its own.
- **iOS** — min 13.0. Uses `beginBackgroundTask` for a short background grace
  period. To make `saveToDownloads` files visible in the Files app, add
  `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` to `Info.plist`.
- **Web** — needs WebCodecs (Chrome/Edge 94+, Safari 16.4+). Inputs/outputs are
  `blob:` URLs; the vendored demux/mux JS (216 KB, see
  [THIRD_PARTY_NOTICES](assets/THIRD_PARTY_NOTICES.md)) loads lazily on first
  video compression — image compression never fetches it.
  Pick a file via `file_picker` and pass `xFile.path` (a `blob:` URL on web).
  **Call `releaseOutput(result.outputPath)`** once you've downloaded or uploaded a
  result — the browser otherwise holds the whole encoded file in memory for the
  life of the page (`clearCache()` releases every output at once).
  Try the [live demo](https://flutter-compress.ckdgdgdg.workers.dev/) to see it in action.

### Android permissions

Everything below merges into **your** app's manifest, so here is exactly what
arrives and why. The plugin never requests a runtime permission itself — that
timing is your product's call.

| Permission | Used for | Required? | If you remove it |
|---|---|---|---|
| `FOREGROUND_SERVICE` | Keeping a video encode alive while the app is backgrounded | Optional | Plugin logs a warning and encodes without background protection |
| `FOREGROUND_SERVICE_DATA_SYNC` | Same, mandatory typing on Android 14+ | Optional | Same as above |
| `POST_NOTIFICATIONS` | The notification that a foreground service must show | Optional | Android 13+ suppresses the notification; the encode still runs |
| `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion="28"`) | `saveToDownloads()` on Android 9 and below | Needed for `saveToDownloads` on API ≤ 28 | `saveToDownloads` fails on API ≤ 28; API 29+ is unaffected (MediaStore) |

**Image-only, or foreground-only?** Pass
`VideoCompressConfig(keepAliveInBackground: false)` so no service ever starts,
then strip the first three from the merged manifest:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"
    tools:node="remove" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"
    tools:node="remove" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"
    tools:node="remove" />
```

Image compression never starts the service, so removing them costs image-only
apps nothing.

### Native dependencies

| Dependency | Version | Unshrunk size | Notes |
|---|---|---|---|
| `androidx.media3:media3-transformer` + `-effect`, `-common`, `-muxer` | 1.4.1 | ~3.4 MB of AARs including transitive ExoPlayer modules | The video pipeline. R8 removes a large share of this; measure your own release build |
| `androidx.core:core-ktx` | 1.15.0 | ~0.2 MB | Almost always already present — Flutter pulls `androidx.core` in |
| `org.jetbrains.kotlinx:kotlinx-coroutines-android` | 1.8.1 | ~20 KB | Also usually already present |

iOS and web add **no** third-party native dependencies: iOS uses AVFoundation
and ImageIO from the SDK, web uses the browser's WebCodecs plus two vendored JS
bundles (see [THIRD_PARTY_NOTICES](assets/THIRD_PARTY_NOTICES.md) for sizes and
licences).

Versions are pinned to the ones actually tested rather than floated. Gradle
resolves conflicts upward, so an app declaring a newer Media3 still wins — but
the plugin won't silently adopt one. (Media3 changed the meaning of a
`DefaultMuxer.Factory` parameter inside its 1.x line once, which truncated every
output to 30 seconds while compiling perfectly cleanly.)

## Known limitations

- **Web (v1):** audio is dropped and `trim` is not yet applied.

## License

MIT — see [LICENSE](LICENSE).
