import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../models/online_room.dart';

class OnlineIdentity {
  final String roomCode;
  final String playerId;
  final String playerToken;
  final bool isHost;
  const OnlineIdentity({required this.roomCode, required this.playerId, required this.playerToken, required this.isHost});
}

class MultiplayerException implements Exception {
  final String message;
  const MultiplayerException(this.message);
  @override
  String toString() => message;
}

class MultiplayerService {
  static const _timeout = Duration(seconds: 12);
  final http.Client _client;
  MultiplayerService([http.Client? client]) : _client = client ?? http.Client();

  Uri _uri(String file, [Map<String, String>? q]) => Uri.parse('${AppConfig.apiBaseUrl}/$file').replace(queryParameters: q);

  Future<Map<String, dynamic>> _post(String file, Map<String, dynamic> data) async {
    try {
      final res = await _client.post(_uri(file), headers: {'Content-Type': 'application/json', 'Accept': 'application/json'}, body: jsonEncode(data)).timeout(_timeout);
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || decoded['ok'] != true) {
        throw MultiplayerException('${decoded['error'] ?? 'تعذر الاتصال بالخادم'}');
      }
      return decoded;
    } catch (e) {
      if (e is MultiplayerException) rethrow;
      throw MultiplayerException('تعذر الوصول إلى خادم اللعب. تحقق من الإنترنت وحاول مرة ثانية.');
    }
  }

  Future<OnlineIdentity> createRoom({required String name, required int avatar}) async {
    final j = await _post('create_room.php', {'name': name, 'avatar': avatar});
    return OnlineIdentity(roomCode: '${j['room_code']}', playerId: '${j['player_id']}', playerToken: '${j['player_token']}', isHost: true);
  }

  Future<OnlineIdentity> joinRoom({required String code, required String name, required int avatar}) async {
    final j = await _post('join_room.php', {'room_code': code.trim().toUpperCase(), 'name': name, 'avatar': avatar});
    return OnlineIdentity(roomCode: '${j['room_code']}', playerId: '${j['player_id']}', playerToken: '${j['player_token']}', isHost: false);
  }

  Future<OnlineRoom> room(OnlineIdentity id, {int? since}) async {
    try {
      final q = <String, String>{'room_code': id.roomCode, 'player_id': id.playerId, 'player_token': id.playerToken};
      if (since != null) q['since'] = '$since';
      final res = await _client.get(_uri('room.php', q), headers: {'Accept': 'application/json'}).timeout(_timeout);
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400 || j['ok'] != true) throw MultiplayerException('${j['error'] ?? 'تعذر تحديث الغرفة'}');
      return OnlineRoom.fromJson((j['room'] as Map).cast<String, dynamic>());
    } catch (e) {
      if (e is MultiplayerException) rethrow;
      throw const MultiplayerException('انقطع الاتصال بالخادم.');
    }
  }

  Future<void> action(OnlineIdentity id, String action, [Map<String, dynamic>? payload]) async {
    await _post('action.php', {
      'room_code': id.roomCode,
      'player_id': id.playerId,
      'player_token': id.playerToken,
      'action': action,
      'payload': payload ?? <String, dynamic>{},
    });
  }
}
