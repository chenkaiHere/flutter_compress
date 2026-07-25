// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'ضاغط الفيديو';

  @override
  String get language => 'اللغة';

  @override
  String get systemDefault => 'افتراضي النظام';

  @override
  String get inputVideo => 'فيديو الإدخال';

  @override
  String get noFileSelected => 'لم يتم اختيار ملف';

  @override
  String get pickVideo => 'اختر فيديو';

  @override
  String get outputFolder => 'مجلد الإخراج (اختياري)';

  @override
  String get outputHintAndroid =>
      'أندرويد: يُحفظ دائمًا في مجلد التنزيلات العام';

  @override
  String get outputHintOther => 'مستندات التطبيق / التنزيلات';

  @override
  String get pickFolder => 'اختر مجلدًا';

  @override
  String get clear => 'مسح';

  @override
  String get codec => 'الترميز';

  @override
  String get quality => 'الجودة';

  @override
  String get targetSizeMb => 'الحجم المستهدف (ميغابايت)';

  @override
  String get qualityPercent => 'الجودة %';

  @override
  String get compressionMode => 'وضع الضغط';

  @override
  String get modeTargetSize => 'الحجم المستهدف';

  @override
  String get modeQuality => 'الجودة';

  @override
  String get qualityMode => 'وضع الجودة';

  @override
  String get modePreset => 'إعداد مسبق';

  @override
  String get modeCustom => 'مخصص %';

  @override
  String get tagline => 'محلي · بدون رفع · بدون علامة مائية';

  @override
  String get reselectVideo => 'إعادة اختيار الفيديو';

  @override
  String get estimateTitle => 'التقدير';

  @override
  String get estimateBasedOn => 'حسب الإعدادات الحالية';

  @override
  String get estOutput => 'الإخراج المقدّر';

  @override
  String get estSaved => 'توفير';

  @override
  String get estFineness => 'التفاصيل المقدّرة';

  @override
  String get finenessFine => 'دقيق';

  @override
  String get finenessBalanced => 'متوازن';

  @override
  String get finenessCoarse => 'خشن';

  @override
  String get sourceLabel => 'الأصل';

  @override
  String get finenessHintFine => 'شبه خالٍ من الفقد — مثالي للأرشفة والتحرير.';

  @override
  String get finenessHintBalanced =>
      'توازن بين الجودة والحجم — مثالي للمشاركة.';

  @override
  String get finenessHintCoarse => 'ضغط أقوى — الأفضل للملفات الصغيرة جدًا.';

  @override
  String get navVideo => 'فيديو';

  @override
  String get navImage => 'صورة';

  @override
  String get imageTitle => 'ضاغط الصور';

  @override
  String get inputImage => 'صورة الإدخال';

  @override
  String get pickImage => 'اختر صورة';

  @override
  String get reselectImage => 'إعادة اختيار الصورة';

  @override
  String get format => 'الصيغة';

  @override
  String get targetSizeKb => 'الحجم المستهدف (كيلوبايت)';

  @override
  String get off => 'إيقاف';

  @override
  String get actionInfo => 'معلومات';

  @override
  String get actionEstimate => 'تقدير';

  @override
  String get actionCompress => 'ضغط';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String logPickedInput(String path) {
    return 'الإدخال المختار: $path';
  }

  @override
  String logOutputDir(String dir) {
    return 'مجلد الإخراج: $dir';
  }

  @override
  String get logPickVideoFirst => 'اختر فيديو أولاً';

  @override
  String logInfo(
    String width,
    String height,
    String size,
    String duration,
    String bitrate,
  ) {
    return 'معلومات: ${width}x$height، $size ميغابايت، $duration مللي ثانية، $bitrate كيلوبت/ث';
  }

  @override
  String logInfoError(String error) {
    return 'خطأ في المعلومات: $error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return 'تقدير: ~$size ميغابايت عند $bitrate كيلوبت/ث -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return 'خطأ في التقدير: $error';
  }

  @override
  String get logPickValidVideoFirst => 'اختر فيديو صالحًا أولاً';

  @override
  String logStoragePermission(String status) {
    return 'إذن التخزين: $status';
  }

  @override
  String get logSkipped => 'تم التخطي (الضغط لن يقلل الحجم)';

  @override
  String logDone(String size, String saved, String codec) {
    return 'تم: $size ميغابايت (توفير $saved%، $codec)';
  }

  @override
  String logSavedToDownloads(String path) {
    return 'تم الحفظ في التنزيلات: $path';
  }

  @override
  String logOutput(String path) {
    return 'الإخراج: $path';
  }

  @override
  String get logCancelled => 'أُلغي';

  @override
  String logError(String error) {
    return 'خطأ: $error';
  }
}
