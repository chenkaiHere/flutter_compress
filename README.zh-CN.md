# flutter_compress

[![pub package](https://img.shields.io/pub/v/flutter_compress.svg)](https://pub.dev/packages/flutter_compress)
[![platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-blue.svg)](https://pub.dev/packages/flutter_compress)
[![license](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**一个插件搞定视频和图片压缩 —— 覆盖 Android / iOS / Web,且不依赖 FFmpeg。**

每个平台都使用系统原生的硬件加速编码器,压缩又快、体积又小、画质原生级 ——
**不用打包 20MB 的 FFmpeg、没有 GPL 授权顾虑、不额外增加包体**。API 以**意图**为核心
(「压到约 10MB」「码率减半」「压到 200KB 以内」),而不是让你去猜各种晦涩的质量档。

> English docs: [README.md](README.md)

**🌐 [点此在浏览器中在线体验 Web 版 →](https://flutter-compress.ckdgdgdg.workers.dev/)**

| | |
|:---:|:---:|
| ![预览图 1](https://flutter-compress.ckdgdgdg.workers.dev/img/compress_zh_1.jpeg) | ![预览图 2](https://flutter-compress.ckdgdgdg.workers.dev/img/compress_zh_2.jpeg) |

## 为什么选它?

- 🪶 **无 FFmpeg、无 GPL、不臃肿** —— 除了系统自带的编码器,什么都不用打包。App 体积小、授权干净。
- 🌍 **一套 API,三个平台** —— 同一份 Dart 代码在 Android、iOS **和浏览器**(WebCodecs)都能跑,大多数同类插件根本不支持 Web。
- 🎯 **目标大小,压得准** —— 给个目标体积,插件在各平台用同一套算法反推码率,精准命中。
- 🎬🖼️ **视频、图片都能压** —— 两套专用且互不干扰的 API(`compress` / `compressImage`),各自为自己的媒介调优。
- 📡 **可直接上生产** —— 实时进度、取消、顺序批量、以及「越压越大就返回原文件」的保护。
- 🧼 **不声明任何权限** —— 多数压缩插件会把一条前台服务通知(和它的权限)推进每个依赖它的 App。这里后台压缩是可选的,而通知是**你的**:你的图标、你的文案、你的渠道。
- 🚀 **常见场景有预设** —— `forSocialMedia()`、`maxCompression()`、`forAvatar()`,不用自己调参。

## 底层实现

| 平台 | 视频引擎 | 图片引擎 |
|---|---|---|
| **Android** | Media3 `Transformer`(Google 维护、硬件加速) | `Bitmap` |
| **iOS** | 手写 `AVAssetReader`/`AVAssetWriter`(可精确控制码率) | ImageIO |
| **Web** | WebCodecs + `mp4box.js` / `mp4-muxer`(约 0.2MB,非 FFmpeg) | Canvas |

## 特性

### 🎬 视频 —— `compress`

- 🎯 **目标大小**,或显式**码率**、**质量百分比**、**预设档位**。
- 🧬 **H.265(HEVC)+ 自动回退 H.264**,三端通用。
- 📉 分辨率上限、帧率上限、去音轨、裁剪、`÷16` 对齐。
- 🖼️ 缩略图、媒体信息、以及压缩前的**体积预估**(不编码)。
- 📡 实时进度、取消、顺序批量。

### 🖼️ 图片 —— `compressImage`

- 🎯 **目标大小**(精确 —— 引擎二分质量,必要时再降分辨率)**或质量**。
- 🎞️ 格式:**JPEG · PNG · WebP · HEIC**(不支持时自动回退)。
- 📐 分辨率上限,以及可选的 **EXIF** 保留(方向、GPS…)。
- ⚡ 毫秒级,支持单张或批量。
- 🧠 **直接压内存字节**(`compressImageBytes`)—— `image_picker` 的结果、相机帧、下载的图,都不用先落临时文件。

## 平台能力对照

### 🎬 视频

| 能力                            |  Android   |    iOS    |  Web  |
|-------------------------------|:----------:|:---------:|:-----:|
| 压缩(目标大小 / 码率 / 质量)            |     ✅      |     ✅     |   ✅   |
| H.265 + 回退 H.264              |     ✅      |     ✅     |   ✅   |
| 分辨率上限(`maxWidth`/`maxHeight`) |     ✅      |     ✅     |   ✅   |
| 帧率上限(`frameRate`)             |     ❌      |     ✅     |   ❌   |
| 音频:去除(`removeAudio`)          |     ✅      |     ✅     |   ❌   |
| 音频码率(`audioBitrateKbps`)      |     ❌      |     ✅     |   ❌   |
| 裁剪(`trim`)                    |     ✅      |     ✅     |   ❌   |
| 缩略图 / 信息 / 预估                 |     ✅      |     ✅     |   ✅   |
| 进度 / 取消 / 批量                  |     ✅      |     ✅     |   ✅   |
| 后台不中断                         | ⚠️ 需自行开启 ⁴ |  ✅ 后台任务   |  不适用  |
| `saveToDownloads`             | MediaStore | Documents | 浏览器下载 |

¹ Web 仅在浏览器支持 WebCodecs 的 HEVC 编码时用 H.265(如 Safari、带硬件 HEVC 的 Chrome),否则自动回退 H.264。

² 只有 iOS 能真正抽帧。Media3 没有抽帧效果,Web 管线对每一个解码帧都重新编码 ——
这两端的 `frameRate` 只影响码率/关键帧计算。实际帧率请读 `result.frameRate`。

³ Media3 1.4.x 不暴露任何音频编码器设置,Android 使用其默认 AAC 码率。该值仍参与
`targetSizeMB` 的预算计算。

⁴ Android 需要前台服务,而它的通知必须是你的 —— 传 `androidNotification` 并声明
`FOREGROUND_SERVICE`。两者缺一,编码就只在前台进行,**不报错**。见
[Android 的后台压缩](#android-的后台压缩)。iOS 什么都不需要(`beginBackgroundTask`:
无 UI、无权限)。

标 ❌ 的项是**被忽略**,不是近似处理 —— 结果对象会回报实际发生了什么
(`result.frameRate`、`result.hasAudio`、`result.durationMs`)。

### 🖼️ 图片

| 能力                            |  Android   |    iOS    |  Web  |
|-------------------------------|:----------:|:---------:|:-----:|
| 压缩(目标大小 / 质量)                 |     ✅      |     ✅     |   ✅   |
| JPEG / PNG / WebP             |     ✅      |     ✅     |   ✅   |
| HEIC                          |    ⚠️ ¹    |     ✅     |   ❌   |
| 分辨率上限(`maxWidth`/`maxHeight`) |     ✅      |     ✅     |   ✅   |
| 保留 EXIF(`keepExif`)           | ⚠️ 仅 JPEG ² |   ✅     |   ❌   |
| 压缩内存字节(`compressImageBytes`) |     ✅      |     ✅     |   ✅   |
| `saveToDownloads`             | MediaStore | Documents | 浏览器下载 |

¹ Android 仅在设备存在 HEIC 编码器时才写 HEIC,否则回退 JPEG(实际格式在结果中返回)。

² Android 会把 48 个 EXIF 标签(机身、曝光、镜头、GPS、时间)写入 JPEG 输出;iOS 直接
整体透传源元数据;Web 的 canvas 重编码必然剥离元数据,无法绕过。

## 安装

```yaml
dependencies:
  flutter_compress: ^2.0.1
```

## 配合 AI 助手接入

把 **[llm-guide.md](llm-guide.md)** 交给 Claude Code、Cursor、Copilot 或任意 LLM
—— 本指南将引导助手完成整个集成过程。

> 读一下 https://raw.githubusercontent.com/chenkaiHere/flutter_compress/master/llm-guide.md
> ,然后在这个页面里加上视频压缩。

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

| 字段                                 | 含义                                         |
|------------------------------------|--------------------------------------------|
| `targetSizeMB`                     | 目标输出大小,插件据此反推码率。                           |
| `videoBitrateKbps`                 | 显式指定平均视频码率。                                |
| `qualityPercent`                   | 输出码率 = **源码率** 的 `percent%`(1–100)。        |
| `quality`                          | 预设档:`high` / `medium` / `low` / `veryLow`。 |
| `codec`                            | `h265`(默认,自动回退)或 `h264`。                   |
| `maxWidth` / `maxHeight`           | 尺寸上限;保持比例、只缩不放。                            |
| `frameRate`                        | 帧率上限。                                      |
| `removeAudio` / `audioBitrateKbps` | 去音轨 / 重编码音频。                               |
| `trim`                             | `TrimRange(startMs, endMs)`。               |
| `alignment`                        | `auto16`(默认)对齐到 `÷16`,避免边缘伪影。              |
| `keepOriginalIfLarger`             | 压缩无益时返回原文件。                                |
| `minSavingsPercent`                | 节省达不到这个百分比就返回原文件(0–99,默认 0)。设为 `5` 时,只压掉 3% 的结果会以 `skipped` 返回。 |
| `androidNotification`              | 传入前台服务的通知(图标、标题、正文、渠道)即开启后台压缩;`null`(默认)则不启动服务。仅 Android。 |
| `container`                        | `auto`(默认)尽量保持源容器(iOS 保 `.mov`/`.mp4`;Android/Web 只能 `.mp4`),或 `mp4` 强制。 |

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
  outputName: 'my_clip',                   // 可选;不带扩展名,自动补
);
await token.cancel();                      // 中止上面的任务

// 批量(顺序)、缩略图、清理
await api.compressAll(paths, config);
final String thumb = await api.getThumbnail(path, positionMs: 1000, maxWidth: 320);
final String saved = await api.saveToDownloads(result.outputPath);
await api.releaseOutput(result.outputPath);  // 释放单个结果(见下)
await api.clearCache();

// 全局进度流(适合批量 UI)
api.progressStream.listen((p) => print('${p.id} ${p.progress}'));
```

## 图片

图片 API 与视频完全独立。

```dart
final api = FlutterCompress.instance;

// 探测(不编码)
final ImageMeta meta = await api.getImageInfo(path);

// 压到目标大小(精确 —— 图片编码极快,引擎会二分质量,必要时再降分辨率压到目标以内)
// 不传 `format` 时,输出保持源文件格式。
final ImageCompressResult r = await api.compressImage(
  path,
  const ImageCompressConfig(
    targetSizeKB: 200,          // 最高优先级的体积控制
    maxWidth: 2560,             // 只缩不放
    maxHeight: 2560,
  ),
  outputDirectory: dir,         // 可选;null → 插件缓存
  outputName: 'my_photo',       // 可选;不带扩展名,自动补
);
print('${r.format} ${r.width}x${r.height} • 节省 ${r.savedPercent.toStringAsFixed(1)}%');

// 也可转格式、控质量、走无损:
await api.compressImage(path, const ImageCompressConfig(format: ImageFormat.webp, quality: 80));
await api.compressImageLossless(path);   // 保持源格式、像素级

// 预设 —— 不用调参
await api.compressImage(path, const ImageCompressConfig.forAvatar());
await api.compressImage(path, const ImageCompressConfig.forSocialMedia());

// 手里已经是字节?不用先落临时文件
final ImageBytesResult b = await api.compressImageBytes(
  bytes,                                 // 例如 await xFile.readAsBytes()
  const ImageCompressConfig(targetSizeKB: 200),
);
uploadBytes(b.bytes);                    // 不写磁盘,也没有需要释放的产物

// 批量:带进度、可取消、单张失败不影响整体
final token = CancellationToken();
final results = await api.compressImages(
  paths,
  const ImageCompressConfig(targetSizeKB: 300),
  onItemDone: (i, total) => print('${i + 1}/$total'),
  cancellationToken: token,
  continueOnError: true,                  // 某张失败不丢弃其余结果
  onItemError: (i, path, e) => print('已跳过 $path: $e'),
);
```

## 错误处理

所有失败都抛类型化异常,不会泄漏原始 `PlatformException`。

```dart
try {
  await api.compressImage(path, config);
} on CompressCancelled {
  // 被取消(视频/图片通用)
} on ImageCompressException catch (e) {
  if (e.code == CompressErrorCode.imageCompressFailed) { /* … */ }
} on CompressException catch (e) {
  // 两套 API 的其他任何失败
}
```

`CompressException` 是基类;`VideoCompressException` / `ImageCompressException` 各自细分,
`CompressCancelled` 是两种取消异常共同实现的标记接口。

判断错误请比对 **`CompressErrorCode`** 常量而不是裸字符串 —— 这套常量在三端各有一份镜像,
且取值属于公开合同的一部分。

`ImageCompressConfig` —— 优先级为 `lossless` → `targetSizeKB` → `quality`:

| 字段                       | 含义                                   |
|--------------------------|--------------------------------------|
| `format`                 | `null`(默认)保持**源格式**;或 `jpeg` / `png` / `webp` / `heic`。 |
| `targetSizeKB`           | 目标输出大小,引擎迭代压到该值或略低。                  |
| `quality`                | 1–100,`targetSizeKB` 为空时生效(PNG 忽略)。  |
| `lossless`               | 无损编码(PNG 真无损;JPEG 保持 JPEG、用最高画质)。忽略 `quality`/`targetSizeKB`。 |
| `maxWidth` / `maxHeight` | 尺寸上限;保持比例、只缩不放。                      |
| `keepExif`               | 保留 EXIF(方向、GPS…),默认剥离。               |
| `keepOriginalIfLarger`   | 压缩无益时返回原文件(标记 `skipped`)。默认开启。       |
| `minSavingsPercent`      | 节省达不到这个百分比就返回原文件(0–99,默认 0)。          |

## 各平台配置

- **Android** —— 最低 SDK 24,`compileSdk 36`。**不声明任何权限**。见
  [Android 权限](#android-权限) 与 [Android 的后台压缩](#android-的后台压缩)。
- **iOS** —— 最低 13.0。用 `beginBackgroundTask` 争取短暂后台时间。若想让
  `saveToDownloads` 保存的文件在「文件」App 里可见,请在 `Info.plist` 加入
  `UIFileSharingEnabled` 与 `LSSupportsOpeningDocumentsInPlace`。
- **Web** —— 需要 WebCodecs(Chrome/Edge 94+、Safari 16.4+)。输入/输出均为
  `blob:` URL;内置的解封装/封装 JS(216 KB,见
  [THIRD_PARTY_NOTICES](assets/THIRD_PARTY_NOTICES.md))在**首次压缩视频**时才懒加载
  —— 只压图片则完全不会下载。用 `file_picker`
  选文件并传 `xFile.path`(在 web 上就是 `blob:` URL)。
  结果下载或上传完后请**调用 `releaseOutput(result.outputPath)`** —— 否则浏览器会把
  整个编码结果在页面生命周期内一直留在内存里(`clearCache()` 可一次性释放全部)。
  可直接在 [在线 Demo](https://flutter-compress.ckdgdgdg.workers.dev/) 里试用。

### Android 权限

**本插件不声明任何权限。** 压缩就是对你已经交过来的文件做编解码,它什么权限都不需要;而
manifest 合并会把这里声明的任何权限推进**每一个**依赖它的 App。

插件只声明了一个 `<service>`(不是权限,不影响商店审核)—— 那个类必须在清单里才能被启动。
但它是**惰性的**:除非你同时声明了 `FOREGROUND_SERVICE` **并且**传了
`androidNotification`,它永远不会启动。见下方[Android 的后台压缩](#android-的后台压缩)。

唯一的例外值得知道:`saveToDownloads()` 在 **Android 9 及以下**是直接往公共 Downloads
目录写文件,所以需要那条老权限。API 29+ 走 MediaStore,什么都不需要。

```xml
<!-- 只有会调用 saveToDownloads() 且要支持 Android 9 及以下时才加 -->
<uses-permission
    android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```

不加的话 `saveToDownloads()` 会抛 `CompressErrorCode.permissionDenied`,错误信息里会把
这件事说清楚。插件**从不**替你申请运行时权限 —— 什么时候向用户要权限是产品决策。

示例 App **声明了零个权限** —— 这正是重点:它在什么都没授权的情况下照样压缩视频和图片。

### Android 的后台压缩

App 退到后台后 Android 会挂起工作,所以长时间编码需要一个前台服务 —— 而前台服务必须显示
一条通知。插件提供了这个服务,但**不提供任何自带通知**:图标、文案、渠道名都是很显眼的 UI,
它们属于**你的** App,不属于一个库。

所以是两步开启。先声明权限:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<!-- 可选,Android 13+ 的运行时权限。不给也行,服务照样跑,只是不显示通知。 -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

再把通知传进来:

```dart
await FlutterCompress.instance.compress(
  path,
  const VideoCompressConfig(
    targetSizeMB: 10,
    androidNotification: AndroidNotification(
      smallIcon: 'drawable/ic_compress',   // 你的资源
      title: '正在压缩视频',                  // 你的文案、你的多语言
      text: '点击返回 App',
      channelName: '媒体处理',               // 显示在系统设置里的渠道名
    ),
  ),
);
```

`smallIcon` 是 `"类型/名字"`,在**你的** App 资源里解析(`"mipmap/ic_launcher"` 也行;
只写 `"ic_compress"` 等价于 `"drawable/ic_compress"`)。

**三个条件全部满足才会启动服务**,而任何一条不满足都**不是错误** —— 插件记一条日志,编码
继续,只是仅限前台:

| 缺什么 | 结果 |
|---|---|
| 没传 `androidNotification` | 不启动服务。**这是默认行为** |
| `smallIcon` 在你的 App 里解析不到 | 不启动服务(错误的图标在部分 OEM 上显示空白、在部分上直接抛异常) |
| 没声明 `FOREGROUND_SERVICE` | 不启动服务 |

iOS 完全不需要这一套:插件用 `beginBackgroundTask` 申请一小段后台时间,**无 UI、无权限**。
`androidNotification` 在 iOS 和 Web 上被忽略。

#### 这个 service 在你的 APK 里是可见的

`<service>` 会合并进你的 manifest、编译进 APK 的二进制 `AndroidManifest.xml`,并且能通过
`PackageManager` 读到 —— 所以 **LibChecker** 这类 APK 分析工具会列出
`com.compress.all.flutter_compress.CompressionService`,并据此识别出你用了这个插件。
它不会运行,但名字在那里。

想追查合并后的**任何**一个元素是哪个依赖加进来的,看这份报告:

```
<你的 App>/build/app/outputs/logs/manifest-merger-<variant>-report.txt
```

每一条都会标明来源,例如
`service#…CompressionService  ADDED from [:flutter_compress]`。

如果你的 App 根本不需要后台压缩,把声明去掉即可 —— 组件列表里也就不会再有它:

```xml
<service android:name="com.compress.all.flutter_compress.CompressionService"
    tools:node="remove" />
```

### 原生依赖

| 依赖 | 版本 | 未压缩体积 | 说明 |
|---|---|---|---|
| `androidx.media3:media3-transformer` 及 `-effect`、`-common`、`-muxer` | 1.4.1 | 含传递依赖(ExoPlayer 等)约 3.4 MB AAR | 视频管线。R8 会裁掉相当大一部分,请以自己的 release 包实测为准 |
| `androidx.core:core-ktx` | 1.15.0 | 约 0.2 MB | 几乎必然已存在 —— Flutter 本身就会引入 `androidx.core` |
| `org.jetbrains.kotlinx:kotlinx-coroutines-android` | 1.8.1 | 约 20 KB | 通常也已存在 |

iOS 与 Web **不引入任何第三方原生依赖**:iOS 只用 SDK 自带的 AVFoundation 与
ImageIO,Web 用浏览器的 WebCodecs 加两个内置 JS(体积与许可证见
[THIRD_PARTY_NOTICES](assets/THIRD_PARTY_NOTICES.md))。

版本锁的是**实测过的**那一个,而不是浮动区间。Gradle 的冲突仲裁本来就向上取,所以
App 声明更高版本的 Media3 依然会生效 —— 但插件不会自己悄悄跟着升。(Media3 曾在
1.x 内部改掉 `DefaultMuxer.Factory` 一个参数的语义,把每个输出都截断成 30 秒,而
编译毫无警告。)

## 已知限制

- **Web(v1)**:丢弃音频,且暂不支持 `trim`。

## 许可证

MIT —— 见 [LICENSE](LICENSE)。
