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

// RE-WRITING TM state file to include Status Monitoring
final tmRegistryProvider = NotifierProvider<TMRegistryNotifier, Map<String, TMParameter>>(() {
  return TMRegistryNotifier();
});

// STATUS MODEL
class SystemStatus {
  final String satellite;
  final bool connected;
  SystemStatus({this.satellite = '---', this.connected = false});
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
         final usedPort = kDebugMode ? 8888 : port;
         final usedHost = kDebugMode ? "localhost" : host;
         
         final response = await http.get(Uri.parse('http://$usedHost:$usedPort/api/status'));
         if (response.statusCode == 200) {
            final data = json.decode(response.body);
            state = SystemStatus(
              satellite: data['satellite'],
              connected: data['connected'],
            );
         }
       } catch (e) {
         state = SystemStatus(connected: false);
       }
    });
  }
}

class TMRegistryNotifier extends Notifier<Map<String, TMParameter>> {
  WebSocketChannel? _channel;
  List<String> _currentSubscription = [];

  @override
  Map<String, TMParameter> build() {
    final Map<String, TMParameter> initial = {};
    _fetchMnemonics();
    _connectWebSocket();

    ref.listen(currentPageProvider, (oldPage, newPage) {
      if (newPage != null) _subscribeToPage(newPage);
    });

    ref.onDispose(() => _channel?.sink.close());
    return initial;
  }

  void _subscribeToPage(PageLayout page) {
    final mnemonics = <String>{};
    for (var row in page.grid) {
      for (var cell in row) {
        if (cell.id.isNotEmpty && cell.content.isNotEmpty && cell.type == CellType.parameter) {
           mnemonics.add(cell.content);
        }
      }
    }
    updateSubscription(mnemonics.toList());
  }

  void updateSubscription(List<String> mnemonics) {
    _currentSubscription = mnemonics;
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({"type": "subscribe", "mnemonics": mnemonics}));
    }
  }

  Future<void> _fetchMnemonics() async {
    try {
      final host = kDebugMode ? 'localhost' : Uri.base.host;
      final port = kDebugMode ? 8888 : Uri.base.port;
      final url = 'http://${host.isEmpty ? "localhost" : host}:$port/mnemonics';
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
      final host = kDebugMode ? 'localhost' : Uri.base.host;
      final port = kDebugMode ? 8888 : Uri.base.port;
      final wsUrl = 'ws://${host.isEmpty ? "localhost" : host}:$port/ws';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _triggerInitialSubscription();
      _channel!.stream.listen((message) {
        final updatedParam = TMParameter.fromJson(json.decode(message));
        final newState = Map<String, TMParameter>.from(state);
        newState[updatedParam.mnemonic] = updatedParam;
        state = newState;
      }, onError: (err) => Future.delayed(const Duration(seconds: 3), _connectWebSocket));
    } catch (_) {}
  }

  void _triggerInitialSubscription() {
    Future.delayed(const Duration(milliseconds: 500), () {
        final page = ref.read(currentPageProvider);
        if (page != null) _subscribeToPage(page);
    });
  }
}

// Optimized providers
final parameterProvider = Provider.family<TMParameter?, String>((ref, id) {
  return ref.watch(tmRegistryProvider)[id];
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
