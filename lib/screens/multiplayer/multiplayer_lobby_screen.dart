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
import '../../widgets/arcade_game_shell.dart';
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
    if ((room?.players.length ?? 0) < 3) return _toast('تحتاج اللعبة إلى 3 لاعبين على الأقل');
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
    return ArcadeGameShell(
      title: 'غرفة خمن من الرسم',
      child: r == null
          ? Center(
              child: ArcadePanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFFFC547)),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF7770))),
                    ],
                  ],
                ),
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
              children: [
                ArcadePanel(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: QrImageView(
                          data: 'https://scrptaty.com/apps/imposter/join?room=${r.code}',
                          size: 86,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('رمز الغرفة', style: TextStyle(color: Color(0xFF91AABA), fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            SelectableText(
                              r.code,
                              style: const TextStyle(color: Colors.white, fontSize: 30, letterSpacing: 5, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final p in r.players) ...[
                  ArcadePanel(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(
                      children: [
                        Text(['🕵️','🦊','🐼','🐯','🐸','🦝','🐧','🐻'][p.avatar % 8], style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
                        if (p.host) const Text('👑'),
                        if (!p.connected) const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.cloud_off_rounded, color: Color(0xFF91AABA), size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (widget.identity.isHost) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'اختر الفئات',
                    style: TextStyle(fontFamily: 'PCB', color: Color(0xFFFFF1B0), fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((c) {
                      final on = selected.contains(c.slug);
                      return FilterChip(
                        selected: on,
                        label: Text('${c.emoji} ${c.nameAr}'),
                        labelStyle: TextStyle(color: on ? Colors.white : const Color(0xFFDCECF5), fontWeight: FontWeight.w700),
                        selectedColor: const Color(0xFFB72822),
                        backgroundColor: const Color(0xFF101820),
                        side: BorderSide(color: on ? const Color(0xFFFFC547) : const Color(0xFF31566E), width: 1.5),
                        onSelected: (v) => setState(() => v ? selected.add(c.slug) : selected.remove(c.slug)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  ArcadePrimaryButton(
                    label: busy ? 'يرجى الانتظار' : 'ابدأ اللعبة',
                    busy: busy,
                    onPressed: busy ? null : _start,
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  const ArcadePanel(
                    child: Center(
                      child: Text('بانتظار المضيف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Color(0xFFFF7770)), textAlign: TextAlign.center),
                ],
              ],
            ),
    );
  }
}
