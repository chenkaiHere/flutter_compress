import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import 'compress_page.dart';
import 'image_compress_page.dart';

/// Hosts the two compression demos (video / image) behind a bottom nav.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [CompressPage(), ImageCompressPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: c.cardBottom,
        indicatorColor: c.accent.withValues(alpha: 0.25),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.movie_outlined),
            selectedIcon: const Icon(Icons.movie),
            label: l10n.navVideo,
          ),
          NavigationDestination(
            icon: const Icon(Icons.image_outlined),
            selectedIcon: const Icon(Icons.image),
            label: l10n.navImage,
          ),
        ],
      ),
    );
  }
}
