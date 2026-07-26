import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_compress/flutter_compress.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/action_bar.dart';
import '../widgets/app_header.dart';
import '../widgets/output_card.dart';
import '../widgets/ui.dart';

/// Image size/quality intent — mutually exclusive. Local to the image page
/// (the video page has its own SizeMode). [visualLossless] is a high-quality
/// lossy preset ("visually lossless") that shrinks JPEGs while looking
/// identical — distinct from the plugin's true `lossless` flag.
enum ImgMode { targetSize, quality, visualLossless }

/// Image-compression screen — parallel to the video page but driven by the
/// separate image API (`compressImage` / `ImageCompressConfig`).
class ImageCompressPage extends StatefulWidget {
  const ImageCompressPage({super.key});

  @override
  State<ImageCompressPage> createState() => _ImageCompressPageState();
}

class _ImageCompressPageState extends State<ImageCompressPage> {
  final _compressor = FlutterCompress.instance;

  String? _inputPath;
  ImageMeta? _info;
  String? _outputDir;

  /// null = keep the source's format (the plugin default).
  ImageFormat? _format;
  ImgMode _mode = ImgMode.targetSize;
  int _targetSizeKB = 200;
  int _quality = 85;

  String _log = '';
  bool _busy = false;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  void _appendLog(String line) => setState(() => _log = '$line\n$_log');

  /// "Visually lossless" high-quality preset — high enough to be visually
  /// indistinguishable, low enough to still shrink typical JPEGs.
  static const _visualLosslessQuality = 90;

