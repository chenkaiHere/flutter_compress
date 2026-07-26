// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appTitle => 'ویڈیو کمپریسر';

  @override
  String get language => 'زبان';

  @override
  String get systemDefault => 'سسٹم ڈیفالٹ';

  @override
  String get inputVideo => 'ان پٹ ویڈیو';

  @override
  String get noFileSelected => 'کوئی فائل منتخب نہیں';

  @override
  String get pickVideo => 'ویڈیو منتخب کریں';

  @override
  String get outputFolder => 'آؤٹ پٹ فولڈر (اختیاری)';

  @override
  String get outputHintAndroid => 'اینڈرائیڈ: ہمیشہ عوامی ڈاؤن لوڈز میں محفوظ';

  @override
  String get outputHintOther => 'ایپ دستاویزات / ڈاؤن لوڈز';

  @override
  String get pickFolder => 'فولڈر منتخب کریں';

  @override
  String get clear => 'صاف کریں';

  @override
  String get codec => 'کوڈیک';

  @override
  String get quality => 'معیار';

  @override
  String get targetSizeMb => 'ہدف سائز (MB)';

  @override
  String get qualityPercent => 'معیار %';

  @override
  String get compressionMode => 'کمپریشن موڈ';

  @override
  String get modeTargetSize => 'ہدف سائز';

  @override
  String get modeQuality => 'معیار';

  @override
  String get qualityMode => 'معیار موڈ';

  @override
  String get modePreset => 'پہلے سے طے شدہ';

  @override
  String get modeCustom => 'حسب ضرورت %';

  @override
  String get tagline => 'لوکل · کوئی اپ لوڈ نہیں · کوئی واٹر مارک نہیں';

  @override
  String get reselectVideo => 'ویڈیو دوبارہ منتخب کریں';

  @override
  String get estimateTitle => 'تخمینہ';

  @override
  String get estimateBasedOn => 'موجودہ ترتیبات کی بنیاد پر';

  @override
  String get estOutput => 'متوقع آؤٹ پٹ';

  @override
  String get estSaved => 'بچت';

  @override
  String get estFineness => 'متوقع باریکی';

  @override
  String get finenessFine => 'باریک';

  @override
  String get finenessBalanced => 'متوازن';

  @override
  String get finenessCoarse => 'کھردرا';

  @override
  String get sourceLabel => 'اصل';

  @override
  String get finenessHintFine =>
      'تقریباً بغیر نقصان — آرکائیو اور دوبارہ ایڈیٹنگ کے لیے بہترین۔';

  @override
  String get finenessHintBalanced =>
      'معیار اور سائز کا توازن — شیئرنگ کے لیے مثالی۔';

  @override
  String get finenessHintCoarse =>
      'زیادہ کمپریشن — بہت چھوٹی فائلوں کے لیے بہترین۔';

  @override
  String get navVideo => 'ویڈیو';

  @override
  String get navImage => 'تصویر';

  @override
  String get imageTitle => 'تصویر کمپریسر';

  @override
  String get inputImage => 'ان پٹ تصویر';

  @override
  String get pickImage => 'تصویر منتخب کریں';

  @override
  String get reselectImage => 'تصویر دوبارہ منتخب کریں';

  @override
  String get format => 'فارمیٹ';

  @override
  String get formatOriginal => 'اصل';

  @override
  String get targetSizeKb => 'ہدف سائز (KB)';

  @override
  String get modeVisualLossless => 'بلا نقصان';

  @override
  String get visualLosslessHint =>
      'بصری طور پر بلا نقصان — JPEG کو بھی چھوٹا کرتا ہے، دیکھنے میں یکساں۔';

  @override
  String get off => 'بند';

  @override
  String get actionInfo => 'معلومات';

  @override
  String get actionEstimate => 'تخمینہ';

  @override
  String get actionCompress => 'کمپریس';

  @override
  String get actionCancel => 'منسوخ';

  @override
  String logPickedInput(String path) {
    return 'منتخب ان پٹ: $path';
  }

  @override
  String logOutputDir(String dir) {
    return 'آؤٹ پٹ فولڈر: $dir';
  }

  @override
  String get logPickVideoFirst => 'پہلے ایک ویڈیو منتخب کریں';

  @override
  String logInfo(
    String width,
    String height,
    String size,
    String duration,
    String bitrate,
  ) {
    return 'معلومات: ${width}x$height، $size MB، $duration ms، $bitrate kbps';
  }

  @override
  String logInfoError(String error) {
    return 'معلومات میں خرابی: $error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return 'تخمینہ: ~$size MB بمطابق $bitrate kbps -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return 'تخمینے میں خرابی: $error';
  }

  @override
  String get logPickValidVideoFirst => 'پہلے ایک درست ویڈیو منتخب کریں';

  @override
  String logStoragePermission(String status) {
    return 'اسٹوریج اجازت: $status';
  }

  @override
  String get logSkipped => 'چھوڑ دیا گیا (کمپریشن سے سائز کم نہیں ہوگا)';

  @override
  String logDone(String size, String saved, String codec) {
    return 'مکمل: $size MB ($saved% بچت، $codec)';
  }

  @override
  String logSavedToDownloads(String path) {
    return 'ڈاؤن لوڈز میں محفوظ: $path';
  }

  @override
  String logOutput(String path) {
    return 'آؤٹ پٹ: $path';
  }

  @override
  String get logCancelled => 'منسوخ';

  @override
  String logError(String error) {
    return 'خرابی: $error';
  }
}
