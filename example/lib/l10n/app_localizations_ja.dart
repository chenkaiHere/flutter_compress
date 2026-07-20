// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '動画圧縮';

  @override
  String get language => '言語';

  @override
  String get systemDefault => 'システムの既定';

  @override
  String get inputVideo => '入力動画';

  @override
  String get noFileSelected => 'ファイルが選択されていません';

  @override
  String get pickVideo => '動画を選択';

  @override
  String get outputFolder => '出力フォルダ（任意）';

  @override
  String get outputHintAndroid => 'Android: 常に公開の「ダウンロード」に保存';

  @override
  String get outputHintOther => 'アプリのドキュメント / ダウンロード';

  @override
  String get pickFolder => 'フォルダを選択';

  @override
  String get clear => 'クリア';

  @override
  String get codec => 'コーデック';

  @override
  String get quality => '画質';

  @override
  String get targetSizeMb => '目標サイズ (MB)';

  @override
  String get qualityPercent => '画質 %';

  @override
  String get compressionMode => '圧縮モード';

  @override
  String get modeTargetSize => '目標サイズ';

  @override
  String get modeQuality => '画質';

  @override
  String get qualityMode => '画質モード';

  @override
  String get modePreset => 'プリセット';

  @override
  String get modeCustom => 'カスタム %';

  @override
  String get tagline => 'ローカル処理 · アップロードなし · 透かしなし';

  @override
  String get reselectVideo => '動画を選び直す';

  @override
  String get estimateTitle => '圧縮見積り';

  @override
  String get estimateBasedOn => '現在の設定に基づく';

  @override
  String get estOutput => '予想出力';

  @override
  String get estSaved => '削減';

  @override
  String get estFineness => '予想の精細さ';

  @override
  String get finenessFine => '精細';

  @override
  String get finenessBalanced => 'バランス';

  @override
  String get finenessCoarse => '粗い';

  @override
  String get sourceLabel => '元';

  @override
  String get finenessHintFine => 'ほぼ無損失 — 保存や再編集に最適。';

  @override
  String get finenessHintBalanced => '画質と容量のバランス — 共有に最適。';

  @override
  String get finenessHintCoarse => '高圧縮 — 極小サイズ向け。';

  @override
  String get off => 'オフ';

  @override
  String get actionInfo => '情報';

  @override
  String get actionEstimate => '見積り';

  @override
  String get actionCompress => '圧縮';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String logPickedInput(String path) {
    return '入力を選択: $path';
  }

  @override
  String logOutputDir(String dir) {
    return '出力フォルダ: $dir';
  }

  @override
  String get logPickVideoFirst => '先に動画を選択してください';

  @override
  String logInfo(
    String width,
    String height,
    String size,
    String duration,
    String bitrate,
  ) {
    return '情報: ${width}x$height, $size MB, $duration ms, $bitrate kbps';
  }

  @override
  String logInfoError(String error) {
    return '情報エラー: $error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return '見積り: 約 $size MB / $bitrate kbps -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return '見積りエラー: $error';
  }

  @override
  String get logPickValidVideoFirst => '先に有効な動画を選択してください';

  @override
  String logStoragePermission(String status) {
    return 'ストレージ権限: $status';
  }

  @override
  String get logSkipped => 'スキップ（圧縮してもサイズは減りません）';

  @override
  String logDone(String size, String saved, String codec) {
    return '完了: $size MB（$saved% 削減, $codec）';
  }

  @override
  String logSavedToDownloads(String path) {
    return 'ダウンロードに保存: $path';
  }

  @override
  String logOutput(String path) {
    return '出力: $path';
  }

  @override
  String get logCancelled => 'キャンセルしました';

  @override
  String logError(String error) {
    return 'エラー: $error';
  }
}