  ImageCompressConfig _config() {
    final visual = _mode == ImgMode.visualLossless;
    return ImageCompressConfig(
      format: _format,
      targetSizeKB: _mode == ImgMode.targetSize ? _targetSizeKB : null,
      quality: visual ? _visualLosslessQuality : _quality,
      // Visually lossless keeps the source resolution; other modes cap it.
      maxWidth: visual ? null : 2560,
      maxHeight: visual ? null : 2560,
    );
  }

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final result =
        await FilePicker.pickFiles(type: FileType.image, withData: kIsWeb);
    final path = result?.files.single.xFile.path;
    if (path == null || path.isEmpty) return;
    setState(() {
      _inputPath = path;
      _info = null;
    });
    try {
      final info = await _compressor.getImageInfo(path);
      final srcKB = (info.sizeBytes / 1024).ceil();
      setState(() {
        _info = info;
        if (_targetSizeKB > srcKB) _targetSizeKB = srcKB < 10 ? 10 : srcKB;
      });
    } catch (e) {
      _appendLog(l10n.logInfoError('$e'));
    }
  }

  Future<void> _pickOutputDir() async {
    final l10n = AppLocalizations.of(context);
    final dir = await FilePicker.getDirectoryPath();
    if (dir != null) {
      setState(() => _outputDir = dir);
      _appendLog(l10n.logOutputDir(dir));
    }
  }

  Future<void> _info2() async {
    final l10n = AppLocalizations.of(context);
    final path = _inputPath;
    if (path == null) return _appendLog(l10n.logPickVideoFirst);
    try {
      final i = await _compressor.getImageInfo(path);
      _appendLog('${i.width}x${i.height}, '
          '${(i.sizeBytes / 1024).toStringAsFixed(0)} KB, ${i.format ?? '—'}');
    } catch (e) {
      _appendLog(l10n.logInfoError('$e'));
    }
  }

  Future<void> _compress() async {
    final l10n = AppLocalizations.of(context);
    final path = _inputPath;
    if (path == null || (!kIsWeb && !File(path).existsSync())) {
      return _appendLog(l10n.logPickValidVideoFirst);
    }
    setState(() => _busy = true);
    final routeToDownloads = _isAndroid || _outputDir == null;
    if (routeToDownloads && _isAndroid) {
      await Permission.storage.request();
    }
    try {
      final r = await _compressor.compressImage(
        path,
        _config(),
        outputDirectory: routeToDownloads ? null : _outputDir,
      );
      if (r.skipped) {
        _appendLog(l10n.logSkipped);
        return;
      }
      _appendLog(l10n.logDone(
        (r.compressedSizeBytes / 1024).toStringAsFixed(0),
        r.savedPercent.toStringAsFixed(1),
        '${r.format} ${r.width}x${r.height}',
      ).replaceFirst('MB', 'KB'));
      if (routeToDownloads) {
        final saved = await _compressor.saveToDownloads(
          r.outputPath,
          // Use the format actually written (lossless may fall back to PNG),
          // so the extension — and thus the saved MIME type — is correct.
          fileName: 'compressed_${DateTime.now().millisecondsSinceEpoch}.${_ext(r.format)}',
        );
        _appendLog(l10n.logSavedToDownloads(saved));
      } else {
        _appendLog(l10n.logOutput(r.outputPath));
      }
    } catch (e) {
      _appendLog(l10n.logError('$e'));
    } finally {
      setState(() => _busy = false);
    }
  }

  String _ext(String format) => switch (format) {
        'jpeg' || 'jpg' => 'jpg',
        'png' => 'png',
        'webp' => 'webp',
        'heic' => 'heic',
        _ => format,
      };

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
              AppHeader(title: AppLocalizations.of(context).imageTitle),
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
        const SizedBox(height: 20),
        _actionBar(),
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (_log.isNotEmpty) ...[
          const SizedBox(height: 16),
          LogView(log: _log),
        ],
      ],
    );
  }

  /// Two-column desktop layout: settings on the left, a sticky preview +
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
                    Expanded(child: _preview()),
                    const SizedBox(height: 16),
                    _actionBar(),
                    if (_busy) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
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

  /// The settings controls, shared by both layouts.
  List<Widget> _settings() {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    return [
      _inputCard(l10n, c),
      const SizedBox(height: 14),
      OutputCard(
        isAndroid: _isAndroid,
        outputDir: _outputDir,
        busy: _busy,
        onPick: _pickOutputDir,
      ),
      const SizedBox(height: 22),
      SectionLabel(l10n.format),
      const SizedBox(height: 10),
      _formatPills(),
      const SizedBox(height: 22),
      SectionLabel(l10n.compressionMode),
      const SizedBox(height: 10),
      _modeSelector(l10n),
      const SizedBox(height: 14),
      _control(l10n, c),
    ];
  }

  Widget _actionBar() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: GhostButton(
            icon: Icons.info_outline,
            label: l10n.actionInfo,
            onTap: _busy ? null : _info2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PrimaryButton(
            icon: Icons.bolt,
            label: l10n.actionCompress,
            onTap: _busy ? () {} : _compress,
          ),
        ),
      ],
    );
  }

  /// Desktop sidebar: a large preview of the picked image, or a placeholder.
  Widget _preview() {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    final path = _inputPath;
    if (path == null) {
      return GlassCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, color: c.textMuted, size: 34),
              const SizedBox(height: 12),
              Text(
                l10n.inputImage,
                style: TextStyle(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.pickImage,
                style: TextStyle(color: c.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    final info = _info;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: kIsWeb
                  ? Image.network(path, fit: BoxFit.contain)
                  : Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
          if (info != null) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                LabelChip('${info.width}x${info.height}'),
                LabelChip('${(info.sizeBytes / 1024).toStringAsFixed(0)} KB'),
                if (info.format != null) LabelChip(info.format!.toUpperCase()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _inputCard(AppLocalizations l10n, AppColors c) {
    final info = _info;
    if (_inputPath == null) {
      return GestureDetector(
        onTap: _busy ? null : _pick,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 34),
          child: Column(
            children: [
              Icon(Icons.image_outlined, color: c.accent, size: 34),
              const SizedBox(height: 10),
              Text(l10n.pickImage,
                  style: TextStyle(
                      color: c.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    return GlassCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: kIsWeb
                      ? Image.network(_inputPath!, fit: BoxFit.cover)
                      : Image.file(File(_inputPath!), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.inputImage,
                        style: TextStyle(color: c.textMuted, fontSize: 11)),
                    const SizedBox(height: 3),
                    Text(
                      _inputPath!.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (info != null)
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        LabelChip('${info.width}x${info.height}'),
                        LabelChip('${(info.sizeBytes / 1024).toStringAsFixed(0)} KB'),
                        if (info.format != null)
                          LabelChip(info.format!.toUpperCase()),
                      ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GhostButton(
            icon: Icons.refresh,
            label: l10n.reselectImage,
            onTap: _busy ? null : _pick,
          ),
        ],
      ),
    );
  }

  Widget _formatPills() {
    final l10n = AppLocalizations.of(context);
    // A leading null = "keep source format" (the plugin default).
    final options = <ImageFormat?>[null, ...ImageFormat.values];
    return Row(
      children: [
        for (final f in options) ...[
          Expanded(
            child: Pill(
              label: f?.name ?? l10n.formatOriginal,
              selected: _format == f,
              onTap: _busy ? null : () => setState(() => _format = f),
            ),
          ),
          if (f != options.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _modeSelector(AppLocalizations l10n) {
    Widget toggle(IconData icon, String label, ImgMode mode) => Expanded(
          child: ModeToggle(
            icon: icon,
            label: label,
            selected: _mode == mode,
            onTap: _busy ? null : () => setState(() => _mode = mode),
          ),
        );
    return Row(
      children: [
        toggle(Icons.data_usage, l10n.modeTargetSize, ImgMode.targetSize),
        const SizedBox(width: 10),
        toggle(Icons.star_outline, l10n.modeQuality, ImgMode.quality),
        const SizedBox(width: 10),
        toggle(Icons.diamond_outlined, l10n.modeVisualLossless,
            ImgMode.visualLossless),
      ],
    );
  }

  Widget _control(AppLocalizations l10n, AppColors c) {
    if (_mode == ImgMode.visualLossless) {
      return GlassCard(
        child: Row(
          children: [
            Icon(Icons.diamond_outlined, color: c.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.visualLosslessHint,
                style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ),
      );
    }
    if (_mode == ImgMode.targetSize) {
      final maxKB =
          (_info != null ? (_info!.sizeBytes / 1024).ceil() : 2000).clamp(20, 100000);
      return GlassCard(
        child: Column(
          children: [
            ValueReadout(
                label: l10n.targetSizeKb, value: '$_targetSizeKB', unit: 'KB'),
            Slider(
              value: _targetSizeKB.clamp(10, maxKB).toDouble(),
              min: 10,
              max: maxKB.toDouble(),
              onChanged: (v) => setState(() => _targetSizeKB = v.round()),
            ),
          ],
        ),
      );
    }
    return GlassCard(
      child: Column(
        children: [
          ValueReadout(label: l10n.quality, value: '$_quality', unit: '%'),
          Slider(
            value: _quality.toDouble(),
            min: 1,
            max: 100,
            onChanged: (v) => setState(() => _quality = v.round()),
          ),
        ],
      ),
    );
  }
}
