import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'l10n/app_localizations.dart';
import 'pages/home_page.dart';

/// Root widget: owns the app-wide locale and theme mode (both persisted), and
/// exposes static helpers so any descendant can change them.
class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  static void setLocale(BuildContext context, Locale? locale) =>
      context.findAncestorStateOfType<_DemoAppState>()?.setLocale(locale);

  static void toggleTheme(BuildContext context) =>
      context.findAncestorStateOfType<_DemoAppState>()?.toggleTheme();

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  static const _localeKey = 'app_locale';
  static const _themeKey = 'app_theme_mode';

  Locale? _locale; // null => follow the system locale
  ThemeMode _themeMode = ThemeMode.dark; // design is dark-first

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    final theme = prefs.getString(_themeKey);
    setState(() {
      if (code != null && code.isNotEmpty) _locale = Locale(code);
      if (theme == 'light') _themeMode = ThemeMode.light;
      if (theme == 'dark') _themeMode = ThemeMode.dark;
    });
  }

  Future<void> setLocale(Locale? locale) async {
    setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, locale.languageCode);
    }
  }

  Future<void> toggleTheme() async {
    setState(
      () => _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      themeMode: _themeMode,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // First launch (no saved choice): match the system language, else English.
      localeResolutionCallback: (device, supported) {
        if (device != null) {
          for (final l in supported) {
            if (l.languageCode == device.languageCode) return l;
          }
        }
        return const Locale('en');
      },
      home: const HomePage(),
    );
  }
}
