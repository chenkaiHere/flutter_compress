# Changelog

## 2.0.1

- iOS: fix videos being **cropped instead of scaled** whenever `maxWidth` /
  `maxHeight` required a downscale — the output had the right dimensions but
  showed only the top-left of the frame. This hit every orientation, and both
  `forSocialMedia()` and `maxCompression()` on typical 1080p sources. Reported by
  @nicolai-jacobsen, fixed by @tomquas (#5).

## 2.0.0

### Breaking

- **The plugin no longer declares any Android permission.** `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_DATA_SYNC`, `POST_NOTIFICATIONS` and
  `WRITE_EXTERNAL_STORAGE` are gone: manifest merging pushed all four into every
  app that depended on the plugin, for capabilities many never used — and none are
  needed to compress. Declare what you actually want; the README has the
  snippets.
- **`keepAliveInBackground` is replaced by `androidNotification`.** A foreground
  service must show a notification, and its icon, title and wording belong to your
  app, not to a library — so the plugin no longer supplies one. Pass an
  `AndroidNotification` (icon, title, optional text and channel name) to opt into
  background compression; omit it and no service is ever started.

  No service starts unless the notification is supplied, its `smallIcon` resolves
  in your app, **and** your app declares `FOREGROUND_SERVICE`. A miss is never an
  error: the plugin logs and encodes foreground-only.

  **Migrating:** relied on background compression? Declare the permissions and
  pass `androidNotification`. Didn't? Drop `keepAliveInBackground` and nothing
  else changes. iOS keeps its background window (`beginBackgroundTask`: no UI, no
  permission) and ignores this field.
- `saveToDownloads()` on Android 9 and below now throws
  `CompressErrorCode.permissionDenied` unless your app declares
  `WRITE_EXTERNAL_STORAGE` with `maxSdkVersion="28"`. API 29+ is unaffected.
- Add `CompressErrorCode.permissionDenied` (Android-only today).

### Added

- `compressImageBytes()` — compress an image already in memory, no temp file.
  Images only: a video would mean copying tens of MB through the channel at once.
- `minSavingsPercent`: return the original unless compression saves at least
  this much. Default `0` keeps the previous behaviour.
- Presets: `VideoCompressConfig.forSocialMedia()` / `.maxCompression()`,
  `ImageCompressConfig.forAvatar()` / `.forSocialMedia()`.

### Fixed

- Android `keepExif` now copies 48 tags instead of 7 — exposure, lens and
  orientation data used to be dropped silently.

## 1.5.1

- Add [`llm-guide.md`](llm-guide.md) — an integration guide for AI coding
  assistants (Claude Code, Cursor, Copilot).
- iOS: clearer internal names. No API or behaviour change.

## 1.5.0

- iOS: fix a compile error that broke every 1.4.0 iOS build (`CompressionEngine`
  was missing `cancelAll`). Reported by @waitwalker.
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
