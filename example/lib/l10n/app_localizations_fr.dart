// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Compresseur vidéo';

  @override
  String get language => 'Langue';

  @override
  String get systemDefault => 'Par défaut du système';

  @override
  String get inputVideo => 'Vidéo d\'entrée';

  @override
  String get noFileSelected => 'Aucun fichier sélectionné';

  @override
  String get pickVideo => 'Choisir une vidéo';

  @override
  String get outputFolder => 'Dossier de sortie (facultatif)';

  @override
  String get outputHintAndroid =>
      'Android : toujours enregistré dans Téléchargements';

  @override
  String get outputHintOther => 'Documents de l\'app / Téléchargements';

  @override
  String get pickFolder => 'Choisir un dossier';

  @override
  String get clear => 'Effacer';

  @override
  String get codec => 'Codec';

  @override
  String get quality => 'Qualité';

  @override
  String get targetSizeMb => 'Taille cible (Mo)';

  @override
  String get qualityPercent => 'Qualité %';

  @override
  String get compressionMode => 'Mode de compression';

  @override
  String get modeTargetSize => 'Taille cible';

  @override
  String get modeQuality => 'Qualité';

  @override
  String get qualityMode => 'Mode de qualité';

  @override
  String get modePreset => 'Préréglage';

  @override
  String get modeCustom => 'Personnalisé %';

  @override
  String get tagline => 'Local · Sans upload · Sans filigrane';

  @override
  String get reselectVideo => 'Choisir une autre vidéo';

  @override
  String get estimateTitle => 'Estimation';

  @override
  String get estimateBasedOn => 'Selon les réglages actuels';

  @override
  String get estOutput => 'Sortie est.';

  @override
  String get estSaved => 'Économie';

  @override
  String get estFineness => 'Détail est.';

  @override
  String get finenessFine => 'Fin';

  @override
  String get finenessBalanced => 'Équilibré';

  @override
  String get finenessCoarse => 'Grossier';

  @override
  String get sourceLabel => 'Source';

  @override
  String get finenessHintFine =>
      'Quasi sans perte — idéal pour l\'archivage et le montage.';

  @override
  String get finenessHintBalanced =>
      'Qualité et taille équilibrées — idéal pour le partage.';

  @override
  String get finenessHintCoarse =>
      'Compression forte — pour des fichiers très légers.';

  @override
  String get navVideo => 'Vidéo';

  @override
  String get navImage => 'Image';

  @override
  String get imageTitle => 'Compresseur d\'images';

  @override
  String get inputImage => 'Image d\'entrée';

  @override
  String get pickImage => 'Choisir une image';

  @override
  String get reselectImage => 'Choisir une autre image';

  @override
  String get format => 'Format';

  @override
  String get formatOriginal => 'Original';

  @override
  String get targetSizeKb => 'Taille cible (Ko)';

  @override
  String get modeVisualLossless => 'Sans perte';

  @override
  String get visualLosslessHint =>
      'Sans perte visible — réduit aussi les JPEG, aspect identique.';

  @override
  String get off => 'désactivé';

  @override
  String get actionInfo => 'Infos';

  @override
  String get actionEstimate => 'Estimer';

  @override
  String get actionCompress => 'Compresser';

  @override
  String get actionCancel => 'Annuler';

  @override
  String logPickedInput(String path) {
    return 'entrée choisie : $path';
  }

  @override
  String logOutputDir(String dir) {
    return 'dossier de sortie : $dir';
  }

  @override
  String get logPickVideoFirst => 'choisissez d\'abord une vidéo';

  @override
  String logInfo(
    String width,
    String height,
    String size,
    String duration,
    String bitrate,
  ) {
    return 'infos : ${width}x$height, $size Mo, $duration ms, $bitrate kbps';
  }

  @override
  String logInfoError(String error) {
    return 'erreur d\'infos : $error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return 'estimation : ~$size Mo à $bitrate kbps -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return 'erreur d\'estimation : $error';
  }

  @override
  String get logPickValidVideoFirst => 'choisissez d\'abord une vidéo valide';

  @override
  String logStoragePermission(String status) {
    return 'permission de stockage : $status';
  }

  @override
  String get logSkipped => 'ignoré (la compression ne réduirait pas la taille)';

  @override
  String logDone(String size, String saved, String codec) {
    return 'terminé : $size Mo (économisé $saved %, $codec)';
  }

  @override
  String logSavedToDownloads(String path) {
    return 'enregistré dans Téléchargements : $path';
  }

  @override
  String logOutput(String path) {
    return 'sortie : $path';
  }

  @override
  String get logCancelled => 'annulé';

  @override
  String logError(String error) {
    return 'erreur : $error';
  }
}
