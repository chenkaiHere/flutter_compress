// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '视频压缩';

  @override
  String get language => '语言';

  @override
  String get systemDefault => '跟随系统';

  @override
  String get inputVideo => '输入视频';

  @override
  String get noFileSelected => '未选择文件';

  @override
  String get pickVideo => '选择视频';

  @override
  String get outputFolder => '输出目录（可选）';

  @override
  String get outputHintAndroid => 'Android：始终保存到公共“下载”目录';

  @override
  String get outputHintOther => '应用文档 / 下载目录';

  @override
  String get pickFolder => '选择目录';

  @override
  String get clear => '清除';

  @override
  String get codec => '编码';

  @override
  String get quality => '质量';

  @override
  String get targetSizeMb => '目标大小 (MB)';

  @override
  String get qualityPercent => '质量 %';

  @override
  String get compressionMode => '压缩模式';

  @override
  String get modeTargetSize => '目标大小';

  @override
  String get modeQuality => '质量';

  @override
  String get qualityMode => '质量模式';

  @override
  String get modePreset => '预设档';

  @override
  String get modeCustom => '自定义 %';

  @override
  String get tagline => '本地处理 · 不上传 · 无水印';

  @override
  String get reselectVideo => '重新选择视频';

  @override
  String get estimateTitle => '压缩预估';

  @override
  String get estimateBasedOn => '基于当前设置';

  @override
  String get estOutput => '预计输出';

  @override
  String get estSaved => '节省空间';

  @override
  String get estFineness => '预估细腻度';

  @override
  String get finenessFine => '细腻';

  @override
  String get finenessBalanced => '均衡';

  @override
  String get finenessCoarse => '粗糙';

  @override
  String get sourceLabel => '原始';

  @override
  String get finenessHintFine => '几乎无损,适合归档与二次剪辑。';

  @override
  String get finenessHintBalanced => '画质与体积平衡,适合分享传播。';

  @override
  String get finenessHintCoarse => '压缩较重,适合极小体积场景。';

  @override
  String get navVideo => '视频';

  @override
  String get navImage => '图片';

  @override
  String get imageTitle => '图片压缩';

  @override
  String get inputImage => '输入图片';

  @override
  String get pickImage => '选择图片';

  @override
  String get reselectImage => '重新选择图片';

  @override
  String get format => '格式';

  @override
  String get formatOriginal => '原格式';

  @override
  String get targetSizeKb => '目标大小 (KB)';

  @override
  String get modeVisualLossless => '无损压缩';

  @override
  String get visualLosslessHint => '视觉无损,肉眼几乎无差;JPEG 也能压小。';

  @override
  String get off => '关闭';

  @override
  String get actionInfo => '信息';

  @override
  String get actionEstimate => '预估';

  @override
  String get actionCompress => '压缩';

  @override
  String get actionCancel => '取消';

  @override
  String logPickedInput(String path) {
    return '已选输入：$path';
  }

  @override
  String logOutputDir(String dir) {
    return '输出目录：$dir';
  }

  @override
  String get logPickVideoFirst => '请先选择一个视频';

  @override
  String logInfo(
    String width,
    String height,
    String size,
    String duration,
    String bitrate,
  ) {
    return '信息：${width}x$height，$size MB，$duration 毫秒，$bitrate kbps';
  }

  @override
  String logInfoError(String error) {
    return '读取信息出错：$error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return '预估：约 $size MB，$bitrate kbps -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return '预估出错：$error';
  }

  @override
  String get logPickValidVideoFirst => '请先选择一个有效的视频';

  @override
  String logStoragePermission(String status) {
    return '存储权限：$status';
  }

  @override
  String get logSkipped => '已跳过（压缩不会减小体积）';

  @override
  String logDone(String size, String saved, String codec) {
    return '完成：$size MB（节省 $saved%，$codec）';
  }

  @override
  String logSavedToDownloads(String path) {
    return '已保存到下载目录：$path';
  }

  @override
  String logOutput(String path) {
    return '输出：$path';
  }

  @override
  String get logCancelled => '已取消';

  @override
  String logError(String error) {
    return '错误：$error';
  }
}
