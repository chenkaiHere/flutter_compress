import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('bn'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('ur'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Video Compressor'**
  String get appTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @inputVideo.
  ///
  /// In en, this message translates to:
  /// **'Input video'**
  String get inputVideo;

  /// No description provided for @noFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get noFileSelected;

  /// No description provided for @pickVideo.
  ///
  /// In en, this message translates to:
  /// **'Pick video'**
  String get pickVideo;

  /// No description provided for @outputFolder.
  ///
  /// In en, this message translates to:
  /// **'Output folder (optional)'**
  String get outputFolder;

  /// No description provided for @outputHintAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android: always saved to public Downloads'**
  String get outputHintAndroid;

  /// No description provided for @outputHintOther.
  ///
  /// In en, this message translates to:
  /// **'App documents / Downloads'**
  String get outputHintOther;

  /// No description provided for @pickFolder.
  ///
  /// In en, this message translates to:
  /// **'Pick folder'**
  String get pickFolder;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @codec.
  ///
  /// In en, this message translates to:
  /// **'Codec'**
  String get codec;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @targetSizeMb.
  ///
  /// In en, this message translates to:
  /// **'Target size (MB)'**
  String get targetSizeMb;

  /// No description provided for @qualityPercent.
  ///
  /// In en, this message translates to:
  /// **'Quality %'**
  String get qualityPercent;

  /// No description provided for @compressionMode.
  ///
  /// In en, this message translates to:
  /// **'Compression mode'**
  String get compressionMode;

  /// No description provided for @modeTargetSize.
  ///
  /// In en, this message translates to:
  /// **'Target size'**
  String get modeTargetSize;

  /// No description provided for @modeQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get modeQuality;

  /// No description provided for @qualityMode.
  ///
  /// In en, this message translates to:
  /// **'Quality mode'**
  String get qualityMode;

  /// No description provided for @modePreset.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get modePreset;

  /// No description provided for @modeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom %'**
  String get modeCustom;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Local · No upload · No watermark'**
  String get tagline;

  /// No description provided for @reselectVideo.
  ///
  /// In en, this message translates to:
  /// **'Reselect video'**
  String get reselectVideo;

  /// No description provided for @estimateTitle.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get estimateTitle;

  /// No description provided for @estimateBasedOn.
  ///
  /// In en, this message translates to:
  /// **'Based on current settings'**
  String get estimateBasedOn;

  /// No description provided for @estOutput.
  ///
  /// In en, this message translates to:
  /// **'Est. output'**
  String get estOutput;

  /// No description provided for @estSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get estSaved;

  /// No description provided for @estFineness.
  ///
  /// In en, this message translates to:
  /// **'Est. detail'**
  String get estFineness;

  /// No description provided for @finenessFine.
  ///
  /// In en, this message translates to:
  /// **'Fine'**
  String get finenessFine;

  /// No description provided for @finenessBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get finenessBalanced;

  /// No description provided for @finenessCoarse.
  ///
  /// In en, this message translates to:
  /// **'Coarse'**
  String get finenessCoarse;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceLabel;

  /// No description provided for @finenessHintFine.
  ///
  /// In en, this message translates to:
  /// **'Near-lossless — great for archiving and re-editing.'**
  String get finenessHintFine;

  /// No description provided for @finenessHintBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced quality and size — ideal for sharing.'**
  String get finenessHintBalanced;

  /// No description provided for @finenessHintCoarse.
  ///
  /// In en, this message translates to:
  /// **'Heavier compression — best for very small files.'**
  String get finenessHintCoarse;

  /// No description provided for @navVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get navVideo;

  /// No description provided for @navImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get navImage;

  /// No description provided for @imageTitle.
  ///
  /// In en, this message translates to:
  /// **'Image Compressor'**
  String get imageTitle;

  /// No description provided for @inputImage.
  ///
  /// In en, this message translates to:
  /// **'Input image'**
  String get inputImage;

  /// No description provided for @pickImage.
  ///
  /// In en, this message translates to:
  /// **'Pick image'**
  String get pickImage;

  /// No description provided for @reselectImage.
  ///
  /// In en, this message translates to:
  /// **'Reselect image'**
  String get reselectImage;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @targetSizeKb.
  ///
  /// In en, this message translates to:
  /// **'Target size (KB)'**
  String get targetSizeKb;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get off;

  /// No description provided for @actionInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get actionInfo;

  /// No description provided for @actionEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get actionEstimate;

  /// No description provided for @actionCompress.
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get actionCompress;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @logPickedInput.
  ///
  /// In en, this message translates to:
  /// **'picked input: {path}'**
  String logPickedInput(String path);

  /// No description provided for @logOutputDir.
  ///
  /// In en, this message translates to:
  /// **'output dir: {dir}'**
  String logOutputDir(String dir);

  /// No description provided for @logPickVideoFirst.
  ///
  /// In en, this message translates to:
  /// **'pick a video first'**
  String get logPickVideoFirst;

  /// No description provided for @logInfo.
  ///
  /// In en, this message translates to:
  /// **'info: {width}x{height}, {size} MB, {duration} ms, {bitrate} kbps'**
  String logInfo(
    String width,
    String height,
    String size,
    String duration,
    String bitrate,
  );

  /// No description provided for @logInfoError.
  ///
  /// In en, this message translates to:
  /// **'info error: {error}'**
  String logInfoError(String error);

  /// No description provided for @logEstimate.
  ///
  /// In en, this message translates to:
  /// **'estimate: ~{size} MB at {bitrate} kbps -> {width}x{height}'**
  String logEstimate(String size, String bitrate, String width, String height);

  /// No description provided for @logEstimateError.
  ///
  /// In en, this message translates to:
  /// **'estimate error: {error}'**
  String logEstimateError(String error);

  /// No description provided for @logPickValidVideoFirst.
  ///
  /// In en, this message translates to:
  /// **'pick a valid video first'**
  String get logPickValidVideoFirst;

  /// No description provided for @logStoragePermission.
  ///
  /// In en, this message translates to:
  /// **'storage permission: {status}'**
  String logStoragePermission(String status);

  /// No description provided for @logSkipped.
  ///
  /// In en, this message translates to:
  /// **'skipped (compression would not reduce size)'**
  String get logSkipped;

  /// No description provided for @logDone.
  ///
  /// In en, this message translates to:
  /// **'done: {size} MB (saved {saved}%, {codec})'**
  String logDone(String size, String saved, String codec);

  /// No description provided for @logSavedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'saved to Downloads: {path}'**
  String logSavedToDownloads(String path);

  /// No description provided for @logOutput.
  ///
  /// In en, this message translates to:
  /// **'output: {path}'**
  String logOutput(String path);

  /// No description provided for @logCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get logCancelled;

  /// No description provided for @logError.
  ///
  /// In en, this message translates to:
  /// **'error: {error}'**
  String logError(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'bn',
    'en',
    'es',
    'fr',
    'hi',
    'ja',
    'ko',
    'pt',
    'ru',
    'ur',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'ur':
      return AppLocalizationsUr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
