import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'menu/menu_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // targetSdk is 36, so Android 15+ forces edge-to-edge and ignores
  // statusBarColor. Ask for it explicitly so pre-15 devices match, then let
  // SafeArea in each screen keep content clear of the system bars.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: NhReaderApp()));
}

class NhReaderApp extends StatelessWidget {
  const NhReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nh Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF_0F0F14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF_E51160),
          brightness: Brightness.dark,
        ),

        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF_0F0F14),
          indicatorColor: Color(0xFF_2A1520),
          height: 60,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Home is the landing tab.
  int _index = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _PlaceholderPage(key: ValueKey('bookmarks-page'), label: 'Bookmarks'),
          _PlaceholderPage(key: ValueKey('home-page'), label: 'Home'),
          MenuPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Bookmarks',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Menu',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      // shortcut: no data source yet, swap for the real refresh once the API layer lands.
      onRefresh: () async {},
      child: CustomScrollView(
        // Always draggable so pull-to-refresh works on an empty screen.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(child: Center(child: Text(label))),
          ),
        ],
      ),
    );
  }
}
