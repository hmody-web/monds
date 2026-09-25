import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/app_config.dart';
import '../../models/guess_time_models.dart';
import '../../models/killer_killed_avatar.dart';

class GuessTimeOnlineIdentity {
  const GuessTimeOnlineIdentity({
    required this.roomCode,
    required this.playerId,
    required this.token,
    required this.isHost,
  });

  final String roomCode;
  final String playerId;
  final String token;
  final bool isHost;
}

class GuessTimeOnlinePlayer {
  const GuessTimeOnlinePlayer({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.host,
    required this.connected,
    required this.targetMs,
    required this.stoppedMs,
    required this.totalErrorMs,
    required this.avatar,
  });

  final String id;
  final String name;
  final int colorIndex;
  final bool host;
  final bool connected;
  final int targetMs;
  final int? stoppedMs;
  final int totalErrorMs;
  final KillerKilledAvatar avatar;

  factory GuessTimeOnlinePlayer.fromJson(Map<String, dynamic> j) => GuessTimeOnlinePlayer(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        colorIndex: (j['color_index'] as num?)?.toInt() ?? 0,
        host: j['host'] == true || j['host'] == 1,
        connected: j['connected'] != false && j['connected'] != 0,
        targetMs: (j['target_ms'] as num?)?.toInt() ?? 0,
        stoppedMs: (j['stopped_ms'] as num?)?.toInt(),
        totalErrorMs: (j['total_error_ms'] as num?)?.toInt() ?? 0,
        avatar: j['avatar'] is Map
            ? KillerKilledAvatar.fromJson((j['avatar'] as Map).cast<String, dynamic>())
            : KillerKilledAvatar.defaultAvatar,
      );
}

class GuessTimeOnlineState {
  const GuessTimeOnlineState({
    required this.code,
    required this.phase,
    required this.round,
    required this.version,
    required this.serverNowMs,
    required this.phaseStartedAtMs,
    required this.timingStartedAtMs,
    required this.players,
    required this.screenOwners,
    required this.roundRanking,
    required this.finalRanking,
    required this.loserId,
  });

  final String code;
  final GuessTimePhase phase;
  final int round;
  final int version;
  final int serverNowMs;
  final int phaseStartedAtMs;
  final int? timingStartedAtMs;
  final List<GuessTimeOnlinePlayer> players;
  final List<int> screenOwners;
  final List<String> roundRanking;
  final List<String> finalRanking;
  final String? loserId;

  factory GuessTimeOnlineState.fromJson(Map<String, dynamic> j) {
    GuessTimePhase parsePhase(String value) => switch (value) {
          'reveal' => GuessTimePhase.reveal,
          'countdown' => GuessTimePhase.countdown,
          'timing' => GuessTimePhase.timing,
          'results' => GuessTimePhase.roundResults,
          'final' => GuessTimePhase.finalResults,
          'elimination' => GuessTimePhase.elimination,
          'finished' => GuessTimePhase.finished,
          _ => GuessTimePhase.waiting,
        };

    return GuessTimeOnlineState(
      code: '${j['code'] ?? ''}',
      phase: parsePhase('${j['phase'] ?? 'lobby'}'),
      round: (j['round'] as num?)?.toInt() ?? 0,
      version: (j['version'] as num?)?.toInt() ?? 0,
      serverNowMs: (j['server_now_ms'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      phaseStartedAtMs: (j['phase_started_at_ms'] as num?)?.toInt() ?? 0,
      timingStartedAtMs: (j['timing_started_at_ms'] as num?)?.toInt(),
      players: ((j['players'] as List?) ?? const [])
          .map((e) => GuessTimeOnlinePlayer.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      screenOwners: ((j['screen_owners'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
      roundRanking: ((j['round_ranking'] as List?) ?? const []).map((e) => '$e').toList(),
      finalRanking: ((j['final_ranking'] as List?) ?? const []).map((e) => '$e').toList(),
      loserId: j['loser_id']?.toString(),
    );
  }

  GuessTimeOnlinePlayer? player(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }
}

class GuessTimeOnlineException implements Exception {
  const GuessTimeOnlineException(this.message);
  final String message;
  @override
  String toString() => message;
}

class GuessTimeOnlineService {
  GuessTimeOnlineService([http.Client? client]) : _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 12);
  final http.Client _client;

  Uri _uri(String file) => Uri.parse('${AppConfig.apiBaseUrl}/guess_time/$file');

  Future<Map<String, dynamic>> _post(String file, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            _uri(file),
            headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final raw = utf8.decode(response.bodyBytes);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException();
      final json = decoded.cast<String, dynamic>();
      if (response.statusCode >= 400 || json['ok'] != true) {
        throw GuessTimeOnlineException('${json['error'] ?? 'تعذر الاتصال بغرفة خمن الوقت'}');
      }
      return json;
    } on GuessTimeOnlineException {
      rethrow;
    } catch (_) {
      throw const GuessTimeOnlineException('تعذر الوصول إلى خادم خمن الوقت. تحقق من الإنترنت وإعداد ملفات الخادم.');
    }
  }

  Future<GuessTimeOnlineIdentity> createRoom({required String name, required KillerKilledAvatar avatar}) async {
    final j = await _post('create_room.php', {'name': name.trim(), 'avatar': avatar.toJson()});
    return GuessTimeOnlineIdentity(
      roomCode: '${j['room_code']}',
      playerId: '${j['player_id']}',
      token: '${j['token']}',
      isHost: true,
    );
  }

  Future<GuessTimeOnlineIdentity> joinRoom({required String code, required String name, required KillerKilledAvatar avatar}) async {
    final j = await _post('join_room.php', {
      'room_code': code.trim().toUpperCase(),
      'name': name.trim(),
      'avatar': avatar.toJson(),
    });
    return GuessTimeOnlineIdentity(
      roomCode: '${j['room_code']}',
      playerId: '${j['player_id']}',
      token: '${j['token']}',
      isHost: false,
    );
  }

  Future<GuessTimeOnlineState> state(GuessTimeOnlineIdentity id) async {
    final j = await _post('state.php', {
      'room_code': id.roomCode,
      'player_id': id.playerId,
      'token': id.token,
    });
    return GuessTimeOnlineState.fromJson((j['state'] as Map).cast<String, dynamic>());
  }

  Future<void> action(GuessTimeOnlineIdentity id, String action) async {
    await _post('action.php', {
      'room_code': id.roomCode,
      'player_id': id.playerId,
      'token': id.token,
      'action': action,
    });
  }

  void dispose() => _client.close();
}
