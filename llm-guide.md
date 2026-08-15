# flutter_compress — LLM Integration Guide

**Purpose.** A self-contained reference for AI coding assistants integrating
`flutter_compress`. Everything needed to write correct code is in this file — no
other page needs to be fetched.

**Package:** `flutter_compress` · **This guide targets:** 1.5.1
**Source of truth:** <https://pub.dev/packages/flutter_compress>

Before integrating, check the latest version on pub.dev and use it in
`pubspec.yaml`. If the installed version differs from 1.5.1, prefer the
package's own dartdoc over this file.

**What it does.** Compresses **video** and **images** on Android, iOS and Web
using each platform's native encoder. No FFmpeg, no GPL, nothing to bundle.

---

## 0. Read this first — the five things that get written wrong

These are the mistakes an assistant makes when it guesses instead of reading.
Each is expanded later; this list exists so they are seen before any code is
written.

1. **Video and images are two separate APIs.** `compress()` is video-only.
   `compressImage()` is image-only. Passing a JPEG to `compress()` fails.
2. **Set exactly one size control.** `targetSizeMB` / `videoBitrateKbps` /
   `qualityPercent` / `quality` are ranked, not combined. Setting several does
   not "refine" the result — the highest-ranked one wins and the rest are dead
   config.
3. **Options unsupported on a platform are ignored, not approximated.** Setting
   `frameRate: 24` on Android changes nothing about the output's frame rate.
   Nothing throws. See §7.
4. **Read the result; do not assume the request was honoured.** `result.codec`,
   `result.frameRate`, `result.hasAudio`, `result.durationMs` and
   `result.format` report what was *actually written*.
5. **On Web you must release outputs.** Outputs are `blob:` URLs held for the
   life of the page. Call `releaseOutput(path)` when done, or memory grows until
   the tab dies.

---

## 1. Installation

```yaml
dependencies:
  flutter_compress: ^1.5.1
```

No platform registration, no init call. The plugin registers itself.

```dart
import 'package:flutter_compress/flutter_compress.dart';

final api = FlutterCompress.instance;
```

`FlutterCompress.instance` is the only entry point. Do not construct it.

---

## 2. Platform setup

### Android

`minSdk 24`. The plugin's manifest merges these into the host app:

| Permission | For | Required? |
|---|---|---|
| `FOREGROUND_SERVICE` | video encode surviving backgrounding | optional |
| `FOREGROUND_SERVICE_DATA_SYNC` | same, Android 14+ typing | optional |
| `POST_NOTIFICATIONS` | the foreground service's notification | optional |
| `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion="28"`) | `saveToDownloads()` on API ≤ 28 | only for that call |

**If the app only compresses images, or only in the foreground**, pass
`keepAliveInBackground: false` and strip the first three:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"
    tools:node="remove" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"
    tools:node="remove" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"
    tools:node="remove" />
