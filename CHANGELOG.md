# Changelog

## 1.5.0

- Add `keepAliveInBackground` — set `false` to skip Android's foreground service
  and its notification.
- iOS: fix a retain cycle that leaked the engine; a cancel arriving before the
  job starts is no longer dropped.
- Web: `cancel()` with no id now works; `releaseOutput` no longer revokes your
  own input URL.
- Android: a missing `FOREGROUND_SERVICE` permission no longer crashes the encode.

## 1.4.0

- iOS: reply to channel calls on the platform thread, and stop an in-flight
  export when the engine detaches.
- iOS: the privacy manifest is now actually packaged (podspec + SPM) — App Store
  requires it from third-party SDKs.
- Android: ship `consumer-rules.pro` so apps with R8 enabled don't have to guess.
- Add `CompressErrorCode` — the `code` values are now named constants, mirrored
  on all three platforms. Values are unchanged.

## 1.3.0

- Fix: Android truncated every video to 30 seconds.
- Android: alignment no longer upscales (1080 → 1088); target-size mode pins CBR.
- iOS: more accurate target size.

## 1.2.0

- Fix: cancelling a video on Android left the `compress()` future pending forever.
- Android: no longer blocks the UI thread; EXIF orientation applied; bitmaps recycled.
- iOS: failed encodes now error instead of writing a 0-byte file; `maxWidth`/`maxHeight` respected per axis.
- Web: codecs and output blobs are released; images no longer download as `.mp4`.
- Typed errors: `CompressException`, `ImageCompressException`, `CompressCancelled`.
- Batch: `compressImages` gained progress/cancellation; both gained `continueOnError`.
- Add `releaseOutput(path)`, `cancelAll()`, `CancellationToken.reset()`.
- Target-size search is far cheaper — one encode when the image already fits.

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
