import 'package:flutter/material.dart';
import 'package:flutter_compress/flutter_compress.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';

/// Live compression estimate. [expanded] renders the taller desktop-sidebar
/// layout (big output number, savings badge, output-vs-source bar, hint);
/// otherwise the compact mobile card.
class EstimateCard extends StatelessWidget {
  const EstimateCard({
    super.key,
    required this.estimate,
    required this.info,
    this.expanded = false,
  });

  final CompressionEstimate estimate;
  final VideoInfo? info;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return expanded ? _buildExpanded(context) : _buildCompact(context);
  }

  // ---- compact (mobile) --------------------------------------------------

  Widget _buildCompact(BuildContext context) {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    final f = _fineness(l10n, c);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: l10n.estOutput,
                  value: _outMB.toStringAsFixed(0),
                  unit: 'MB',
                  color: c.textPrimary,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: l10n.estSaved,
                  value: _saved.toStringAsFixed(0),
                  unit: '%',
                  color: c.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _finenessRow(context, f),
          const SizedBox(height: 8),
          _meter(context, f),
        ],
      ),
    );
  }

  // ---- expanded (desktop sidebar) ----------------------------------------

  Widget _buildExpanded(BuildContext context) {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    final f = _fineness(l10n, c);
    final srcMB = (info?.sizeBytes ?? 0) / 1024 / 1024;
    final ratio = srcMB > 0 ? (_outMB / srcMB).clamp(0.0, 1.0) : 0.0;
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const SizedBox(height: 22),
          Text(
            l10n.estOutput,
            style: TextStyle(color: c.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _outMB.toStringAsFixed(0),
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  height: 0.95,
                  fontFamilyFallback: kMonoFallback,
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'MB',
                  style: TextStyle(color: c.textMuted, fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '↓ ${_saved.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: c.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamilyFallback: kMonoFallback,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.sourceLabel} ${srcMB.toStringAsFixed(0)} MB',
                  style: TextStyle(color: c.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // output-vs-source bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              color: c.pill,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio == 0 ? 0.02 : ratio,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: c.accentGradient),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.estOutput,
                style: TextStyle(color: c.textMuted, fontSize: 10),
              ),
              Text(
                l10n.sourceLabel,
                style: TextStyle(color: c.textMuted, fontSize: 10),
              ),
            ],
          ),
          const Spacer(),
          _finenessRow(context, f),
          const SizedBox(height: 8),
          _meter(context, f),
          const SizedBox(height: 12),
          Text(
            f.hint,
            style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ---- shared bits -------------------------------------------------------

  Widget _header(BuildContext context) {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.estimateTitle,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          l10n.estimateBasedOn,
          style: TextStyle(color: c.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _finenessRow(BuildContext context, _Fineness f) {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.estFineness,
          style: TextStyle(color: c.textSecondary, fontSize: 12),
        ),
        Text(
          f.label,
          style: TextStyle(
            color: f.color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _meter(BuildContext context, _Fineness f) {
    final c = context.c;
    return Row(
      children: [
        for (int i = 0; i < 10; i++) ...[
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i < f.level ? f.color : c.pill,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (i < 9) const SizedBox(width: 4),
        ],
      ],
    );
  }

  double get _outMB => estimate.estimatedSizeBytes / 1024 / 1024;

  double get _saved {
    final srcBytes = info?.sizeBytes ?? 0;
    if (srcBytes <= 0) return 0;
    return ((1 - estimate.estimatedSizeBytes / srcBytes) * 100).clamp(0, 100);
  }

  _Fineness _fineness(AppLocalizations l10n, AppColors c) {
    final src = info?.bitrateKbps ?? 0;
    final est = estimate.estimatedBitrateKbps;
    if (src <= 0 || est <= 0) {
      return _Fineness(0, '—', c.textMuted, '');
    }
    final ratio = (est / src).clamp(0.0, 1.0);
    final level = (ratio * 10).round();
    if (ratio >= 0.66) {
      return _Fineness(
        level,
        l10n.finenessFine,
        c.success,
        l10n.finenessHintFine,
      );
    }
    if (ratio >= 0.33) {
      return _Fineness(
        level,
        l10n.finenessBalanced,
        c.warn,
        l10n.finenessHintBalanced,
      );
    }
    return _Fineness(
      level,
      l10n.finenessCoarse,
      c.danger,
      l10n.finenessHintCoarse,
    );
  }
}

class _Fineness {
  const _Fineness(this.level, this.label, this.color, this.hint);
  final int level;
  final String label;
  final Color color;
  final String hint;
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                fontFamilyFallback: kMonoFallback,
                height: 1,
              ),
            ),
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                unit,
                style: TextStyle(color: c.textMuted, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
