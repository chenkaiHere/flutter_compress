import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_compress/flutter_compress.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/compress_options.dart';
import '../widgets/action_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/codec_selector.dart';
import '../widgets/compression_mode_selector.dart';
import '../widgets/estimate_card.dart';
import '../widgets/input_video_card.dart';
import '../widgets/output_card.dart';
import '../widgets/quality_section.dart';
import '../widgets/target_size_control.dart';
import '../widgets/ui.dart';

/// The single screen: owns compression settings + results and orchestrates the
/// presentational widgets. All rendering lives in `widgets/`.
class CompressPage extends StatefulWidget {
  const CompressPage({super.key});

  @override
  State<CompressPage> createState() => _CompressPageState();
}

class _CompressPageState extends State<CompressPage> {
  final _compressor = FlutterCompress.instance;

  // Inputs.
  String? _inputPath;
  VideoInfo? _videoInfo;
  String? _thumbPath;
  String? _outputDir;

  // Settings.
  VideoCodec _codec = VideoCodec.h265;
  SizeMode _sizeMode = SizeMode.targetSize;
  QualityMode _qualityMode = QualityMode.preset;
  int _targetSizeMB = 60;
  CompressQuality _quality = CompressQuality.medium;
  int _qualityPercent = 50;

  // Results / status.
  CompressionEstimate? _est;
  double _progress = 0;
  String _log = '';
  bool _busy = false;
  CancellationToken? _token;

  // dart:io Platform throws on web (which this plugin doesn't target); guard it.
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  void _appendLog(String line) => setState(() => _log = '$line\n$_log');

  VideoCompressConfig _buildConfig() {
    // Target-size mode keeps the source resolution so the bitrate budget alone
    // decides the size (otherwise a forced downscale makes the output land well
    // under the target). Quality mode caps resolution to help shrink the file.
    const qualityCap = (w: 1280, h: 1280);
    if (_sizeMode == SizeMode.targetSize) {
      return VideoCompressConfig(codec: _codec, targetSizeMB: _targetSizeMB);
    }
    if (_qualityMode == QualityMode.percent) {
      return VideoCompressConfig(
        codec: _codec,
        qualityPercent: _qualityPercent,
        maxWidth: qualityCap.w,
        maxHeight: qualityCap.h,
      );
    }
    return VideoCompressConfig(
      codec: _codec,
      quality: _quality,
      maxWidth: qualityCap.w,
      maxHeight: qualityCap.h,
    );
  }

  // ---- data --------------------------------------------------------------

