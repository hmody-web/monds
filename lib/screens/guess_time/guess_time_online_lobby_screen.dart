import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/mundas_colors.dart';
import '../../models/guess_time_models.dart';
import '../../models/killer_killed_avatar.dart';
import '../../services/guess_time/guess_time_online_service.dart';
import '../../widgets/dot_background.dart';
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
    return Scaffold(
      body: SafeArea(
        child: DotBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                child: Row(
                  children: [
                    IconButton.filledTonal(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_forward_rounded)),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('غرفة خمن الوقت', style: TextStyle(fontSize: 21))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: MundasColors.primaryLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: MundasColors.primary)),
                      child: Text(widget.identity.roomCode, style: const TextStyle(color: MundasColors.primaryDark, fontSize: 17, letterSpacing: 2)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 650),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF0A2830), Color(0xFF104B52)]),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: MundasColors.ink, width: 2),
                              boxShadow: const [BoxShadow(color: MundasColors.ink, offset: Offset(0, 6), blurRadius: 0)],
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.groups_3_rounded, color: Colors.white, size: 42),
                                const SizedBox(height: 10),
                                const Text('بانتظار اللاعبين', style: TextStyle(color: Colors.white, fontSize: 24)),
                                const SizedBox(height: 5),
                                Text('شارك الرمز ${widget.identity.roomCode} • تبدأ من لاعبين إلى 4', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(.72), fontSize: 11.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (current == null)
                            const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
                          else
                            for (var i = 0; i < 4; i++) ...[
                              _playerSlot(i, i < current.players.length ? current.players[i] : null),
                              if (i != 3) const SizedBox(height: 10),
                            ],
                          if (error != null) ...[
                            const SizedBox(height: 14),
                            Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: MundasColors.coral, fontSize: 12)),
                          ],
                          const SizedBox(height: 20),
                          if (widget.identity.isHost)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton.icon(
                                onPressed: busy || (current?.players.length ?? 0) < 2 ? null : _start,
                                icon: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow_rounded),
                                label: const Text('ابدأ الخمس جولات'),
                                style: FilledButton.styleFrom(backgroundColor: MundasColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(.82), borderRadius: BorderRadius.circular(18), border: Border.all(color: MundasColors.line)),
                              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)), SizedBox(width: 10), Text('المضيف سيبدأ اللعبة')]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerSlot(int index, GuessTimeOnlinePlayer? player) {
    final color = GuessTimePalette.colors[index];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.88), borderRadius: BorderRadius.circular(19), border: Border.all(color: player == null ? MundasColors.line : color.withOpacity(.55), width: player == null ? 1 : 1.6)),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(player == null ? .09 : .17), border: Border.all(color: color.withOpacity(.65))), child: Icon(player == null ? Icons.chair_alt_rounded : Icons.person_rounded, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Text(player?.name ?? 'مقعد فارغ', style: TextStyle(fontSize: 14, color: player == null ? MundasColors.muted : MundasColors.ink))),
          if (player?.host == true) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: MundasColors.gold.withOpacity(.30), borderRadius: BorderRadius.circular(999)), child: const Text('المضيف', style: TextStyle(fontSize: 10))),
        ],
      ),
    );
  }
}
