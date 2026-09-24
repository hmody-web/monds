import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/killer_killed_avatar.dart';

class KillerKilledAvatarStore {
  static const _key = 'killer_killed_avatar_v1';

  static Future<KillerKilledAvatar> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return KillerKilledAvatar.defaultAvatar;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return KillerKilledAvatar.fromJson(decoded);
      }
      if (decoded is Map) {
        return KillerKilledAvatar.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {}
    return KillerKilledAvatar.defaultAvatar;
  }

  static Future<void> save(KillerKilledAvatar avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(avatar.toJson()));
  }
}
