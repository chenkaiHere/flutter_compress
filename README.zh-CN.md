# flutter_compress

Flutter 高质量**视频压缩**插件 —— 覆盖 Android / iOS / Web,**不依赖 FFmpeg**。
每个平台都使用系统原生的硬件加速编码器,API 以**意图**为核心(「压到约 10MB」「码率减半」),
而不是让你猜测各种质量档。

> English docs: [README.md](README.md)

**🌐 Web 版在线体验 —— 浏览器直接试用:**
<https://flutter-compress.ckdgdgdg.workers.dev/>

- **Android** → Media3 `Transformer`(Google 维护、硬件加速)
- **iOS** → 手写 `AVAssetReader`/`AVAssetWriter` 管线(可精确控制码率)
- **Web** → WebCodecs + `mp4box.js` / `mp4-muxer`(体积极小,约 0.2MB,非 FFmpeg)

## 特性

- 🎯 **目标大小** —— 给个目标体积,插件在各平台用同一套算法反推码率。
- 🎚️ **也能控质量** —— 按源码率的百分比,或预设档位。
- 🧬 **H.265(HEVC)+ 自动回退 H.264**,三端通用。
- 📉 分辨率上限、帧率上限、去音轨、裁剪、`÷16` 对齐。
- 📡 实时**进度**、**取消**、顺序**批量**、**缩略图**、**体积预估**。
- 💾 `saveToDownloads`,以及「越压越大就返回原文件」的保护。
- 🪶 无 FFmpeg、无 GPL、体积轻量。

## 平台能力对照

| 能力 | Android | iOS | Web |
|---|:---:|:---:|:---:|
| 压缩(目标大小 / 码率 / 质量) | ✅ | ✅ | ✅ |
| H.265 + 回退 H.264 | ✅ | ✅ | ✅¹ |
| 分辨率上限(`maxWidth`/`maxHeight`) | ✅ | ✅ | ✅ |
| 帧率上限(`frameRate`) | ⚠️ 尽力而为 | ✅ | ✅ |
| 音频:去除 / 码率 | ✅ | ✅ | ⚠️ v1 丢弃音频 |
| 裁剪(`trim`) | ✅ | ✅ | ❌(v1) |
| 缩略图 / 信息 / 预估 | ✅ | ✅ | ✅ |
| 进度 / 取消 / 批量 | ✅ | ✅ | ✅ |
| 后台压缩 | ✅ 前台服务 | ✅ 后台任务 | 不适用 |
| `saveToDownloads` | MediaStore | Documents | 浏览器下载 |

¹ Web 仅在浏览器支持 WebCodecs 的 HEVC 编码时用 H.265(如 Safari、带硬件 HEVC 的 Chrome),否则自动回退 H.264。

## 安装

```yaml
dependencies:
  flutter_compress: ^1.0.0
```

## 快速上手

```dart
import 'package:flutter_compress/flutter_compress.dart';

final result = await FlutterCompress.instance.compress(
  inputPath,
  const VideoCompressConfig(
    targetSizeMB: 10,          // 最高优先级的体积控制
    codec: VideoCodec.h265,    // 不支持时自动回退 H.264
    maxWidth: 1280,            // 只缩不放
    maxHeight: 1280,
  ),
  onProgress: (p) => debugPrint('${(p.progress * 100).toStringAsFixed(0)}%'),
);

print('节省 ${result.savedPercent.toStringAsFixed(1)}% → ${result.outputPath}');
```

## 配置

`VideoCompressConfig` —— 只需设置**一个**体积/质量控制项,优先级为:

`targetSizeMB` → `videoBitrateKbps` → `qualityPercent` → `quality`

| 字段 | 含义 |
|---|---|
| `targetSizeMB` | 目标输出大小,插件据此反推码率。 |
| `videoBitrateKbps` | 显式指定平均视频码率。 |
| `qualityPercent` | 输出码率 = **源码率** 的 `percent%`(1–100)。 |
| `quality` | 预设档:`high` / `medium` / `low` / `veryLow`。 |
| `codec` | `h265`(默认,自动回退)或 `h264`。 |
| `maxWidth` / `maxHeight` | 尺寸上限;保持比例、只缩不放。 |
| `frameRate` | 帧率上限。 |
| `removeAudio` / `audioBitrateKbps` | 去音轨 / 重编码音频。 |
| `trim` | `TrimRange(startMs, endMs)`。 |
| `alignment` | `auto16`(默认)对齐到 `÷16`,避免边缘伪影。 |
| `keepOriginalIfLarger` | 压缩无益时返回原文件。 |

## API

```dart
final api = FlutterCompress.instance;

// 探测与预估(不编码)
final VideoInfo info = await api.getVideoInfo(path);
final CompressionEstimate est = await api.estimate(path, config);

// 单个压缩
final token = CancellationToken();
final result = await api.compress(
  path, config,
  onProgress: (p) => print(p.progress),   // 0.0–1.0
  cancellationToken: token,
  outputDirectory: dir,                    // 可选
);
await token.cancel();                      // 中止上面的任务

// 批量(顺序)、缩略图、清理
await api.compressAll(paths, config);
final String thumb = await api.getThumbnail(path, positionMs: 1000, maxWidth: 320);
final String saved = await api.saveToDownloads(result.outputPath);
await api.clearCache();

// 全局进度流(适合批量 UI)
api.progressStream.listen((p) => print('${p.id} ${p.progress}'));
```

## 各平台配置

- **Android** —— 最低 SDK 24,`compileSdk 36`。插件已声明 `FOREGROUND_SERVICE`、
  `FOREGROUND_SERVICE_DATA_SYNC`、`POST_NOTIFICATIONS`,以及(API ≤ 28 下
  `saveToDownloads` 需要的)`WRITE_EXTERNAL_STORAGE`。
- **iOS** —— 最低 13.0。用 `beginBackgroundTask` 争取短暂后台时间。若想让
  `saveToDownloads` 保存的文件在「文件」App 里可见,请在 `Info.plist` 加入
  `UIFileSharingEnabled` 与 `LSSupportsOpeningDocumentsInPlace`。
- **Web** —— 需要 WebCodecs(Chrome/Edge 94+、Safari 16.4+)。输入/输出均为
  `blob:` URL;内置的解封装/封装 JS(约 0.2MB)首次使用时懒加载。用 `file_picker`
  选文件并传 `xFile.path`(在 web 上就是 `blob:` URL)。可直接在
  [在线 Demo](https://flutter-compress.ckdgdgdg.workers.dev/) 里试用。

## 已知限制

- **Web(v1)**:丢弃音频,且暂不支持 `trim`。

## 许可证

MIT —— 见 [LICENSE](LICENSE)。
