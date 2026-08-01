import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:fuzzy/fuzzy.dart';
import '../models/tm_parameter.dart';
import '../models/page_layout.dart';
import 'layout_state.dart';
import 'critical_state.dart';

// RE-WRITING TM state file to include Status Monitoring
final tmRegistryProvider = NotifierProvider<TMRegistryNotifier, Map<String, TMParameter>>(() {
  return TMRegistryNotifier();
});

// STATUS MODEL
enum TMConnectionState { disconnected, connected, live }

class SystemStatus {
  final String satellite;
  final bool connected;
  final TMConnectionState state;
  final List<String> ribbon;
  SystemStatus({
    this.satellite = '---',
    this.connected = false,
    this.state = TMConnectionState.disconnected,
    this.ribbon = const [],
  });
}

final systemStatusProvider = NotifierProvider<StatusNotifier, SystemStatus>(() {
  return StatusNotifier();
});

class StatusNotifier extends Notifier<SystemStatus> {
  Timer? _timer;

  @override
  SystemStatus build() {
    _startPolling();
    ref.onDispose(() => _timer?.cancel());
    return SystemStatus();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
       try {
         final String host = Uri.base.host.isEmpty ? "localhost" : Uri.base.host;
         final int port = Uri.base.port == 0 ? 8888 : Uri.base.port;
         
         final response = await http.get(Uri.parse('http://$host:$port/api/status'));
         if (response.statusCode == 200) {
            final data = json.decode(response.body);
            state = SystemStatus(
              satellite: data['satellite'],
              connected: data['connected'],
              state: TMConnectionState.values[data['state'] ?? 0],
              ribbon: List<String>.from(data['ribbon'] ?? []),
            );
         }
       } catch (e) {
         state = SystemStatus(connected: false, state: TMConnectionState.disconnected);
       }
    });
  }
}

class TMRegistryNotifier extends Notifier<Map<String, TMParameter>> {
  WebSocketChannel? _channel;
  List<String> _currentSubscription = [];
  
  // OPTION A: Batching Buffer (List to ensure no samples are lost)
  final List<Map<String, dynamic>> _updateBuffer = [];
  Timer? _batchTimer;

  @override
  Map<String, TMParameter> build() {
    _fetchMnemonics();
    _connectWebSocket();

    // Start the batch flush timer (250ms frame rate)
    _batchTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => _flushUpdates());

    ref.listen(currentPageProvider, (oldPage, newPage) {
      if (newPage != null) _subscribeToPage(newPage);
    });

    ref.listen(systemStatusProvider, (prev, next) {
      if (prev?.ribbon.toString() != next.ribbon.toString()) {
        final page = ref.read(currentPageProvider);
        if (page != null) _subscribeToPage(page);
      }
    });

    ref.listen(criticalParamsProvider, (_, _) {
      final page = ref.read(currentPageProvider);
      if (page != null) _subscribeToPage(page);
    });

