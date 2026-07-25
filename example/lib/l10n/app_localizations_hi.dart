// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'वीडियो कंप्रेसर';

  @override
  String get language => 'भाषा';

  @override
  String get systemDefault => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get inputVideo => 'इनपुट वीडियो';

  @override
  String get noFileSelected => 'कोई फ़ाइल चयनित नहीं';

  @override
  String get pickVideo => 'वीडियो चुनें';

  @override
  String get outputFolder => 'आउटपुट फ़ोल्डर (वैकल्पिक)';

  @override
  String get outputHintAndroid =>
      'Android: हमेशा सार्वजनिक Downloads में सहेजा जाता है';

  @override
  String get outputHintOther => 'ऐप दस्तावेज़ / Downloads';

  @override
  String get pickFolder => 'फ़ोल्डर चुनें';

  @override
  String get clear => 'साफ़ करें';

  @override
  String get codec => 'कोडेक';

  @override
  String get quality => 'गुणवत्ता';

  @override
  String get targetSizeMb => 'लक्ष्य आकार (MB)';

  @override
  String get qualityPercent => 'गुणवत्ता %';

  @override
  String get compressionMode => 'कंप्रेशन मोड';

  @override
  String get modeTargetSize => 'लक्ष्य आकार';

  @override
  String get modeQuality => 'गुणवत्ता';

  @override
  String get qualityMode => 'गुणवत्ता मोड';

  @override
  String get modePreset => 'प्रीसेट';

  @override
  String get modeCustom => 'कस्टम %';

  @override
  String get tagline => 'लोकल · कोई अपलोड नहीं · कोई वॉटरमार्क नहीं';

  @override
  String get reselectVideo => 'वीडियो दोबारा चुनें';

  @override
  String get estimateTitle => 'अनुमान';

  @override
  String get estimateBasedOn => 'मौजूदा सेटिंग्स के आधार पर';

  @override
  String get estOutput => 'अनुमानित आउटपुट';

  @override
  String get estSaved => 'बचत';

  @override
  String get estFineness => 'अनुमानित बारीकी';

  @override
  String get finenessFine => 'बारीक';

  @override
  String get finenessBalanced => 'संतुलित';

  @override
  String get finenessCoarse => 'मोटा';

  @override
  String get sourceLabel => 'मूल';

  @override
  String get finenessHintFine =>
      'लगभग हानिरहित — संग्रह और पुनः संपादन के लिए बढ़िया।';

  @override
  String get finenessHintBalanced =>
      'गुणवत्ता और आकार संतुलित — साझा करने के लिए आदर्श।';

  @override
  String get finenessHintCoarse =>
      'अधिक कंप्रेशन — बहुत छोटी फ़ाइलों के लिए सर्वोत्तम।';

  @override
  String get navVideo => 'वीडियो';

  @override
  String get navImage => 'छवि';

  @override
  String get imageTitle => 'छवि कंप्रेसर';

  @override
  String get inputImage => 'इनपुट छवि';

  @override
  String get pickImage => 'छवि चुनें';

  @override
  String get reselectImage => 'छवि दोबारा चुनें';

  @override
  String get format => 'फ़ॉर्मेट';

  @override
  String get targetSizeKb => 'लक्ष्य आकार (KB)';

  @override
  String get off => 'बंद';

  @override
  String get actionInfo => 'जानकारी';

  @override
  String get actionEstimate => 'अनुमान';

  @override
  String get actionCompress => 'कंप्रेस';

  @override
  String get actionCancel => 'रद्द करें';

  @override
  String logPickedInput(String path) {
    return 'चयनित इनपुट: $path';
  }

  @override
  String logOutputDir(String dir) {
    return 'आउटपुट फ़ोल्डर: $dir';
  }

  @override
  String get logPickVideoFirst => 'पहले एक वीडियो चुनें';

  @override
  String logInfo(
    String width,
    String height,
    String size,
    String duration,
    String bitrate,
  ) {
    return 'जानकारी: ${width}x$height, $size MB, $duration ms, $bitrate kbps';
  }

  @override
  String logInfoError(String error) {
    return 'जानकारी त्रुटि: $error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return 'अनुमान: ~$size MB @ $bitrate kbps -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return 'अनुमान त्रुटि: $error';
  }

  @override
  String get logPickValidVideoFirst => 'पहले एक मान्य वीडियो चुनें';

  @override
  String logStoragePermission(String status) {
    return 'स्टोरेज अनुमति: $status';
  }

  @override
  String get logSkipped => 'छोड़ा गया (कंप्रेशन से आकार कम नहीं होगा)';

  @override
  String logDone(String size, String saved, String codec) {
    return 'पूर्ण: $size MB ($saved% बचत, $codec)';
  }

  @override
  String logSavedToDownloads(String path) {
    return 'Downloads में सहेजा गया: $path';
  }

  @override
  String logOutput(String path) {
    return 'आउटपुट: $path';
  }

  @override
  String get logCancelled => 'रद्द किया गया';

  @override
  String logError(String error) {
    return 'त्रुटि: $error';
  }
}
