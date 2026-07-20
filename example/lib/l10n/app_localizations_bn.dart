// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'ভিডিও কম্প্রেসর';

  @override
  String get language => 'ভাষা';

  @override
  String get systemDefault => 'সিস্টেম ডিফল্ট';

  @override
  String get inputVideo => 'ইনপুট ভিডিও';

  @override
  String get noFileSelected => 'কোনো ফাইল নির্বাচিত হয়নি';

  @override
  String get pickVideo => 'ভিডিও নির্বাচন করুন';

  @override
  String get outputFolder => 'আউটপুট ফোল্ডার (ঐচ্ছিক)';

  @override
  String get outputHintAndroid =>
      'অ্যান্ড্রয়েড: সবসময় পাবলিক ডাউনলোডসে সংরক্ষিত';

  @override
  String get outputHintOther => 'অ্যাপ ডকুমেন্টস / ডাউনলোডস';

  @override
  String get pickFolder => 'ফোল্ডার নির্বাচন করুন';

  @override
  String get clear => 'মুছুন';

  @override
  String get codec => 'কোডেক';

  @override
  String get quality => 'মান';

  @override
  String get targetSizeMb => 'লক্ষ্য আকার (MB)';

  @override
  String get qualityPercent => 'মান %';

  @override
  String get compressionMode => 'কম্প্রেশন মোড';

  @override
  String get modeTargetSize => 'লক্ষ্য আকার';

  @override
  String get modeQuality => 'মান';

  @override
  String get qualityMode => 'মান মোড';

  @override
  String get modePreset => 'প্রিসেট';

  @override
  String get modeCustom => 'কাস্টম %';

  @override
  String get tagline => 'লোকাল · আপলোড নেই · ওয়াটারমার্ক নেই';

  @override
  String get reselectVideo => 'আবার ভিডিও নির্বাচন করুন';

  @override
  String get estimateTitle => 'অনুমান';

  @override
  String get estimateBasedOn => 'বর্তমান সেটিংস অনুযায়ী';

  @override
  String get estOutput => 'আনুমানিক আউটপুট';

  @override
  String get estSaved => 'সাশ্রয়';

  @override
  String get estFineness => 'আনুমানিক বিশদতা';

  @override
  String get finenessFine => 'সূক্ষ্ম';

  @override
  String get finenessBalanced => 'সুষম';

  @override
  String get finenessCoarse => 'মোটা';

  @override
  String get sourceLabel => 'মূল';

  @override
  String get finenessHintFine =>
      'প্রায় লসলেস — আর্কাইভ ও পুনঃসম্পাদনার জন্য উপযুক্ত।';

  @override
  String get finenessHintBalanced =>
      'মান ও আকারের ভারসাম্য — শেয়ারের জন্য আদর্শ।';

  @override
  String get finenessHintCoarse => 'বেশি কম্প্রেশন — খুব ছোট ফাইলের জন্য সেরা।';

  @override
  String get off => 'বন্ধ';

  @override
  String get actionInfo => 'তথ্য';

  @override
  String get actionEstimate => 'অনুমান';

  @override
  String get actionCompress => 'কম্প্রেস';

  @override
  String get actionCancel => 'বাতিল';

  @override
  String logPickedInput(String path) {
    return 'নির্বাচিত ইনপুট: $path';
  }

  @override
  String logOutputDir(String dir) {
    return 'আউটপুট ফোল্ডার: $dir';
  }

  @override
  String get logPickVideoFirst => 'প্রথমে একটি ভিডিও নির্বাচন করুন';

  @override
  String logInfo(
    String width,
    String height,
    String size,
    String duration,
    String bitrate,
  ) {
    return 'তথ্য: ${width}x$height, $size MB, $duration ms, $bitrate kbps';
  }

  @override
  String logInfoError(String error) {
    return 'তথ্য ত্রুটি: $error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return 'অনুমান: ~$size MB, $bitrate kbps -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return 'অনুমান ত্রুটি: $error';
  }

  @override
  String get logPickValidVideoFirst => 'প্রথমে একটি বৈধ ভিডিও নির্বাচন করুন';

  @override
  String logStoragePermission(String status) {
    return 'স্টোরেজ অনুমতি: $status';
  }

  @override
  String get logSkipped => 'এড়িয়ে যাওয়া হয়েছে (কম্প্রেশন আকার কমাবে না)';

  @override
  String logDone(String size, String saved, String codec) {
    return 'সম্পন্ন: $size MB ($saved% সাশ্রয়, $codec)';
  }

  @override
  String logSavedToDownloads(String path) {
    return 'ডাউনলোডসে সংরক্ষিত: $path';
  }

  @override
  String logOutput(String path) {
    return 'আউটপুট: $path';
  }

  @override
  String get logCancelled => 'বাতিল করা হয়েছে';

  @override
  String logError(String error) {
    return 'ত্রুটি: $error';
  }
}
