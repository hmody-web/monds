import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/game_category.dart';

class WordRepository {
  List<GameCategory>? _cache;

  Future<List<GameCategory>> loadCategories() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/words_ar.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _cache = (decoded['categories'] as List)
        .map((e) => GameCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }
}
