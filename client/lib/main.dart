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
      title: 'Satellite TM Page system',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      
      // LIGHT THEME (PREMIUM GS DESIGN)
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Roboto',
        primaryColor: const Color(0xFF2E66E7), // Modern Electric Blue
        scaffoldBackgroundColor: const Color(0xFFF9FAFB), // Clean neutral
        cardColor: Colors.white,
        dividerColor: const Color(0xFFE5E7EB),
        textTheme: const TextTheme(
           bodyLarge: TextStyle(letterSpacing: -0.2, color: Color(0xFF111827), fontWeight: FontWeight.w500),
           bodyMedium: TextStyle(letterSpacing: -0.2, color: Color(0xFF374151)),
           titleLarge: TextStyle(letterSpacing: -0.5, color: Color(0xFF111827), fontWeight: FontWeight.w900),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF111827),
          surfaceTintColor: Colors.transparent,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E66E7),
          brightness: Brightness.light,
          primary: const Color(0xFF2E66E7),
          secondary: const Color(0xFF10B981), // Success EMERALD
          surface: Colors.white,
        ),
        useMaterial3: true,
      ),

      // DARK THEME (HIGH-END DARK GS DESIGN)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        primaryColor: const Color(0xFF3B82F6),
        scaffoldBackgroundColor: const Color(0xFF0F1115), // Deep Charcoal/Navy
        cardColor: const Color(0xFF1E2128),
        dividerColor: const Color(0xFF2D333B),
        textTheme: const TextTheme(
           bodyLarge: TextStyle(letterSpacing: -0.2, color: Color(0xFFF3F4F6)),
           bodyMedium: TextStyle(letterSpacing: -0.2, color: Color(0xFFD1D5DB)),
           titleLarge: TextStyle(letterSpacing: -0.5, color: Color(0xFFF9FAFB), fontWeight: FontWeight.w900),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFF1E2128),
          foregroundColor: Color(0xFFF9FAFB),
          surfaceTintColor: Colors.transparent,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
          primary: const Color(0xFF3B82F6),
          secondary: const Color(0xFF10B981),
          surface: const Color(0xFF1E2128),
        ),
        useMaterial3: true,
      ),
      
      home: const MainScreen(),
    );
  }
}
