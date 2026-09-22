import 'package:shared_preferences/shared_preferences.dart';

abstract final class PlayerNameStore {
  static const _localKey = 'mundas_local_player_names_v1';
  static const _onlineKey = 'mundas_online_player_name_v1';

  static Future<List<String>> loadLocalNames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_localKey) ?? const <String>[];
  }

  static Future<void> saveLocalNames(List<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _localKey,
      names.map((e) => e.trim()).toList(growable: false),
    );
  }

  static Future<String> loadOnlineName() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_onlineKey) ?? '').trim();
  }

  static Future<void> saveOnlineName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final value = name.trim();
    if (value.isEmpty) {
      await prefs.remove(_onlineKey);
      return;
    }
    await prefs.setString(_onlineKey, value);
  }
}