    ref.onDispose(() {
      _channel?.sink.close();
      _batchTimer?.cancel();
    });
    return {};
  }

  void _subscribeToPage(PageLayout page) {
    final mnemonics = <String>{};
    for (var col in page.columns) {
      for (var cell in col) {
        if (cell.id.isNotEmpty && cell.content.isNotEmpty && cell.type == CellType.parameter) {
           mnemonics.add(cell.content);
        }
      }
    }
    updateSubscription(mnemonics.toList());
  }

  void updateSubscription(List<String> mnemonics) {
    final ribbon = ref.read(systemStatusProvider).ribbon;
    final criticals = (ref.read(criticalParamsProvider).value ?? []).where((c) => c.isActive).map((c) => c.mnemonic).toList();
    final combined = {...mnemonics, ...ribbon, ...criticals}.toList();
    _currentSubscription = combined;
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({"type": "subscribe", "mnemonics": combined}));
    }
  }

  String get _host {
     // If the browser is at 192.168.1.10:8888, Uri.base.host will be 192.168.1.10
     final String browserHost = Uri.base.host;
     return browserHost.isEmpty ? "localhost" : browserHost;
  }

  int get _port {
     final int browserPort = Uri.base.port;
     return browserPort == 0 ? 8888 : browserPort;
  }

  Future<void> _fetchMnemonics() async {
    try {
      final url = 'http://$_host:$_port/mnemonics';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Map<String, TMParameter> initialMap = {};
        for (var item in data) {
           final p = TMParameter.fromJson(item);
           initialMap[p.mnemonic] = p;
        }
        state = initialMap;
      }
    } catch (_) {}
  }

  void _connectWebSocket() {
    try {
      final wsUrl = 'ws://$_host:$_port/ws';
      debugPrint('Connecting TM WS to: $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      if (_currentSubscription.isNotEmpty) {
        _channel!.sink.add(jsonEncode({"type": "subscribe", "mnemonics": _currentSubscription}));
      } else {
        _triggerInitialSubscription();
      }
      _channel!.stream.listen((message) {
        final raw = message.toString();
        final boundary = RegExp(r'\}\s*\{');
        
        if (raw.contains(boundary)) {
          final parts = raw.split(boundary);
          for (var p in parts) {
            String s = p.trim();
            if (s.isEmpty) continue;
            if (!s.startsWith('{')) s = '{$s';
            if (!s.endsWith('}')) s = '$s}';
            _decodeAndBuffer(s);
          }
        } else {
          _decodeAndBuffer(raw);
        }
      }, 
      onError: (err) {
        debugPrint('TM WS Error: $err');
        Future.delayed(const Duration(seconds: 3), _connectWebSocket);
      },
      onDone: () {
        debugPrint('TM WS Closed');
        Future.delayed(const Duration(seconds: 3), _connectWebSocket);
      });
    } catch (_) {}
  }

  void _decodeAndBuffer(String jsonStr) {
    try {
      final Map<String, dynamic> data = json.decode(jsonStr);
      if (data.containsKey('mnemonic')) {
        _updateBuffer.add(data);
      }
    } catch (_) {}
  }

  void _flushUpdates() {
    if (_updateBuffer.isEmpty) return;
    try {
      final newState = Map<String, TMParameter>.from(state);
      final updates = List<Map<String, dynamic>>.from(_updateBuffer);
      _updateBuffer.clear();

      for (final data in updates) {
        final String mnemonic = data['mnemonic'] ?? '';
        if (mnemonic.isEmpty) continue;

        final existing = newState[mnemonic];
        if (existing != null) {
          final h1 = List<double>.from(existing.tm1History);
          final h2 = List<double>.from(existing.tm2History);
          
          final val1Str = data['tm1_value']?.toString() ?? '';
          final val2Str = data['tm2_value']?.toString() ?? '';
          final count1Str = data['tm1_count']?.toString() ?? '';
          final count2Str = data['tm2_count']?.toString() ?? '';

          double? val1 = double.tryParse(val1Str);
          double? val2 = double.tryParse(val2Str);
          
          // Fallback to plotting the count if the value isn't numeric (e.g. "ON", "OFF", hex strings)
          if (val1 == null && count1Str.isNotEmpty) val1 = double.tryParse(count1Str);
          if (val2 == null && count2Str.isNotEmpty) val2 = double.tryParse(count2Str);
          
          if (val1 != null) {
            h1.add(val1);
            if (h1.length > 100) h1.removeAt(0);
          }
          if (val2 != null) {
            h2.add(val2);
            if (h2.length > 100) h2.removeAt(0);
          }
          
          newState[mnemonic] = existing.copyWith(
            tm1Value: val1Str.isNotEmpty ? val1Str : existing.tm1Value,
            tm2Value: val2Str.isNotEmpty ? val2Str : existing.tm2Value,
            tm1Count: count1Str.isNotEmpty ? count1Str : existing.tm1Count,
            tm2Count: count2Str.isNotEmpty ? count2Str : existing.tm2Count,
            tm1History: h1,
            tm2History: h2,
          );
        } else {
          newState[mnemonic] = TMParameter.fromJson(data);
        }
      }
      
      state = newState;
    } catch (e) {
      debugPrint('Flush Error: $e');
    }
  }

  void _triggerInitialSubscription() {
    Future.delayed(const Duration(milliseconds: 500), () {
        final page = ref.read(currentPageProvider);
        if (page != null) _subscribeToPage(page);
    });
  }
}

// Optimized providers using selective rebuilding
final parameterProvider = Provider.family<TMParameter?, String>((ref, id) {
  // Option B: Only notify listeners if the specific entry for this ID changes
  return ref.watch(tmRegistryProvider.select((map) => map[id]));
});

String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

final filteredParametersProvider = Provider.family<List<TMParameter>, (String query, String subsystem)>((ref, filter) {
  final (query, _) = filter;
  final all = ref.watch(tmRegistryProvider).values.toList();
  if (query.isEmpty) return all;
  final normalizedQuery = _normalize(query);
  final normalizedResults = all.where((p) => _normalize(p.mnemonic).contains(normalizedQuery)).toList();
  if (normalizedResults.isNotEmpty) {
    normalizedResults.sort((a,b) => a.mnemonic.length.compareTo(b.mnemonic.length));
    return normalizedResults;
  }
  final fuse = Fuzzy<TMParameter>(all, options: FuzzyOptions(findAllMatches: true, threshold: 0.3, keys: [
        WeightedKey<TMParameter>(name: 'mnemonic', getter: (p) => p.mnemonic, weight: 1.0),
  ]));
  return fuse.search(query).map((r) => r.item).toList();
});
