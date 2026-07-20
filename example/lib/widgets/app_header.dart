import 'package:flutter/material.dart';

import '../app.dart';
import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import 'ui.dart';

/// Native (self-referential) display name for each supported language.
const Map<String, String> kLanguageNames = {
  'en': 'English',
  'zh': '中文',
  'ar': 'العربية',
  'bn': 'বাংলা',
  'es': 'Español',
  'fr': 'Français',
  'hi': 'हिन्दी',
  'ja': '日本語',
  'ko': '한국어',
  'pt': 'Português',
  'ru': 'Русский',
  'ur': 'اردو',
};

/// Brand + title + tagline on the left; theme toggle + language menu on right.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMPRESSOR',
                  style: TextStyle(
                    color: c.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.appTitle,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.tagline,
                  style: TextStyle(color: c.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            onTap: () => DemoApp.toggleTheme(context),
          ),
          const SizedBox(width: 10),
          const _LanguageMenu(),
        ],
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n.language,
      color: c.cardTop,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) =>
          DemoApp.setLocale(context, v.isEmpty ? null : Locale(v)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: '',
          child: Text(
            l10n.systemDefault,
            style: TextStyle(color: c.textPrimary),
          ),
        ),
        const PopupMenuDivider(),
        for (final e in kLanguageNames.entries)
          PopupMenuItem(
            value: e.key,
            child: Text(e.value, style: TextStyle(color: c.textPrimary)),
          ),
      ],
      child: const CircleIconButton(icon: Icons.language),
    );
  }
}