```

Image compression never starts the service, so this costs image-only apps
nothing. A stripped permission does not crash the encode — the plugin logs and
continues without background protection.

R8/ProGuard rules ship with the plugin (`consumer-rules.pro`). Add nothing.

### iOS

Deployment target 13.0. **No `Info.plist` key is required** — the plugin reads
files by path and never touches the camera, photo library, microphone or
location. Do not add `NSCameraUsageDescription` or `NSPhotoLibraryUsageDescription`
on this plugin's behalf; if the app picks files with another package, that
package's requirements apply, not this one's.

Only if `saveToDownloads()` output should be visible in the Files app:

```xml
<key>UIFileSharingEnabled</key><true/>
<key>LSSupportsOpeningDocumentsInPlace</key><true/>
```

A signed privacy manifest (`PrivacyInfo.xcprivacy`) is bundled. Add nothing.

### Web

Requires WebCodecs — Chrome/Edge 94+, Safari 16.4+. Gate on it:

```dart
if (!await api.isSupported()) {
  // Video compression unavailable in this browser. Image compression still
  // works (canvas-based) and needs no gate.
}
```

Paths are `blob:` URLs, not filesystem paths. With `file_picker`, pass
`xFile.path` — on web that *is* a `blob:` URL. See §8 for the release rules.

---

## 3. Video — `compress()`

```dart
Future<VideoCompressResult> compress(
  String path,
  VideoCompressConfig config, {
  void Function(CompressionProgress)? onProgress,
  CancellationToken? cancellationToken,
  String? outputDirectory,
  String? outputName,
})
```

```dart
final result = await api.compress(
  inputPath,
  const VideoCompressConfig(targetSizeMB: 10),
  onProgress: (p) => debugPrint('${(p.progress * 100).toStringAsFixed(0)}%'),
);
print('${result.outputPath} — saved ${result.savedPercent.toStringAsFixed(1)}%');
```

### `VideoCompressConfig`

| Field | Type | Default | Meaning |
|---|---|---|---|
| `quality` | `CompressQuality` | `medium` | Preset tier: `high`/`medium`/`low`/`veryLow` |
| `qualityPercent` | `int?` | `null` | Output bitrate = N% of **source** bitrate (1–100) |
| `videoBitrateKbps` | `int?` | `null` | Explicit average video bitrate |
| `targetSizeMB` | `int?` | `null` | Desired size; the plugin derives the bitrate |
| `codec` | `VideoCodec` | `h265` | `h265` or `h264`; falls back automatically |
| `maxWidth` / `maxHeight` | `int?` | `null` | Cap dimensions; aspect kept, **only scales down** |
| `frameRate` | `double?` | `null` | Cap fps — **iOS only**, see §7 |
| `removeAudio` | `bool` | `false` | Drop the audio track |
| `audioBitrateKbps` | `int?` | `null` | Re-encode audio — **iOS only**, see §7 |
| `trim` | `TrimRange?` | `null` | `TrimRange(startMs:, endMs:)` — **not on Web** |
| `alignment` | `DimensionAlignment` | `auto16` | `auto16` rounds down to ÷16; `none` disables |
| `keepOriginalIfLarger` | `bool` | `true` | Return the source untouched if compression would grow it |
| `container` | `VideoContainer` | `auto` | `auto` keeps the source container where possible; `mp4` forces |
| `keepAliveInBackground` | `bool` | `true` | Android foreground service; see §2 |

### Size-control priority — set exactly one

```
targetSizeMB  →  videoBitrateKbps  →  qualityPercent  →  quality
```

The first non-null one wins; the rest are ignored entirely.

```dart
// WRONG — videoBitrateKbps and quality are dead config here.
const VideoCompressConfig(
  targetSizeMB: 10, videoBitrateKbps: 2000, quality: CompressQuality.low,
);

// RIGHT — one intent.
const VideoCompressConfig(targetSizeMB: 10);
```

Non-positive values (`targetSizeMB: 0`, `maxWidth: 0`, …) trip an assertion.

### `VideoCompressResult`

| Field | Notes |
|---|---|
| `outputPath` | **May be the source path** when `skipped` is true |
| `originalSizeBytes` / `compressedSizeBytes` | Measured, not estimated |
| `width` / `height` | Actual output dimensions |
| `durationMs` | **Output** duration — compare with the source to detect truncation |
| `codec` | `"h264"` or `"h265"` — what was used, which may not be what was requested |
| `frameRate` | `double?` — actual; `null` when the platform can't report it |
| `hasAudio` | `bool?` — whether the output has an audio track |
| `skipped` | True when the original was returned untouched |
| `compressionRatio` / `savedPercent` | Derived getters |

**`skipped` matters.** When true, `outputPath` is the *input* file. Do not
delete it as if it were a temporary output, and do not call `releaseOutput()` on
it on Web (the plugin guards this, but the intent should be explicit).

### Pre-flight estimate — no encoding

```dart
final CompressionEstimate est = await api.estimate(path, config);
// est.estimatedSizeBytes, estimatedBitrateKbps, targetWidth, targetHeight
```

### Other video calls

```dart
final VideoInfo info = await api.getVideoInfo(path);
final String thumb = await api.getThumbnail(path, positionMs: 1000, maxWidth: 320);
final bool busy = await api.isCompressing();
```

`getThumbnail` returns a file path on mobile and a `data:` URL on Web.

---

## 4. Images — `compressImage()`

A **separate API**. Never route an image through `compress()`.

```dart
Future<ImageCompressResult> compressImage(
  String path,
  ImageCompressConfig config, {
  String? outputDirectory,
  String? outputName,
})
```

```dart
final r = await api.compressImage(
  path,
  const ImageCompressConfig(targetSizeKB: 200, maxWidth: 2560),
);
print('${r.format} ${r.width}x${r.height} — ${r.savedPercent.toStringAsFixed(1)}%');
```

### `ImageCompressConfig`

| Field | Type | Default | Meaning |
|---|---|---|---|
| `format` | `ImageFormat?` | `null` | **`null` keeps the source's format.** `jpeg`/`png`/`webp`/`heic` |
| `quality` | `int` | `85` | 1–100; ignored when `targetSizeKB` is set or `lossless` is true |
| `targetSizeKB` | `int?` | `null` | Highest-priority size control; the engine searches quality, then downscales |
| `maxWidth` / `maxHeight` | `int?` | `null` | Cap; only scales down |
| `keepExif` | `bool` | `false` | See §7 — **JPEG only on Android, not on Web** |
| `lossless` | `bool` | `false` | Pixel-identical re-encode; ignores `targetSizeKB` |
| `keepOriginalIfLarger` | `bool` | `true` | Return the source untouched if the result would be larger |

**Leave `format` null unless the app genuinely needs a conversion.** A null
format preserves JPEG as JPEG, PNG as PNG — which is what callers almost always
want.

**`lossless` frequently produces a *larger* file** (re-encoding an
already-compressed JPEG cannot beat the original). That is why
`keepOriginalIfLarger` defaults to true: the result comes back `skipped` with
the original path. This is correct behaviour, not a failure.

```dart
// Convenience wrapper — keeps the source format, sets lossless.
final r = await api.compressImageLossless(path);
```

### `ImageCompressResult`

`outputPath`, `originalSizeBytes`, `compressedSizeBytes`, `width`, `height`,
`format` (**actually written**, may differ from the request), `skipped`, plus
`compressionRatio` / `savedPercent`.

```dart
final ImageMeta meta = await api.getImageInfo(path);
```

---

## 5. Batches

Both run **sequentially**, not in parallel — parallel hardware encodes contend
for the same encoder and are slower, not faster.

```dart
final videos = await api.compressAll(
  paths, config,
  onItemProgress: (index, p) => …,
  cancellationToken: token,
  continueOnError: true,
  onItemError: (index, path, error) => …,
);

