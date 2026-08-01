import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/critical_parameter.dart';

final criticalParamsProvider = AsyncNotifierProvider<CriticalParamsNotifier, List<CriticalParameter>>(() {
  return CriticalParamsNotifier();
});

class CriticalParamsNotifier extends AsyncNotifier<List<CriticalParameter>> {
  String get _host {
    final String browserHost = Uri.base.host;
    return browserHost.isEmpty ? "localhost" : browserHost;
  }

  int get _port {
    final int browserPort = Uri.base.port;
    return browserPort == 0 ? 8888 : browserPort;
  }

  @override
  Future<List<CriticalParameter>> build() async {
    return _fetchCriticalParams();
  }

  Future<List<CriticalParameter>> _fetchCriticalParams() async {
    try {
      final response = await http.get(Uri.parse('http://$_host:$_port/api/critical'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => CriticalParameter.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching critical parameters: $e');
    }
    return [];
  }

  Future<void> saveCriticalParam(CriticalParameter cp) async {
    try {
      final response = await http.post(
        Uri.parse('http://$_host:$_port/api/critical'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(cp.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        state = AsyncData(await _fetchCriticalParams());
      }
    } catch (e) {
      debugPrint('Error saving critical parameter: $e');
    }
  }

  Future<void> deleteCriticalParam(String id) async {
    try {
      final response = await http.delete(Uri.parse('http://$_host:$_port/api/critical?id=$id'));
      if (response.statusCode == 200 || response.statusCode == 204) {
        state = AsyncData(await _fetchCriticalParams());
      }
    } catch (e) {
      debugPrint('Error deleting critical parameter: $e');
    }
  }
}
