# Changelog

## 1.1.0

Adds **image compression** — a separate API from video, so the two never mix.

- `compressImage` / `compressImages` / `getImageInfo` with `ImageCompressConfig`.
- Formats: JPEG, PNG, WebP, HEIC (auto-fallback where a format isn't supported).
- Compress by **target size** (precise, iterative) or **quality**, plus resolution caps and optional EXIF keep.
- Engines: `Bitmap` (Android), ImageIO (iOS), Canvas (Web).
- Example app gains an image tab with the same responsive wide-screen layout.

## 1.0.1

- Docs and pub.dev metadata polish (`dart format`, shorter description). No API or behavior changes.

## 1.0.0

Initial release — native, FFmpeg-free video compression for Android, iOS & Web.

- Compress by target size, bitrate, quality %, or preset tier.
- HEVC (H.265) with automatic H.264 fallback on all platforms.
- Resolution / frame-rate caps, audio removal, trim, thumbnails, estimate.
- Live progress, cancellation, batch, and `saveToDownloads`.
- Engines: Media3 (Android), AVAssetReader/Writer (iOS), WebCodecs (Web).