final images = await api.compressImages(
  paths, config,
  onItemDone: (index, total) => …,
  continueOnError: true,
);
```

With `continueOnError: true` a failing item is **omitted from the result**, so
the returned list may be shorter than `paths`. Match items by `onItemError`
index, not by list position.

A cancel is never treated as an item failure: `compressAll` rethrows it even
with `continueOnError: true`. For `compressImages` the token is checked
**between items** — an image already being encoded finishes first, which is
harmless because images take milliseconds.

---

## 6. Progress, cancellation, errors

### Progress

```dart
// Per-job:
await api.compress(path, config, onProgress: (p) => print(p.progress));

// Global stream (useful for a batch UI):
api.progressStream.listen((p) => print('${p.id} ${p.progress}'));
```

`CompressionProgress`: `id`, `progress` (0.0–1.0), `estimatedRemainingMs?`,
`currentOutputBytes?`.

### Cancellation

```dart
final token = CancellationToken();
final future = api.compress(path, config, cancellationToken: token);
await token.cancel();          // aborts; the future throws
```

**A token latches.** Reusing one without `token.reset()` cancels the next job
immediately.

```dart
token.reset();                 // required before reuse
```

`api.cancel([id])` cancels one job; `api.cancelAll()` cancels everything.

### Errors

Catch the plugin's own types. `PlatformException` never escapes the API.

```dart
try {
  await api.compress(path, config);
} on CompressCancelled {                 // marker: both video & image cancels
  // user aborted
} on VideoCompressException catch (e) {
  if (e.code == CompressErrorCode.unsupported) { … }
} on CompressException catch (e) {       // base type for everything
  …
}
```

| Type | Raised by |
|---|---|
| `CompressException` | base class for all of the below |
| `VideoCompressException` | video calls |
| `ImageCompressException` | image calls |
| `VideoCompressCancelledException` | video cancel — also a `CompressCancelled` |
| `ImageCompressCancelledException` | image cancel — also a `CompressCancelled` |

`CompressErrorCode` constants: `cancelled`, `infoFailed`, `estimateFailed`,
`compressFailed`, `thumbnailFailed`, `saveFailed`, `imageInfoFailed`,
`imageCompressFailed`, `badArguments`, `noEngine`, `unsupported`.

Compare `e.code` against these constants. Never parse `e.message` — its wording
is not stable.

---

## 7. Platform capability matrix — ❌ means *ignored*, not approximated

This is the section most likely to produce wrong code if skipped. An option
marked ❌ is silently dropped: nothing throws, and the output simply does not
have the requested property.

### Video

| Capability | Android | iOS | Web |
|---|:---:|:---:|:---:|
| Target size / bitrate / quality | ✅ | ✅ | ✅ |
| H.265 with H.264 fallback | ✅ | ✅ | ✅ ¹ |
| `maxWidth` / `maxHeight` | ✅ | ✅ | ✅ |
| `frameRate` | ❌ ² | ✅ | ❌ ² |
| `removeAudio` | ✅ | ✅ | ❌ audio always dropped |
| `audioBitrateKbps` | ❌ ³ | ✅ | ❌ |
| `trim` | ✅ | ✅ | ❌ |
| Thumbnail / info / estimate | ✅ | ✅ | ✅ |
| Progress / cancel / batch | ✅ | ✅ | ✅ |
| Background compression | ✅ foreground service | ✅ background task | n/a |

¹ Web uses HEVC only where the browser's WebCodecs supports encoding it,
otherwise H.264. Read `result.codec`.
² Only iOS decimates frames. Media3 has no frame-dropping effect and the web
pipeline re-encodes every decoded frame; on both, `frameRate` only feeds the
bitrate maths. Read `result.frameRate`.
³ Media3 1.4.x exposes no audio-encoder settings; Android encodes AAC at its own
default. The value still shapes the `targetSizeMB` budget.

### Image

| Capability | Android | iOS | Web |
|---|:---:|:---:|:---:|
| Target size / quality | ✅ | ✅ | ✅ |
| JPEG / PNG / WebP | ✅ | ✅ | ✅ |
| HEIC | ⚠️ device encoder only, else JPEG | ✅ | ❌ |
| `maxWidth` / `maxHeight` | ✅ | ✅ | ✅ |
| `keepExif` | ⚠️ JPEG only | ✅ | ❌ |

**Consequence for generated code:** never present an ignored option to the user
as if it worked. If a UI exposes a frame-rate slider, gate it on
`defaultTargetPlatform == TargetPlatform.iOS`, or surface `result.frameRate`
afterwards.

---

## 8. Output files and Web memory

### Where output goes

| | Default | With `outputDirectory` / `outputName` |
|---|---|---|
| Android / iOS | plugin cache dir, `<source-name>_<timestamp>.<ext>` | as given |
| Web | a `blob:` URL | both parameters are ignored |

**`outputName` is a base name, not a file name.** Pass it without an extension.
If one is supplied it is stripped — `'photo.jpg'` yields `photo.<real-ext>`, not
`photo.jpg.jpg` — because the extension is always derived from what was actually
encoded. It follows that `outputName` **cannot change the output format**:
video format comes from `container` (and the platform), image format from
`format`.

Extension rules: video keeps the source container unless `container:
VideoContainer.mp4`; images keep the source format unless `format` is set.

### Saving

```dart
final String saved = await api.saveToDownloads(result.outputPath);
// Android → MediaStore Downloads · iOS → app Documents · Web → browser download
```

### Releasing — mandatory on Web

```dart
await api.releaseOutput(result.outputPath);  // one output
await api.clearCache();                      // everything
```

On Android/iOS these delete cache files. **On Web they revoke blob URLs**, which
is the only way to free the encoded bytes — the browser otherwise holds every
output for the life of the page. Release as soon as the result has been
uploaded, downloaded or rendered.

Do not call `releaseOutput` on a path you still display in an `<img>`/`Image.network`.

---

## 9. Complete worked example

```dart
import 'package:flutter_compress/flutter_compress.dart';

