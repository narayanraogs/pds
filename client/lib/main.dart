import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/layout_state.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SatelliteTMApp(),
    ),
  );
}

class SatelliteTMApp extends ConsumerWidget {
  const SatelliteTMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'PDS Pro — Ground Station Control',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,

      // ── LIGHT THEME ──────────────────────────────────────────────────────────
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Roboto',
        primaryColor: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardColor: Colors.white,
        dividerColor: const Color(0xFFE2E8F0),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(letterSpacing: -0.2, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(letterSpacing: -0.2, color: Color(0xFF334155)),
          titleLarge: TextStyle(letterSpacing: -0.6, color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          surfaceTintColor: Colors.transparent,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF06B6D4),
          surface: Colors.white,
        ),
        useMaterial3: true,
      ),

      // ── DARK THEME ───────────────────────────────────────────────────────────
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Inter',
        primaryColor: const Color(0xFF38BDF8),      // Sky-400
        scaffoldBackgroundColor: const Color(0xFF060A12),  // Near-black space
        cardColor: const Color(0xFF0D1321),
        dividerColor: const Color(0xFF1E293B),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(letterSpacing: -0.2, color: Color(0xFFE2E8F0)),
          bodyMedium: TextStyle(letterSpacing: -0.2, color: Color(0xFF94A3B8)),
          titleLarge: TextStyle(letterSpacing: -0.6, color: Color(0xFFF8FAFC), fontWeight: FontWeight.w800),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFF0D1321),
          foregroundColor: Color(0xFFF8FAFC),
          surfaceTintColor: Colors.transparent,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
          primary: const Color(0xFF38BDF8),
          secondary: const Color(0xFF22D3EE),
          surface: const Color(0xFF0D1321),
        ),
        useMaterial3: true,
      ),

      home: const MainScreen(),
    );
  }
}
