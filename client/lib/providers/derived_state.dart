import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/derived_parameter.dart';

final derivedParamProvider = AsyncNotifierProvider<DerivedParamNotifier, List<DerivedParameter>>(() {
  return DerivedParamNotifier();
});

class DerivedParamNotifier extends AsyncNotifier<List<DerivedParameter>> {
  String get _baseUrl {
    final String host = Uri.base.host.isEmpty ? "localhost" : Uri.base.host;
    final int port = Uri.base.port == 0 ? 8888 : Uri.base.port;
    return 'http://$host:$port/api/derived';
  }

  @override
  FutureOr<List<DerivedParameter>> build() async {
    return _fetch();
  }

  Future<List<DerivedParameter>> _fetch() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => DerivedParameter.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('[API] Load derived params error: $e');
    }
    return [];
  }

  Future<void> save(DerivedParameter dp) async {
    final previousState = state.value ?? [];
    final exists = previousState.any((p) => p.id == dp.id);
    
    state = AsyncValue.data([
      for (final p in previousState)
        if (p.id == dp.id) dp else p,
      if (!exists) dp
    ]);

    try {
      await http.post(
        Uri.parse(_baseUrl),
        body: jsonEncode(dp.toJson()),
      );
    } catch (e) {
      debugPrint('[API] Sync derived params error: $e');
    }
  }

  Future<void> deleteParam(String id) async {
    final previousState = state.value ?? [];
    state = AsyncValue.data(previousState.where((p) => p.id != id).toList());

    try {
      await http.delete(Uri.parse('$_baseUrl?id=$id'));
    } catch (e) {
      debugPrint('[API] Delete derived params error: $e');
    }
  }
}
