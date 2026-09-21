import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../data/word_repository.dart';
import '../../models/game_category.dart';
import '../../models/online_room.dart';
import '../../services/multiplayer_service.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_card.dart';
import '../../widgets/mundas_scaffold.dart';
import 'multiplayer_game_screen.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  final OnlineIdentity identity;
  const MultiplayerLobbyScreen({super.key, required this.identity});
  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  final service = MultiplayerService();
  final repo = WordRepository();
  Timer? timer;
  OnlineRoom? room;
  List<GameCategory> categories = [];
  final Set<String> selected = {};
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    repo.loadCategories().then((v) {
      if (!mounted) return;
      setState(() {
        categories = v;
        selected.addAll(v.map((e) => e.slug));
      });
    });
    _poll();
    timer = Timer.periodic(const Duration(milliseconds: 900), (_) => _poll());
  }

  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  Future<void> _poll() async {
    try {
      final r = await service.room(widget.identity, since: room?.version);
      if (!mounted) return;
      if (r.phase != 'lobby') {
        timer?.cancel();
        Navigator.pushReplacement(context, mundasRoute(MultiplayerGameScreen(identity: widget.identity, initialRoom: r)));
        return;
      }
      setState(() { room = r; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _start() async {
    if ((room?.players.length ?? 0) < 3) return _toast('تحتاجون 3 لاعبين على الأقل');
    if (selected.isEmpty) return _toast('اختر فئة واحدة على الأقل');
    setState(() => busy = true);
    try {
      await service.action(widget.identity, 'start_game', {'categories': selected.toList()});
      await _poll();
    } catch (e) { _toast('$e'); }
    if (mounted) setState(() => busy = false);
  }

  void _toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    final r = room;
    return MundasScaffold(
      title: 'غرفة ${widget.identity.roomCode}',
      showBack: false,
      child: r == null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), if (error != null) Padding(padding: const EdgeInsets.all(18), child: Text(error!, textAlign: TextAlign.center))]))
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
              children: [
                MundasCard(
                  color: MundasColors.primaryLight,
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: QrImageView(data: 'https://scrptaty.com/apps/imposter/join?room=${r.code}', size: 92, padding: EdgeInsets.zero)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('رمز الغرفة', style: TextStyle(color: MundasColors.muted)),
                      SelectableText(r.code, style: const TextStyle(fontSize: 34, letterSpacing: 5, color: MundasColors.primaryDark)),
                      const Text('شارك الرمز أو الـ QR مع أصدقائك.', style: TextStyle(fontSize: 12.5, color: MundasColors.muted)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 18),
                Text('اللاعبون (${r.players.length})', style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 10),
                ...r.players.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: MundasColors.line)),
                    child: Row(children: [
                      Text(['🕵️','🦊','🐼','🐯','🐸','🦝','🐧','🐻'][p.avatar % 8], style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(p.name, style: const TextStyle(fontSize: 17))),
                      if (p.host) const Text('👑'),
                      if (!p.connected) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.cloud_off_rounded, color: MundasColors.muted, size: 18)),
                    ]),
                  ),
                )),
                if (widget.identity.isHost) ...[
                  const SizedBox(height: 16),
                  const Text('الفئات', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 9),
                  Wrap(spacing: 8, runSpacing: 8, children: categories.map((c) {
                    final on = selected.contains(c.slug);
                    return FilterChip(selected: on, label: Text('${c.emoji} ${c.nameAr}'), onSelected: (v) => setState(() => v ? selected.add(c.slug) : selected.remove(c.slug)));
                  }).toList()),
                  const SizedBox(height: 20),
                  MundasButton(label: busy ? 'جاري البدء...' : 'ابدأ اللعبة', icon: Icons.play_arrow_rounded, onPressed: busy ? null : _start),
                ] else ...[
                  const SizedBox(height: 18),
                  const Center(child: Text('بانتظار المضيف حتى يبدأ اللعبة…', style: TextStyle(color: MundasColors.muted))),
                ],
                if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: MundasColors.coral), textAlign: TextAlign.center)),
              ],
            ),
    );
  }
}
