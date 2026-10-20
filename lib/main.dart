import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'menu/menu_page.dart';
import 'settings/secure_window_channel.dart';
import 'settings/settings_providers.dart';
import 'settings/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Re-apply the persisted Secure Window flag; FLAG_SECURE does not survive
  // an activity restart on its own.
  await SecureWindowChannel.apply(SettingsRepository(prefs).secureWindow);
  // targetSdk is 36, so Android 15+ forces edge-to-edge and ignores
  // statusBarColor. Ask for it explicitly so pre-15 devices match, then let
  // SafeArea in each screen keep content clear of the system bars.
  // System bar icon colors follow the app theme via AnnotatedRegion below.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const NhReaderApp(),
    ),
  );
}

/// Builds the app theme for [brightness]. Dark uses the app's hand-picked
/// surface colors; light derives a matching palette from the same seed.
ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final surface = isDark ? const Color(0xFF_0F0F14) : Colors.white;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF_E51160),
      brightness: brightness,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: isDark ? const Color(0xFF_2A1520) : const Color(0xFFFCE4EC),
      height: 60,
    ),
  );
}

/// Keeps status/navigation bar icon colors in sync with the current
/// brightness, so switching theme recolors the system bars live too.
SystemUiOverlayStyle _overlayStyleFor(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
  );
}

class NhReaderApp extends ConsumerWidget {
  const NhReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final brightness = switch (themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      // "system" follows the device setting.
      _ => MediaQuery.platformBrightnessOf(context),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayStyleFor(brightness),
      child: MaterialApp(
        title: 'Nh Reader',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: themeMode,
        home: const HomeShell(),
      ),
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