  Future<void> _pickVideo() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );
    // xFile.path is the real path on native and a blob: URL on web.
    final path = result?.files.single.xFile.path;
    if (path == null || path.isEmpty) return;
    setState(() {
      _inputPath = path;
      _videoInfo = null;
      _thumbPath = null;
      _est = null;
    });
    _appendLog(l10n.logPickedInput(path));
    try {
      final info = await _compressor.getVideoInfo(path);
      String? thumb;
      try {
        thumb = await _compressor.getThumbnail(
          path,
          positionMs: 0,
          maxWidth: 320,
        );
      } catch (_) {}
      final srcMB = (info.sizeBytes / 1024 / 1024).ceil();
      setState(() {
        _videoInfo = info;
        _thumbPath = thumb;
        if (_targetSizeMB > srcMB) _targetSizeMB = srcMB < 1 ? 1 : srcMB;
      });
    } catch (e) {
      _appendLog(l10n.logInfoError('$e'));
    }
    _refreshEstimate();
  }

  Future<void> _pickOutputDir() async {
    final l10n = AppLocalizations.of(context);
    final dir = await FilePicker.getDirectoryPath();
    if (dir != null) {
      setState(() => _outputDir = dir);
      _appendLog(l10n.logOutputDir(dir));
    }
  }

  Future<void> _refreshEstimate() async {
    final path = _inputPath;
    if (path == null) return;
    try {
      final est = await _compressor.estimate(path, _buildConfig());
      if (mounted) setState(() => _est = est);
    } catch (_) {
      // silent — the estimate card just won't update
    }
  }

  Future<void> _ensureStoragePermission(AppLocalizations l10n) async {
    if (!_isAndroid) return;
    final status = await Permission.storage.request();
    _appendLog(l10n.logStoragePermission(status.name));
  }

  // ---- actions -----------------------------------------------------------

  Future<void> _info() async {
    final l10n = AppLocalizations.of(context);
    final path = _inputPath;
    if (path == null) return _appendLog(l10n.logPickVideoFirst);
    try {
      final info = await _compressor.getVideoInfo(path);
      _appendLog(
        l10n.logInfo(
          '${info.width}',
          '${info.height}',
          (info.sizeBytes / 1024 / 1024).toStringAsFixed(1),
          '${info.durationMs}',
          '${info.bitrateKbps}',
        ),
      );
    } catch (e) {
      _appendLog(l10n.logInfoError('$e'));
    }
  }

  Future<void> _estimateAction() async {
    final l10n = AppLocalizations.of(context);
    final path = _inputPath;
    if (path == null) return _appendLog(l10n.logPickVideoFirst);
    await _refreshEstimate();
    final est = _est;
    if (est != null) {
      _appendLog(
        l10n.logEstimate(
          (est.estimatedSizeBytes / 1024 / 1024).toStringAsFixed(1),
          '${est.estimatedBitrateKbps}',
          '${est.targetWidth}',
          '${est.targetHeight}',
        ),
      );
    }
  }

  Future<void> _compress() async {
    final l10n = AppLocalizations.of(context);
    final path = _inputPath;
    // On web the "path" is a blob: URL, not a filesystem file.
    if (path == null || (!kIsWeb && !File(path).existsSync())) {
      return _appendLog(l10n.logPickValidVideoFirst);
    }
    setState(() {
      _busy = true;
      _progress = 0;
    });
    _token = CancellationToken();
    final routeToDownloads = _isAndroid || _outputDir == null;
    if (routeToDownloads) await _ensureStoragePermission(l10n);
    try {
      final result = await _compressor.compress(
        path,
        _buildConfig(),
        outputDirectory: routeToDownloads ? null : _outputDir,
        onProgress: (p) => setState(() => _progress = p.progress),
        cancellationToken: _token,
      );
      if (result.skipped) {
        _appendLog(l10n.logSkipped);
      } else {
        _appendLog(
          l10n.logDone(
            (result.compressedSizeBytes / 1024 / 1024).toStringAsFixed(1),
            result.savedPercent.toStringAsFixed(1),
            result.codec,
          ),
        );
        if (routeToDownloads) {
          final saved = await _compressor.saveToDownloads(
            result.outputPath,
            fileName: 'compressed_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );
          _appendLog(l10n.logSavedToDownloads(saved));
        } else {
          _appendLog(l10n.logOutput(result.outputPath));
        }
      }
    } on VideoCompressCancelledException {
      _appendLog(l10n.logCancelled);
    } catch (e) {
      _appendLog(l10n.logError('$e'));
    } finally {
      setState(() => _busy = false);
    }
  }

  // ---- build -------------------------------------------------------------

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppHeader(),
              Expanded(child: isWide ? _wideBody() : _narrowBody()),
            ],
          ),
        ),
      ),
    );
  }

  /// Single-column phone layout.
  Widget _narrowBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        ..._settings(),
        if (_hasEstimate) ...[
          const SizedBox(height: 16),
          EstimateCard(estimate: _est!, info: _videoInfo),
        ],
        const SizedBox(height: 20),
        _actionBar(),
        if (_busy) ...[
          const SizedBox(height: 16),
          ProgressView(progress: _progress),
        ],
        if (_log.isNotEmpty) ...[
          const SizedBox(height: 16),
          LogView(log: _log),
        ],
      ],
    );
  }

  /// Two-column desktop layout: settings on the left, a sticky estimate +
  /// actions sidebar on the right.
  Widget _wideBody() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    ..._settings(),
                    if (_log.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      LogView(log: _log),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 360,
                child: Column(
                  children: [
                    Expanded(
                      child: _hasEstimate
                          ? EstimateCard(
                              estimate: _est!,
                              info: _videoInfo,
                              expanded: true,
                            )
                          : _sidebarPlaceholder(),
                    ),
                    const SizedBox(height: 16),
                    _actionBar(),
                    if (_busy) ...[
                      const SizedBox(height: 12),
                      ProgressView(progress: _progress),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasEstimate => _est != null && _inputPath != null;

  /// The settings controls, shared by both layouts.
  List<Widget> _settings() {
    final l10n = AppLocalizations.of(context);
    return [
      InputVideoCard(
        inputPath: _inputPath,
        info: _videoInfo,
        thumbPath: _thumbPath,
        busy: _busy,
        onPick: _pickVideo,
      ),
      const SizedBox(height: 14),
      OutputCard(
        isAndroid: _isAndroid,
        outputDir: _outputDir,
        busy: _busy,
        onPick: _pickOutputDir,
      ),
      const SizedBox(height: 22),
      SectionLabel(l10n.codec),
      const SizedBox(height: 10),
      CodecSelector(
        codec: _codec,
        busy: _busy,
        onChanged: (v) => setState(() => _codec = v),
      ),
      const SizedBox(height: 22),
      SectionLabel(l10n.compressionMode),
      const SizedBox(height: 10),
      CompressionModeSelector(
        mode: _sizeMode,
        busy: _busy,
        onChanged: (m) {
          setState(() => _sizeMode = m);
          _refreshEstimate();
        },
      ),
      const SizedBox(height: 14),
      if (_sizeMode == SizeMode.targetSize)
        TargetSizeControl(
          targetSizeMB: _targetSizeMB,
          info: _videoInfo,
          onChanged: (v) => setState(() => _targetSizeMB = v),
          onChangeEnd: _refreshEstimate,
        )
      else
        QualitySection(
          qualityMode: _qualityMode,
          quality: _quality,
          qualityPercent: _qualityPercent,
          busy: _busy,
          onQualityModeChanged: (m) {
            setState(() => _qualityMode = m);
            _refreshEstimate();
          },
          onQualityChanged: (q) {
            setState(() => _quality = q);
            _refreshEstimate();
          },
          onPercentChanged: (v) => setState(() => _qualityPercent = v),
          onChangeEnd: _refreshEstimate,
        ),
    ];
  }

  Widget _actionBar() {
    return ActionBar(
      busy: _busy,
      onInfo: _info,
      onEstimate: _estimateAction,
      onCompress: _compress,
      onCancel: () => _token?.cancel(),
    );
  }

  /// Shown in the desktop sidebar before a video is selected.
  Widget _sidebarPlaceholder() {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    return GlassCard(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined, color: c.textMuted, size: 34),
            const SizedBox(height: 12),
            Text(
              l10n.estimateTitle,
              style: TextStyle(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.pickVideo,
              style: TextStyle(color: c.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