Future<String?> shrinkVideo(String inputPath) async {
  final api = FlutterCompress.instance;

  if (!await api.isSupported()) return null;      // web without WebCodecs

  final token = CancellationToken();
  try {
    final result = await api.compress(
      inputPath,
      const VideoCompressConfig(
        targetSizeMB: 10,                          // one size control only
        codec: VideoCodec.h265,                    // auto-falls back to H.264
        maxWidth: 1280,
        maxHeight: 1280,
      ),
      onProgress: (p) => debugPrint('${(p.progress * 100).round()}%'),
      cancellationToken: token,
    );

    if (result.skipped) {
      // Nothing was written — outputPath is the original file.
      return inputPath;
    }

    debugPrint('codec=${result.codec} '                 // what actually happened
        'fps=${result.frameRate} audio=${result.hasAudio} '
        'duration=${result.durationMs}ms');

    await uploadFile(result.outputPath);
    await api.releaseOutput(result.outputPath);         // required on web
    return result.outputPath;
  } on CompressCancelled {
    return null;
  } on CompressException catch (e) {
    debugPrint('compression failed: ${e.code}');
    return null;
  }
}
```

---

## 10. Integration checklist

- [ ] `flutter_compress` in `pubspec.yaml` at the current pub.dev version
- [ ] Video uses `compress()`; images use `compressImage()` — never crossed
- [ ] Exactly **one** size control set per config
- [ ] `isSupported()` gates video on Web
- [ ] `result.skipped` handled — `outputPath` may be the source
- [ ] Actual values read from the result, not assumed from the config
- [ ] `releaseOutput()` or `clearCache()` called on Web after use
- [ ] `CancellationToken.reset()` before reuse
- [ ] Errors caught as `CompressException` / `CompressCancelled`, not `PlatformException`
- [ ] `e.code` compared against `CompressErrorCode`, never `e.message` parsed
- [ ] Android: `keepAliveInBackground: false` + permissions stripped if image-only
- [ ] No `NS*UsageDescription` added on this plugin's behalf
- [ ] Options marked ❌ for a platform are not exposed as working in the UI

---

## 11. Common mistakes

| Mistake | Why it matters | Fix |
|---|---|---|
| Passing an image to `compress()` | Video engine can't open it; runtime failure | Use `compressImage()` |
| Setting `targetSizeMB` *and* `videoBitrateKbps` | Lower-priority fields silently ignored; intent unclear | Set one |
| Assuming `frameRate` applies everywhere | Android/Web ignore it; output fps is unchanged | Gate on iOS or read `result.frameRate` |
| Assuming `config.codec` is what shipped | H.265 falls back to H.264 on unsupported hardware | Read `result.codec` |
| Treating `outputPath` as always a new file | With `skipped: true` it is the **source** — deleting it destroys the user's file | Check `result.skipped` first |
| Never calling `releaseOutput` on Web | Every output stays in memory for the page's life | Release after use |
| Reusing a `CancellationToken` | It latches; the next job aborts instantly | `token.reset()` |
| Catching `PlatformException` | Never thrown by this API; the catch is dead code | Catch `CompressException` |
| Adding camera/photo `Info.plist` keys | Plugin needs none; unjustified keys invite App Store questions | Only the file-picker package's keys |
| `outputName: 'photo.png'` to get a PNG | The name never sets the format — the extension is stripped and the real format wins | `format: ImageFormat.png` |
| Parallel `Future.wait` over videos | Hardware encoders contend; slower and can fail | `compressAll()` |
| `lossless: true` "failing" because the file grew | Expected for already-compressed sources | Handle `skipped` |

---

## 12. Full API reference

| Member | Signature | Purpose |
|---|---|---|
| `FlutterCompress.instance` | `FlutterCompress` | Singleton entry point |
| `getVideoInfo` | `(String path) → Future<VideoInfo>` | Probe a video |
| `estimate` | `(String path, VideoCompressConfig) → Future<CompressionEstimate>` | Predict size without encoding |
| `compress` | `(String, VideoCompressConfig, {onProgress, cancellationToken, outputDirectory, outputName}) → Future<VideoCompressResult>` | Compress one video |
| `compressAll` | `(List<String>, VideoCompressConfig, {onItemProgress, cancellationToken, outputDirectory, continueOnError, onItemError}) → Future<List<VideoCompressResult>>` | Sequential video batch |
| `getThumbnail` | `(String, {positionMs, quality, maxWidth}) → Future<String>` | Frame grab; path or `data:` URL |
| `getImageInfo` | `(String path) → Future<ImageMeta>` | Probe an image |
| `compressImage` | `(String, ImageCompressConfig, {outputDirectory, outputName}) → Future<ImageCompressResult>` | Compress one image |
| `compressImageLossless` | `(String, {format, maxWidth, maxHeight, keepExif, outputDirectory, outputName}) → Future<ImageCompressResult>` | Lossless wrapper |
| `compressImages` | `(List<String>, ImageCompressConfig, {outputDirectory, onItemDone, cancellationToken, continueOnError, onItemError}) → Future<List<ImageCompressResult>>` | Sequential image batch |
| `cancel` | `([String? id]) → Future<void>` | Cancel one job |
| `cancelAll` | `() → Future<void>` | Cancel everything |
| `isCompressing` | `() → Future<bool>` | Is a job running |
| `isSupported` | `() → Future<bool>` | Video support (Web gate) |
| `saveToDownloads` | `(String path, {String? fileName}) → Future<String>` | Export to Downloads/Documents |
| `releaseOutput` | `(String outputPath) → Future<void>` | Free one output |
| `clearCache` | `() → Future<void>` | Free all outputs |
| `progressStream` | `Stream<CompressionProgress>` | Global progress |

---

## 13. How to use this document

1. Read §0 before writing any code.
2. Pick the API by media type (§3 video, §4 images) — they never mix.
3. Check §7 for every option used, on every platform the app targets. If an
   option is ❌ anywhere, either gate it per-platform or report the actual value
   from the result.
4. Handle `skipped`, cancellation and errors per §6 and §8.
5. Walk §10 before declaring the integration done, and check the work against
   §11.

If asked for something this guide does not cover, say so rather than inventing
an API. The full dartdoc ships with the package, and the source is at
<https://github.com/chenkaiHere/flutter_compress>.
