// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '동영상 압축';

  @override
  String get language => '언어';

  @override
  String get systemDefault => '시스템 기본값';

  @override
  String get inputVideo => '입력 동영상';

  @override
  String get noFileSelected => '선택된 파일 없음';

  @override
  String get pickVideo => '동영상 선택';

  @override
  String get outputFolder => '출력 폴더 (선택)';

  @override
  String get outputHintAndroid => 'Android: 항상 공용 다운로드에 저장';

  @override
  String get outputHintOther => '앱 문서 / 다운로드';

  @override
  String get pickFolder => '폴더 선택';

  @override
  String get clear => '지우기';

  @override
  String get codec => '코덱';

  @override
  String get quality => '품질';

  @override
  String get targetSizeMb => '목표 크기 (MB)';

  @override
  String get qualityPercent => '품질 %';

  @override
  String get compressionMode => '압축 모드';

  @override
  String get modeTargetSize => '목표 크기';

  @override
  String get modeQuality => '품질';

  @override
  String get qualityMode => '품질 모드';

  @override
  String get modePreset => '프리셋';

  @override
  String get modeCustom => '사용자 지정 %';

  @override
  String get tagline => '로컬 처리 · 업로드 없음 · 워터마크 없음';

  @override
  String get reselectVideo => '동영상 다시 선택';

  @override
  String get estimateTitle => '압축 예상';

  @override
  String get estimateBasedOn => '현재 설정 기준';

  @override
  String get estOutput => '예상 출력';

  @override
  String get estSaved => '절약';

  @override
  String get estFineness => '예상 정밀도';

  @override
  String get finenessFine => '정밀';

  @override
  String get finenessBalanced => '균형';

  @override
  String get finenessCoarse => '거침';

  @override
  String get sourceLabel => '원본';

  @override
  String get finenessHintFine => '거의 무손실 — 보관 및 재편집에 적합.';

  @override
  String get finenessHintBalanced => '품질과 용량 균형 — 공유에 적합.';

  @override
  String get finenessHintCoarse => '강한 압축 — 아주 작은 파일에 적합.';

  @override
  String get navVideo => '동영상';

  @override
  String get navImage => '이미지';

  @override
  String get imageTitle => '이미지 압축';

  @override
  String get inputImage => '입력 이미지';

  @override
  String get pickImage => '이미지 선택';

  @override
  String get reselectImage => '이미지 다시 선택';

  @override
  String get format => '형식';

  @override
  String get targetSizeKb => '목표 크기 (KB)';

  @override
  String get off => '끄기';

  @override
  String get actionInfo => '정보';

  @override
  String get actionEstimate => '추정';

  @override
  String get actionCompress => '압축';

  @override
  String get actionCancel => '취소';

  @override
  String logPickedInput(String path) {
    return '입력 선택됨: $path';
  }

  @override
  String logOutputDir(String dir) {
    return '출력 폴더: $dir';
  }

  @override
  String get logPickVideoFirst => '먼저 동영상을 선택하세요';

  @override
  String logInfo(
    String width,
    String height,
    String size,
    String duration,
    String bitrate,
  ) {
    return '정보: ${width}x$height, $size MB, $duration ms, $bitrate kbps';
  }

  @override
  String logInfoError(String error) {
    return '정보 오류: $error';
  }

  @override
  String logEstimate(String size, String bitrate, String width, String height) {
    return '추정: 약 $size MB, $bitrate kbps -> ${width}x$height';
  }

  @override
  String logEstimateError(String error) {
    return '추정 오류: $error';
  }

  @override
  String get logPickValidVideoFirst => '먼저 유효한 동영상을 선택하세요';

  @override
  String logStoragePermission(String status) {
    return '저장소 권한: $status';
  }

  @override
  String get logSkipped => '건너뜀 (압축해도 크기가 줄지 않음)';

  @override
  String logDone(String size, String saved, String codec) {
    return '완료: $size MB ($saved% 절약, $codec)';
  }

  @override
  String logSavedToDownloads(String path) {
    return '다운로드에 저장됨: $path';
  }

  @override
  String logOutput(String path) {
    return '출력: $path';
  }

  @override
  String get logCancelled => '취소됨';

  @override
  String logError(String error) {
    return '오류: $error';
  }
}
