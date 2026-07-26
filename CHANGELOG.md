# Changelog

## 1.1.1

- Add `outputName` (video & image); output name defaults to `<source>_<timestamp>`.
- Image `format` now keeps the source format by default; set it only to convert.
- Add image `lossless` and `keepOriginalIfLarger` (never makes a file bigger).
- Add video `container` (`auto` keeps the source where possible, else `mp4`).

## 1.1.0

- Add **image compression** — a separate API (`compressImage`, `ImageCompressConfig`).
- JPEG / PNG / WebP / HEIC, by target size or quality; engines: Bitmap / ImageIO / Canvas.

## 1.0.1

- Docs and pub.dev metadata polish. No API changes.

## 1.0.0

Initial release — native, FFmpeg-free **video compression** for Android, iOS & Web.

- Target size / bitrate / quality %; HEVC with H.264 fallback.
- Resolution & frame-rate caps, audio removal, trim, thumbnails, estimate.
- Progress, cancellation, batch, `saveToDownloads`.
