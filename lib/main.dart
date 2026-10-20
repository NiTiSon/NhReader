import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      home: const Scaffold(),
    );
  }
}
