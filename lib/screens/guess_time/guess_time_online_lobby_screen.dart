import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/mundas_colors.dart';
import '../../models/guess_time_models.dart';
import '../../models/killer_killed_avatar.dart';
import '../../services/guess_time/guess_time_online_service.dart';
import '../../widgets/dot_background.dart';
import '../../widgets/arcade_game_shell.dart';
import 'guess_time_game_screen.dart';

class GuessTimeOnlineLobbyScreen extends StatefulWidget {
  const GuessTimeOnlineLobbyScreen({
    super.key,
    required this.identity,
    required this.service,
    required this.avatar,
  });

  final GuessTimeOnlineIdentity identity;
  final GuessTimeOnlineService service;
  final KillerKilledAvatar avatar;

  @override
  State<GuessTimeOnlineLobbyScreen> createState() => _GuessTimeOnlineLobbyScreenState();
}

class _GuessTimeOnlineLobbyScreenState extends State<GuessTimeOnlineLobbyScreen> {
  Timer? _pollTimer;
  GuessTimeOnlineState? state;
  bool busy = false;
  bool _openingGame = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 900), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    widget.service.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (busy || _openingGame || !mounted) return;
    try {
      final next = await widget.service.state(widget.identity);
      if (!mounted) return;
      setState(() {
        state = next;
        error = null;
      });
      if (next.phase != GuessTimePhase.waiting &&
          next.phase != GuessTimePhase.finished &&
          !_openingGame) {
        _openingGame = true;
        _pollTimer?.cancel();
        final players = next.players
            .map(
              (p) => GuessTimePlayer(
                id: p.id,
                name: p.name,
                colorIndex: p.colorIndex,
                isBot: false,
                isLocal: p.id == widget.identity.playerId,
                avatar: p.avatar,
              ),
            )
            .toList();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuessTimeGameScreen.online(
              players: players,
              identity: widget.identity,
              service: widget.service,
              initialState: next,
            ),
          ),
        );
        if (!mounted) return;
        _openingGame = false;
        _pollTimer = Timer.periodic(const Duration(milliseconds: 900), (_) => _refresh());
        _refresh();
      }
    } on GuessTimeOnlineException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _start() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.service.action(widget.identity, 'start');
      if (mounted) setState(() => busy = false);
      await _refresh();
    } on GuessTimeOnlineException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted && busy) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = state;
    return ArcadeGameShell(
      title: 'غرفة خمن الوقت',
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                ArcadePanel(
                  child: Column(
                    children: [
                      const Text(
                        'رمز الغرفة',
                        style: TextStyle(
                          fontFamily: 'PCB',
                          color: Color(0xFFFFF1B0),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF050D15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFC547), width: 2.5),
                        ),
                        child: Text(
                          widget.identity.roomCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (current == null)
                  const ArcadePanel(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: Color(0xFFFFC547)),
                    ),
                  )
                else
                  for (var i = 0; i < 4; i++) ...[
                    _playerSlot(i, i < current.players.length ? current.players[i] : null),
                    if (i != 3) const SizedBox(height: 9),
                  ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFFF7770), fontWeight: FontWeight.w800),
                  ),
                ],
                const SizedBox(height: 16),
                if (widget.identity.isHost)
                  ArcadePrimaryButton(
                    label: 'ابدأ اللعبة',
                    busy: busy,
                    onPressed: busy || (current?.players.length ?? 0) < 2 ? null : _start,
                  )
                else
                  const ArcadePanel(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFFFFC547)),
                        ),
                        SizedBox(width: 10),
                        Text('بانتظار المضيف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playerSlot(int index, GuessTimeOnlinePlayer? player) {
    final color = GuessTimePalette.colors[index];
    return ArcadePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(player == null ? .08 : .22),
              border: Border.all(color: player == null ? const Color(0xFF31566E) : color, width: 2),
            ),
            child: Icon(player == null ? Icons.chair_alt_rounded : Icons.person_rounded, color: player == null ? const Color(0xFF7997AA) : color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              player?.name ?? 'مقعد فارغ',
              style: TextStyle(
                color: player == null ? const Color(0xFF91AABA) : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (player?.host == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA31A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('المضيف', style: TextStyle(color: Color(0xFF311006), fontSize: 10, fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );
  }
}
