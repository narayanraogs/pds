import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../models/page_layout.dart';

final editModeProvider = NotifierProvider<EditModeNotifier, bool>(() {
  return EditModeNotifier();
});

// THEME TRACKER
final themeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light; // Default to light

  void toggle() {
    state = (state == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
  }
}

class EditModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  set value(bool val) => state = val;
}

// Switching to AsyncNotifier for real database fetching
final pagesProvider = AsyncNotifierProvider<PagesNotifier, List<PageLayout>>(() {
  return PagesNotifier();
});

class PagesNotifier extends AsyncNotifier<List<PageLayout>> {
  
  String get _baseUrl {
    final String host = Uri.base.host.isEmpty ? "localhost" : Uri.base.host;
    final int port = Uri.base.port == 0 ? 8888 : Uri.base.port;
    final usedPort = kDebugMode ? 8888 : port;
    final usedHost = kDebugMode ? "localhost" : host;
    return 'http://$usedHost:$usedPort/api/pages';
  }

  @override
  FutureOr<List<PageLayout>> build() async {
    return _fetchPages();
  }

  Future<List<PageLayout>> _fetchPages() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          final gridData = json.decode(item['grid_json']) as List<dynamic>;
          return PageLayout(
            id: item['id'],
            name: item['name'],
            grid: gridData.map((row) => (row as List<dynamic>).map((cell) => CellData.fromJson(cell)).toList()).toList(),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[API] Load error: $e');
    }
    
    // Return a default if DB is empty
    return [
      PageLayout(
        id: const Uuid().v4(),
        name: 'Overview Dashboard',
        grid: [[CellData.empty()]],
      )
    ];
  }

  Future<void> addPage(String name) async {
    final newPage = PageLayout(
      id: const Uuid().v4(),
      name: name,
      grid: [[CellData.empty()]],
    );
    
    final previousState = await future;
    state = AsyncValue.data([...previousState, newPage]);
    
    _syncToServer(newPage);
  }

  Future<void> updatePage(PageLayout updatedPage) async {
    final previousState = await future;
    state = AsyncValue.data([
      for (final page in previousState)
        if (page.id == updatedPage.id) updatedPage else page
    ]);
    
    _syncToServer(updatedPage);
  }

  Future<void> deletePage(String id) async {
    final previousState = await future;
    if (previousState.length <= 1) return;

    state = AsyncValue.data(previousState.where((p) => p.id != id).toList());
    
    try {
      await http.delete(Uri.parse('$_baseUrl?id=$id'));
    } catch (e) {
      debugPrint('[API] Delete error: $e');
    }
  }

  Future<void> _syncToServer(PageLayout page) async {
    try {
      // Package the complex grid list as a JSON string for the TEXT column in SQL
      final gridJson = jsonEncode(page.grid.map((row) => row.map((cell) => cell.toJson()).toList()).toList());
      
      await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode({
          'id': page.id,
          'name': page.name,
          'grid_json': gridJson,
        }),
      );
    } catch (e) {
      debugPrint('[API] Sync error: $e');
    }
  }
}

final currentPageIndexProvider = NotifierProvider<CurrentPageIndexNotifier, int>(() {
  return CurrentPageIndexNotifier();
});

class CurrentPageIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  set value(int val) => state = val;
}

final currentPageProvider = Provider<PageLayout?>((ref) {
  final pagesAsync = ref.watch(pagesProvider);
  return pagesAsync.when(
    data: (pages) {
      final index = ref.watch(currentPageIndexProvider);
      if (index >= 0 && index < pages.length) return pages[index];
      return pages.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
