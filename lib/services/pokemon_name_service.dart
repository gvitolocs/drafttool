import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class PokemonNameService {
  PokemonNameService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<String>> loadLocalNames() async {
    final raw = await rootBundle.loadString('assets/data/pokemon_names.txt');
    return raw
        .split('\n')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  Future<bool> existsOnline(String name) async {
    final slug = normalizeForPokeApi(name);
    if (slug.isEmpty) {
      return false;
    }
    final response = await _client
        .get(
          Uri.parse('https://pokeapi.co/api/v2/pokemon-species/$slug'),
          headers: const {'accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data is Map && data['name'] is String;
    }
    return false;
  }

  static String normalizeName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('♀', ' female')
        .replaceAll('♂', ' male')
        .replaceAll(RegExp(r'[’`]'), "'")
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String normalizeForPokeApi(String value) {
    return normalizeName(
      value,
    ).replaceAll(RegExp(r"[^a-z0-9]+"), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
