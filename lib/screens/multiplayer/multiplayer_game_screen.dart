import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/mundas_colors.dart';
import '../../models/online_room.dart';
import '../../services/multiplayer_service.dart';
import '../../widgets/multiplayer_drawing_pad.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_card.dart';
import '../../widgets/mundas_scaffold.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final OnlineIdentity identity;
  final OnlineRoom initialRoom;
  const MultiplayerGameScreen({super.key, required this.identity, required this.initialRoom});
  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  final service = MultiplayerService();
  late OnlineRoom room;
  Timer? timer;
  bool roleVisible = false;
  bool roleSeen = false;
  bool busy = false;
  String? error;
  String? selectedVote;
  final guess = TextEditingController();

  @override
  void initState() {
    super.initState();
    room = widget.initialRoom;
    timer = Timer.periodic(const Duration(milliseconds: 700), (_) => _poll());
  }

  @override
  void dispose() { timer?.cancel(); guess.dispose(); super.dispose(); }

  Future<void> _poll() async {
    try {
      final r = await service.room(widget.identity, since: room.version);
      if (!mounted) return;
      final changedPhase = r.phase != room.phase;
      setState(() {
        room = r;
        error = null;
        if (changedPhase) { selectedVote = null; roleVisible = false; roleSeen = false; }
      });
    } catch (e) { if (mounted) setState(() => error = '$e'); }
  }

  Future<void> _action(String action, [Map<String, dynamic>? payload]) async {
    setState(() => busy = true);
    try { await service.action(widget.identity, action, payload); await _poll(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    if (mounted) setState(() => busy = false);
  }

  OnlinePlayer? get me => room.playerById(widget.identity.playerId);

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (room.phase) {
      case 'role_reveal': body = _role(); break;
      case 'drawing': body = _drawing(); break;
      case 'discussion': body = _discussion(); break;
      case 'voting': body = _voting(); break;
      case 'reveal': body = _reveal(); break;
      case 'imposter_guess': body = _guess(); break;
      case 'game_over': body = _gameOver(); break;
      default: body = const Center(child: CircularProgressIndicator());
    }
    return MundasScaffold(
      title: 'غرفة ${room.code}',
      showBack: false,
      actions: [Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: Icon(error == null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: error == null ? MundasColors.primary : MundasColors.coral))],
      child: AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: KeyedSubtree(key: ValueKey(room.phase), child: body)),
    );
  }

  Widget _role() {
    final r = room;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(children: [
            const Text('دورك سري 👀', style: TextStyle(fontSize: 27)),
            const SizedBox(height: 8),
            const Text('اضغط مطولاً على البطاقة، وارفع إصبعك حتى تخفيها.', textAlign: TextAlign.center, style: TextStyle(color: MundasColors.muted)),
            const SizedBox(height: 24),
            GestureDetector(
              onLongPressStart: (_) { HapticFeedback.mediumImpact(); setState(() { roleVisible = true; roleSeen = true; }); },
              onLongPressEnd: (_) => setState(() => roleVisible = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 330,
                width: double.infinity,
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(color: roleVisible ? (r.amImposter ? MundasColors.coral : MundasColors.primary) : MundasColors.ink, borderRadius: BorderRadius.circular(34), border: Border.all(color: MundasColors.ink, width: 2), boxShadow: const [BoxShadow(color: MundasColors.ink, offset: Offset(0, 8), blurRadius: 0)]),
                child: roleVisible
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: r.amImposter ? [
                        const Text('🕵️', style: TextStyle(fontSize: 64)),
                        const Text('أنت المندس', style: TextStyle(color: Colors.white, fontSize: 38)),
                        const SizedBox(height: 10),
                        const Text('راقب رسوماتهم وخليهم ما يكشفوك.', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
                        if (r.categoryHintEnabled && r.categoryName != null) Padding(padding: const EdgeInsets.only(top: 18), child: Text('تلميح الفئة: ${r.categoryEmoji ?? ''} ${r.categoryName}', style: const TextStyle(color: Colors.white, fontSize: 16))),
                      ] : [
                        Text(r.categoryEmoji ?? '🎨', style: const TextStyle(fontSize: 58)),
                        const Text('كلمتك هي', style: TextStyle(color: Colors.white, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(r.secretWord ?? '...', style: const TextStyle(color: Colors.white, fontSize: 42), textAlign: TextAlign.center),
                      ])
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.visibility_off_rounded, color: Colors.white, size: 68), SizedBox(height: 14), Text('دورك مخفي', style: TextStyle(color: Colors.white, fontSize: 29)), SizedBox(height: 8), Text('اضغط مطولاً للكشف', style: TextStyle(color: Color(0xFFC9D9D7)))]),
              ),
            ),
            const SizedBox(height: 24),
            if (roleSeen) SizedBox(width: double.infinity, child: MundasButton(label: 'فهمت دوري', icon: Icons.check_rounded, onPressed: busy ? null : () => _action('role_seen'))),
            if (!roleSeen) const Text('بانتظار كشفك للدور', style: TextStyle(color: MundasColors.muted)),
          ]),
        ),
      ),
    );
  }

  Widget _drawing() {
    final turn = room.playerById(room.turnPlayerId);
    final mine = room.turnPlayerId == widget.identity.playerId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(children: [
        Row(children: [
          Container(width: 48, height: 48, alignment: Alignment.center, decoration: const BoxDecoration(color: MundasColors.primaryLight, shape: BoxShape.circle), child: Text('${room.turnIndex + 1}', style: const TextStyle(fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(mine ? 'دورك ترسم هسه' : '${turn?.name ?? 'لاعب'} يرسم الآن', style: const TextStyle(fontSize: 20)), Text(mine ? 'أضف تلميحًا واحدًا ذكيًا' : 'شاهد الرسم وهو يتحدث', style: const TextStyle(color: MundasColors.muted, fontSize: 13))])),
        ]),
        const SizedBox(height: 12),
        Expanded(child: MultiplayerDrawingPad(remoteStrokes: room.strokes, enabled: mine && !busy, onStroke: (stroke) async => service.action(widget.identity, 'draw_stroke', {'stroke': stroke}))),
        if (mine) ...[
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: MundasButton(label: 'خلصت دوري', icon: Icons.check_rounded, onPressed: busy ? null : () => _action('finish_turn'))),
        ],
      ]),
    );
  }

  Widget _discussion() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🗣️', style: TextStyle(fontSize: 72)),
      const Text('وقت النقاش', style: TextStyle(fontSize: 34)),
      const SizedBox(height: 8),
      const Text('ناقشوا الرسومات بدون ما تنطقون الكلمة السرية. منو تصرفه مشبوه؟', textAlign: TextAlign.center, style: TextStyle(color: MundasColors.muted, height: 1.55)),
      const SizedBox(height: 24),
      if (widget.identity.isHost) SizedBox(width: double.infinity, child: MundasButton(label: 'ابدأ التصويت', icon: Icons.how_to_vote_rounded, onPressed: busy ? null : () => _action('start_voting')))
      else const Text('بانتظار المضيف لبدء التصويت…', style: TextStyle(color: MundasColors.muted)),
    ])),
  ));

  Widget _voting() {
    final already = me?.voted == true;
    final allowed = room.runoffCandidateIds.isEmpty ? room.players : room.players.where((p) => room.runoffCandidateIds.contains(p.id)).toList();
    return Padding(
      padding: const EdgeInsets.all(18),
      child: already
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('✅', style: TextStyle(fontSize: 62)), SizedBox(height: 10), Text('تم تسجيل صوتك', style: TextStyle(fontSize: 27)), SizedBox(height: 6), Text('بانتظار بقية اللاعبين...', style: TextStyle(color: MundasColors.muted))]))
          : Column(children: [
              const Text('منو المندس؟', style: TextStyle(fontSize: 28)),
              if (room.runoffCandidateIds.isNotEmpty) const Text('تصويت فاصل بين المتعادلين', style: TextStyle(color: MundasColors.coral)),
              const SizedBox(height: 14),
              Expanded(child: GridView.count(crossAxisCount: 2, childAspectRatio: 1.22, crossAxisSpacing: 12, mainAxisSpacing: 12, children: allowed.where((p) => p.id != widget.identity.playerId).map((p) {
                final on = selectedVote == p.id;
                return InkWell(onTap: () => setState(() => selectedVote = p.id), borderRadius: BorderRadius.circular(22), child: AnimatedContainer(duration: const Duration(milliseconds: 170), decoration: BoxDecoration(color: on ? MundasColors.primaryLight : Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: on ? MundasColors.primary : MundasColors.line, width: on ? 2.5 : 1.5)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(['🕵️','🦊','🐼','🐯','🐸','🦝','🐧','🐻'][p.avatar % 8], style: const TextStyle(fontSize: 38)), Text(p.name, style: const TextStyle(fontSize: 18)), if (on) const Icon(Icons.check_circle_rounded, color: MundasColors.primary)])));
              }).toList())),
              SizedBox(width: double.infinity, child: MundasButton(label: 'تأكيد التصويت', icon: Icons.how_to_vote_rounded, onPressed: selectedVote == null || busy ? null : () => _action('vote', {'target_player_id': selectedVote}))),
            ]),
    );
  }

  Widget _reveal() {
    final accused = room.playerById(room.accusedPlayerId);
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('👀', style: TextStyle(fontSize: 72)),
      const Text('أكثر شخص عليه أصوات', style: TextStyle(fontSize: 24)),
      const SizedBox(height: 8),
      Text(accused?.name ?? '...', style: const TextStyle(fontSize: 42, color: MundasColors.coral)),
      const SizedBox(height: 22),
      if (widget.identity.isHost) SizedBox(width: double.infinity, child: MundasButton(label: 'اكشف النتيجة', icon: Icons.visibility_rounded, onPressed: busy ? null : () => _action('reveal_result')))
      else const Text('بانتظار المضيف يكشف النتيجة…', style: TextStyle(color: MundasColors.muted)),
    ]))));
  }

  Widget _guess() {
    if (!room.amImposter) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('🕵️', style: TextStyle(fontSize: 70)), const SizedBox(height: 10), const Text('المندس عنده فرصة أخيرة', style: TextStyle(fontSize: 26)), const SizedBox(height: 6), Text('بانتظار تخمينه…', style: TextStyle(color: MundasColors.muted))]));
    return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: Column(children: [
      const Text('🕵️', style: TextStyle(fontSize: 74)),
      const Text('شنو كانت الكلمة؟', style: TextStyle(fontSize: 30)),
      const SizedBox(height: 8),
      Text('الفئة: ${room.categoryEmoji ?? ''} ${room.categoryName ?? ''}', style: const TextStyle(color: MundasColors.muted)),
      const SizedBox(height: 20),
      TextField(controller: guess, autofocus: true, decoration: const InputDecoration(hintText: 'اكتب تخمينك...')),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, child: MundasButton(label: 'تأكيد التخمين', icon: Icons.psychology_alt_rounded, color: MundasColors.coral, onPressed: busy ? null : () => _action('imposter_guess', {'guess': guess.text.trim()}))),
    ]))));
  }

  Widget _gameOver() {
    final imposterWins = room.winner == 'imposter';
    return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(children: [
      Text(imposterWins ? '😎' : '🎉', style: const TextStyle(fontSize: 86)),
      Text(imposterWins ? 'المندس فاز!' : 'الطاقم فاز!', style: TextStyle(fontSize: 40, color: imposterWins ? MundasColors.coral : MundasColors.primary)),
      const SizedBox(height: 14),
      MundasCard(child: Column(children: [const Text('الكلمة السرية', style: TextStyle(color: MundasColors.muted)), const SizedBox(height: 5), Text(room.secretWord ?? 'تظهر بعد نهاية الجولة', style: const TextStyle(fontSize: 31)), const Divider(height: 26), Text('${room.categoryEmoji ?? ''} ${room.categoryName ?? ''}', style: const TextStyle(fontSize: 17))])),
      const SizedBox(height: 20),
      if (widget.identity.isHost) SizedBox(width: double.infinity, child: MundasButton(label: 'جولة جديدة بنفس الغرفة', icon: Icons.refresh_rounded, onPressed: busy ? null : () => _action('replay')))
      else const Text('بانتظار المضيف للجولة التالية…', style: TextStyle(color: MundasColors.muted)),
      const SizedBox(height: 10),
      TextButton.icon(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), icon: const Icon(Icons.home_rounded), label: const Text('الخروج للرئيسية')),
    ]))));
  }
}
