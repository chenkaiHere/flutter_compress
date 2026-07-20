// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Сжатие видео';

  @override
  String get language => 'Язык';

  @override
  String get systemDefault => 'Системный по умолчанию';

  @override
  String get inputVideo => 'Исходное видео';

  @override
  String get noFileSelected => 'Файл не выбран';

  @override
  String get pickVideo => 'Выбрать видео';

  @override
  String get outputFolder => 'Папка вывода (необязательно)';

  @override
  String get outputHintAndroid =>
      'Android: всегда сохраняется в общие Загрузки';

  @override
  String get outputHintOther => 'Документы приложения / Загрузки';

  @override
  String get pickFolder => 'Выбрать папку';

  @override
  String get clear => 'Очистить';

  @override
  String get codec => 'Кодек';

  @override
  String get quality => 'Качество';

  @override
  String get targetSizeMb => 'Целевой размер (МБ)';

  @override
  String get qualityPercent => 'Качество %';

  @override
  String get compressionMode => 'Режим сжатия';

  @override
  String get modeTargetSize => 'Целевой размер';

  @override
  String get modeQuality => 'Качество';

  @override
  String get qualityMode => 'Режим качества';

  @override
  String get modePreset => 'Пресет';

  @override
  String get modeCustom => 'Вручную %';

  @override
  String get tagline => 'Локально · Без загрузки · Без водяных знаков';

  @override
  String get reselectVideo => 'Выбрать другое видео';

  @override
  String get estimateTitle => 'Оценка';

  @override
  String get estimateBasedOn => 'На основе текущих настроек';

  @override
  String get estOutput => 'Ожид. вывод';

  @override
  String get estSaved => 'Экономия';

  @override
  String get estFineness => 'Ожид. детализация';

  @override
  String get finenessFine => 'Чётко';

  @override
  String get finenessBalanced => 'Баланс';

  @override
  String get finenessCoarse => 'Грубо';

  @override
  String get sourceLabel => 'Исходник';

  @override
  String get finenessHintFine => 'Почти без потерь — для архива и перемонтажа.';

  @override
  String get finenessHintBalanced =>
      'Баланс качества и размера — идеально для обмена.';

  @override
  String get finenessHintCoarse =>
      'Сильное сжатие — для очень маленьких файлов.';

  @override
  String get off => 'выкл';

  @override
  String get actionInfo => 'Информация';

  @override
  String get actionEstimate => 'Оценка';

  @override
  String get actionCompress => 'Сжать';

  @override
  String get actionCancel => 'Отмена';

  @override
  String logPickedInput(String path) {
    return 'выбран ввод: $path';
  }

  @override
  String logOutputDir(String dir) {
    return 'папка вывода: $dir';
  }

  @override
  String get logPickVideoFirst => 'сначала выберите видео';

  @override
  String logInfo(
    String width,
    String height,
    String size,
    String duration,
    String bitrate,
  ) {
    return 'инфо: ${width}x$height, $size МБ, $duration мс, $bitrate кбит/с';
  }

  @override
  String logInfoError(String error) {
    return 'ошибка инфо: $error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return 'оценка: ~$size МБ при $bitrate кбит/с -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return 'ошибка оценки: $error';
  }

  @override
  String get logPickValidVideoFirst => 'сначала выберите корректное видео';

  @override
  String logStoragePermission(String status) {
    return 'разрешение на хранилище: $status';
  }

  @override
  String get logSkipped => 'пропущено (сжатие не уменьшит размер)';

  @override
  String logDone(String size, String saved, String codec) {
    return 'готово: $size МБ (сэкономлено $saved%, $codec)';
  }

  @override
  String logSavedToDownloads(String path) {
    return 'сохранено в Загрузки: $path';
  }

  @override
  String logOutput(String path) {
    return 'вывод: $path';
  }

  @override
  String get logCancelled => 'отменено';

  @override
  String logError(String error) {
    return 'ошибка: $error';
  }
}
