class OnlinePlayer {
  final String id;
  final String name;
  final int avatar;
  final bool host;
  final bool connected;
  final bool ready;
  final bool voted;

  const OnlinePlayer({required this.id, required this.name, required this.avatar, required this.host, required this.connected, required this.ready, required this.voted});

  factory OnlinePlayer.fromJson(Map<String, dynamic> j) => OnlinePlayer(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        avatar: (j['avatar'] as num?)?.toInt() ?? 0,
        host: j['host'] == true || j['host'] == 1,
        connected: j['connected'] != false && j['connected'] != 0,
        ready: j['ready'] == true || j['ready'] == 1,
        voted: j['voted'] == true || j['voted'] == 1,
      );
}

class OnlineRoom {
  final String code;
  final String phase;
  final int version;
  final List<OnlinePlayer> players;
  final List<String> categories;
  final int turnIndex;
  final String? turnPlayerId;
  final String? accusedPlayerId;
  final String? winner;
  final String? categoryName;
  final String? categoryEmoji;
  final String? secretWord;
  final bool amImposter;
  final bool roleAvailable;
  final bool categoryHintEnabled;
  final List<Map<String, dynamic>> strokes;
  final List<String> runoffCandidateIds;

  const OnlineRoom({
    required this.code,
    required this.phase,
    required this.version,
    required this.players,
    required this.categories,
    required this.turnIndex,
    required this.turnPlayerId,
    required this.accusedPlayerId,
    required this.winner,
    required this.categoryName,
    required this.categoryEmoji,
    required this.secretWord,
    required this.amImposter,
    required this.roleAvailable,
    required this.categoryHintEnabled,
    required this.strokes,
    required this.runoffCandidateIds,
  });

  factory OnlineRoom.fromJson(Map<String, dynamic> j) {
    final role = (j['my_role'] as Map?)?.cast<String, dynamic>();
    return OnlineRoom(
      code: '${j['code'] ?? ''}',
      phase: '${j['phase'] ?? 'lobby'}',
      version: (j['version'] as num?)?.toInt() ?? 0,
      players: ((j['players'] as List?) ?? const []).map((e) => OnlinePlayer.fromJson((e as Map).cast<String, dynamic>())).toList(),
      categories: ((j['categories'] as List?) ?? const []).map((e) => '$e').toList(),
      turnIndex: (j['turn_index'] as num?)?.toInt() ?? 0,
      turnPlayerId: j['turn_player_id']?.toString(),
      accusedPlayerId: j['accused_player_id']?.toString(),
      winner: j['winner']?.toString(),
      categoryName: role?['category_name']?.toString() ?? j['category_name']?.toString(),
      categoryEmoji: role?['category_emoji']?.toString() ?? j['category_emoji']?.toString(),
      secretWord: role?['secret_word']?.toString(),
      amImposter: role?['is_imposter'] == true,
      roleAvailable: role != null,
      categoryHintEnabled: j['category_hint_enabled'] != false,
      strokes: ((j['strokes'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList(),
      runoffCandidateIds: ((j['runoff_candidate_ids'] as List?) ?? const []).map((e) => '$e').toList(),
    );
  }

  OnlinePlayer? playerById(String? id) {
    if (id == null) return null;
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }
}
