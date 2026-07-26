// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Video Compressor';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System default';

  @override
  String get inputVideo => 'Input video';

  @override
  String get noFileSelected => 'No file selected';

  @override
  String get pickVideo => 'Pick video';

  @override
  String get outputFolder => 'Output folder (optional)';

  @override
  String get outputHintAndroid => 'Android: always saved to public Downloads';

  @override
  String get outputHintOther => 'App documents / Downloads';

  @override
  String get pickFolder => 'Pick folder';

  @override
  String get clear => 'Clear';

  @override
  String get codec => 'Codec';

  @override
  String get quality => 'Quality';

  @override
  String get targetSizeMb => 'Target size (MB)';

  @override
  String get qualityPercent => 'Quality %';

  @override
  String get compressionMode => 'Compression mode';

  @override
  String get modeTargetSize => 'Target size';

  @override
  String get modeQuality => 'Quality';

  @override
  String get qualityMode => 'Quality mode';

  @override
  String get modePreset => 'Preset';

  @override
  String get modeCustom => 'Custom %';

  @override
  String get tagline => 'Local · No upload · No watermark';

  @override
  String get reselectVideo => 'Reselect video';

  @override
  String get estimateTitle => 'Estimate';

  @override
  String get estimateBasedOn => 'Based on current settings';

  @override
  String get estOutput => 'Est. output';

  @override
  String get estSaved => 'Saved';

  @override
  String get estFineness => 'Est. detail';

  @override
  String get finenessFine => 'Fine';

  @override
  String get finenessBalanced => 'Balanced';

  @override
  String get finenessCoarse => 'Coarse';

  @override
  String get sourceLabel => 'Source';

  @override
  String get finenessHintFine =>
      'Near-lossless — great for archiving and re-editing.';

  @override
  String get finenessHintBalanced =>
      'Balanced quality and size — ideal for sharing.';

  @override
  String get finenessHintCoarse =>
      'Heavier compression — best for very small files.';

  @override
  String get navVideo => 'Video';

  @override
  String get navImage => 'Image';

  @override
  String get imageTitle => 'Image Compressor';

  @override
  String get inputImage => 'Input image';

  @override
  String get pickImage => 'Pick image';

  @override
  String get reselectImage => 'Reselect image';

  @override
  String get format => 'Format';

  @override
  String get formatOriginal => 'Original';

  @override
  String get targetSizeKb => 'Target size (KB)';

  @override
  String get modeVisualLossless => 'Lossless';

  @override
  String get visualLosslessHint =>
      'Visually lossless — shrinks JPEGs too, looks identical.';

  @override
  String get off => 'off';

  @override
  String get actionInfo => 'Info';

  @override
  String get actionEstimate => 'Estimate';

  @override
  String get actionCompress => 'Compress';

  @override
  String get actionCancel => 'Cancel';

  @override
  String logPickedInput(String path) {
    return 'picked input: $path';
  }

  @override
  String logOutputDir(String dir) {
    return 'output dir: $dir';
  }

  @override
  String get logPickVideoFirst => 'pick a video first';

  @override
  String logInfo(
    String width,
    String height,
    String size,
    String duration,
    String bitrate,
  ) {
    return 'info: ${width}x$height, $size MB, $duration ms, $bitrate kbps';
  }

  @override
  String logInfoError(String error) {
    return 'info error: $error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return 'estimate: ~$size MB at $bitrate kbps -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return 'estimate error: $error';
  }

  @override
  String get logPickValidVideoFirst => 'pick a valid video first';

  @override
  String logStoragePermission(String status) {
    return 'storage permission: $status';
  }

  @override
  String get logSkipped => 'skipped (compression would not reduce size)';

  @override
  String logDone(String size, String saved, String codec) {
    return 'done: $size MB (saved $saved%, $codec)';
  }

  @override
  String logSavedToDownloads(String path) {
    return 'saved to Downloads: $path';
  }

  @override
  String logOutput(String path) {
    return 'output: $path';
  }

  @override
  String get logCancelled => 'cancelled';

  @override
  String logError(String error) {
    return 'error: $error';
  }
}
