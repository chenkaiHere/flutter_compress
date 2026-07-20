# flutter_compress

High-quality **video compression** for Flutter — Android, iOS and Web — with
**no FFmpeg**. Each platform uses its native hardware-accelerated encoder, and
the API is built around *intent* ("make it ~10 MB", "half the bitrate") rather
than opaque quality presets.

> 中文文档见 [README.zh-CN.md](README.zh-CN.md)。

**🌐 [Try the live web demo in your browser →](https://flutter-compress.ckdgdgdg.workers.dev/)**

- **Android** → Media3 `Transformer` (Google-maintained, hardware-accelerated)
- **iOS** → explicit `AVAssetReader`/`AVAssetWriter` pipeline (real bitrate control)
- **Web** → WebCodecs + `mp4box.js` / `mp4-muxer` (tiny, ~0.2 MB, no FFmpeg)

## Highlights

- 🎯 **Target size** — ask for a size, the plugin
  derives the bitrate with identical math on every platform.
- 🎚️ **Or control quality** — a percentage of the source bitrate, or preset tiers.
- 🧬 **HEVC (H.265) with automatic H.264 fallback** on all platforms.
- 📉 Resolution cap, frame-rate cap, audio removal, trim, `÷16` alignment.
- 📡 Live **progress**, **cancellation**, sequential **batch**, **thumbnails**,
  and a pre-flight **size estimate**.
- 💾 `saveToDownloads` and a keep-original-if-larger guard.
- 🪶 No FFmpeg, no GPL, tiny footprint.

## Platform support

| Capability | Android | iOS | Web |
|---|:---:|:---:|:---:|
| Compress (target size / bitrate / quality) | ✅ | ✅ | ✅ |
| HEVC (H.265) with H.264 fallback | ✅ | ✅ | ✅¹ |
| Resolution cap (`maxWidth`/`maxHeight`) | ✅ | ✅ | ✅ |
| Frame-rate cap (`frameRate`) | ⚠️ best-effort | ✅ | ✅ |
| Audio: remove / bitrate | ✅ | ✅ | ⚠️ dropped (v1) |
| Trim (`trim`) | ✅ | ✅ | ❌ (v1) |
| Thumbnail / info / estimate | ✅ | ✅ | ✅ |
| Progress / cancel / batch | ✅ | ✅ | ✅ |
| Background compression | ✅ foreground service | ✅ background task | n/a |
| `saveToDownloads` | MediaStore | Documents | browser download |

¹ Web uses HEVC only where the browser supports WebCodecs HEVC encoding
(e.g. Safari, Chrome with HW HEVC); otherwise it falls back to H.264.

## Install

```yaml
dependencies:
  flutter_compress: ^1.0.0
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

| Field | Meaning |
|---|---|
| `targetSizeMB` | Desired output size; the plugin derives the bitrate. |
| `videoBitrateKbps` | Explicit average video bitrate. |
| `qualityPercent` | Output bitrate = `percent%` of the **source** bitrate (1–100). |
| `quality` | Preset tier: `high` / `medium` / `low` / `veryLow`. |
| `codec` | `h265` (default, auto-fallback) or `h264`. |
| `maxWidth` / `maxHeight` | Cap dimensions; aspect kept, only ever scales down. |
| `frameRate` | Cap the fps. |
| `removeAudio` / `audioBitrateKbps` | Drop or re-encode audio. |
| `trim` | `TrimRange(startMs, endMs)`. |
| `alignment` | `auto16` (default) rounds to `÷16` to avoid edge artifacts. |
| `keepOriginalIfLarger` | Return the original if compression wouldn't help. |

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
