// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Compresor de vídeo';

  @override
  String get language => 'Idioma';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get inputVideo => 'Vídeo de entrada';

  @override
  String get noFileSelected => 'Ningún archivo seleccionado';

  @override
  String get pickVideo => 'Elegir vídeo';

  @override
  String get outputFolder => 'Carpeta de salida (opcional)';

  @override
  String get outputHintAndroid =>
      'Android: siempre se guarda en Descargas públicas';

  @override
  String get outputHintOther => 'Documentos de la app / Descargas';

  @override
  String get pickFolder => 'Elegir carpeta';

  @override
  String get clear => 'Borrar';

  @override
  String get codec => 'Códec';

  @override
  String get quality => 'Calidad';

  @override
  String get targetSizeMb => 'Tamaño objetivo (MB)';

  @override
  String get qualityPercent => 'Calidad %';

  @override
  String get compressionMode => 'Modo de compresión';

  @override
  String get modeTargetSize => 'Tamaño objetivo';

  @override
  String get modeQuality => 'Calidad';

  @override
  String get qualityMode => 'Modo de calidad';

  @override
  String get modePreset => 'Preajuste';

  @override
  String get modeCustom => 'Personalizado %';

  @override
  String get tagline => 'Local · Sin subida · Sin marca de agua';

  @override
  String get reselectVideo => 'Reelegir vídeo';

  @override
  String get estimateTitle => 'Estimación';

  @override
  String get estimateBasedOn => 'Según los ajustes actuales';

  @override
  String get estOutput => 'Salida est.';

  @override
  String get estSaved => 'Ahorro';

  @override
  String get estFineness => 'Detalle est.';

  @override
  String get finenessFine => 'Fino';

  @override
  String get finenessBalanced => 'Equilibrado';

  @override
  String get finenessCoarse => 'Basto';

  @override
  String get sourceLabel => 'Original';

  @override
  String get finenessHintFine =>
      'Casi sin pérdida — ideal para archivar y reeditar.';

  @override
  String get finenessHintBalanced =>
      'Calidad y tamaño equilibrados — ideal para compartir.';

  @override
  String get finenessHintCoarse =>
      'Compresión fuerte — mejor para archivos muy pequeños.';

  @override
  String get navVideo => 'Vídeo';

  @override
  String get navImage => 'Imagen';

  @override
  String get imageTitle => 'Compresor de imágenes';

  @override
  String get inputImage => 'Imagen de entrada';

  @override
  String get pickImage => 'Elegir imagen';

  @override
  String get reselectImage => 'Reelegir imagen';

  @override
  String get format => 'Formato';

  @override
  String get targetSizeKb => 'Tamaño objetivo (KB)';

  @override
  String get off => 'desactivado';

  @override
  String get actionInfo => 'Información';

  @override
  String get actionEstimate => 'Estimar';

  @override
  String get actionCompress => 'Comprimir';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String logPickedInput(String path) {
    return 'entrada elegida: $path';
  }

  @override
  String logOutputDir(String dir) {
    return 'carpeta de salida: $dir';
  }

  @override
  String get logPickVideoFirst => 'elige un vídeo primero';

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
    return 'error de info: $error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return 'estimación: ~$size MB a $bitrate kbps -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return 'error de estimación: $error';
  }

  @override
  String get logPickValidVideoFirst => 'elige un vídeo válido primero';

  @override
  String logStoragePermission(String status) {
    return 'permiso de almacenamiento: $status';
  }

  @override
  String get logSkipped => 'omitido (la compresión no reduciría el tamaño)';

  @override
  String logDone(String size, String saved, String codec) {
    return 'listo: $size MB (ahorrado $saved%, $codec)';
  }

  @override
  String logSavedToDownloads(String path) {
    return 'guardado en Descargas: $path';
  }

  @override
  String logOutput(String path) {
    return 'salida: $path';
  }

  @override
  String get logCancelled => 'cancelado';

  @override
  String logError(String error) {
    return 'error: $error';
  }
}
