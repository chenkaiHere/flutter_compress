// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Compressor de vídeo';

  @override
  String get language => 'Idioma';

  @override
  String get systemDefault => 'Padrão do sistema';

  @override
  String get inputVideo => 'Vídeo de entrada';

  @override
  String get noFileSelected => 'Nenhum arquivo selecionado';

  @override
  String get pickVideo => 'Escolher vídeo';

  @override
  String get outputFolder => 'Pasta de saída (opcional)';

  @override
  String get outputHintAndroid => 'Android: sempre salvo em Downloads públicos';

  @override
  String get outputHintOther => 'Documentos do app / Downloads';

  @override
  String get pickFolder => 'Escolher pasta';

  @override
  String get clear => 'Limpar';

  @override
  String get codec => 'Codec';

  @override
  String get quality => 'Qualidade';

  @override
  String get targetSizeMb => 'Tamanho alvo (MB)';

  @override
  String get qualityPercent => 'Qualidade %';

  @override
  String get compressionMode => 'Modo de compressão';

  @override
  String get modeTargetSize => 'Tamanho alvo';

  @override
  String get modeQuality => 'Qualidade';

  @override
  String get qualityMode => 'Modo de qualidade';

  @override
  String get modePreset => 'Predefinição';

  @override
  String get modeCustom => 'Personalizado %';

  @override
  String get tagline => 'Local · Sem upload · Sem marca d\'água';

  @override
  String get reselectVideo => 'Reselecionar vídeo';

  @override
  String get estimateTitle => 'Estimativa';

  @override
  String get estimateBasedOn => 'Com base nas configurações atuais';

  @override
  String get estOutput => 'Saída est.';

  @override
  String get estSaved => 'Economia';

  @override
  String get estFineness => 'Detalhe est.';

  @override
  String get finenessFine => 'Fino';

  @override
  String get finenessBalanced => 'Equilibrado';

  @override
  String get finenessCoarse => 'Grosseiro';

  @override
  String get sourceLabel => 'Original';

  @override
  String get finenessHintFine =>
      'Quase sem perdas — ótimo para arquivar e reeditar.';

  @override
  String get finenessHintBalanced =>
      'Qualidade e tamanho equilibrados — ideal para compartilhar.';

  @override
  String get finenessHintCoarse =>
      'Compressão mais forte — melhor para arquivos muito pequenos.';

  @override
  String get navVideo => 'Vídeo';

  @override
  String get navImage => 'Imagem';

  @override
  String get imageTitle => 'Compressor de imagens';

  @override
  String get inputImage => 'Imagem de entrada';

  @override
  String get pickImage => 'Escolher imagem';

  @override
  String get reselectImage => 'Reselecionar imagem';

  @override
  String get format => 'Formato';

  @override
  String get formatOriginal => 'Original';

  @override
  String get targetSizeKb => 'Tamanho alvo (KB)';

  @override
  String get modeVisualLossless => 'Sem perdas';

  @override
  String get visualLosslessHint =>
      'Sem perda visual — também reduz JPEG, parece idêntico.';

  @override
  String get off => 'desligado';

  @override
  String get actionInfo => 'Informações';

  @override
  String get actionEstimate => 'Estimar';

  @override
  String get actionCompress => 'Comprimir';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String logPickedInput(String path) {
    return 'entrada escolhida: $path';
  }

  @override
  String logOutputDir(String dir) {
    return 'pasta de saída: $dir';
  }

  @override
  String get logPickVideoFirst => 'escolha um vídeo primeiro';

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
    return 'erro de info: $error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return 'estimativa: ~$size MB a $bitrate kbps -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return 'erro de estimativa: $error';
  }

  @override
  String get logPickValidVideoFirst => 'escolha um vídeo válido primeiro';

  @override
  String logStoragePermission(String status) {
    return 'permissão de armazenamento: $status';
  }

  @override
  String get logSkipped => 'ignorado (a compressão não reduziria o tamanho)';

  @override
  String logDone(String size, String saved, String codec) {
    return 'concluído: $size MB (economizou $saved%, $codec)';
  }

  @override
  String logSavedToDownloads(String path) {
    return 'salvo em Downloads: $path';
  }

  @override
  String logOutput(String path) {
    return 'saída: $path';
  }

  @override
  String get logCancelled => 'cancelado';

  @override
  String logError(String error) {
    return 'erro: $error';
  }
}
