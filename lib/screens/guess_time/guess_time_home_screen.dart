import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/mundas_colors.dart';
import '../../models/guess_time_models.dart';
import '../../models/killer_killed_avatar.dart';
import '../../services/guess_time/guess_time_online_service.dart';
import '../../services/killer_killed/killer_killed_avatar_store.dart';
import '../../services/player_name_store.dart';
import '../../widgets/dot_background.dart';
import '../killer_killed/killer_killed_avatar_customizer.dart';
import 'guess_time_game_screen.dart';
import 'guess_time_online_lobby_screen.dart';

enum _GuessEntryMode { local, online }

class GuessTimeHomeScreen extends StatefulWidget {
  const GuessTimeHomeScreen({super.key});

  @override
  State<GuessTimeHomeScreen> createState() => _GuessTimeHomeScreenState();
}

class _GuessTimeHomeScreenState extends State<GuessTimeHomeScreen> {
  _GuessEntryMode mode = _GuessEntryMode.local;
  int humanCount = 1;
  KillerKilledAvatar avatar = KillerKilledAvatar.defaultAvatar;
  late final List<KillerKilledAvatar> localAvatars = List<KillerKilledAvatar>.generate(
    4,
    (i) => i == 0
        ? KillerKilledAvatar.defaultAvatar
        : KillerKilledAvatar.random(math.Random(9100 + i)),
  );
  final TextEditingController nameController = TextEditingController(text: 'محمد');
  final TextEditingController codeController = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    final savedAvatar = await KillerKilledAvatarStore.load();
    var name = await PlayerNameStore.loadOnlineName();
    if (name.isEmpty) {
      final locals = await PlayerNameStore.loadLocalNames();
      if (locals.isNotEmpty) name = locals.first.trim();
    }
    if (!mounted) return;
    setState(() {
      avatar = savedAvatar;
      localAvatars[0] = savedAvatar;
      if (name.isNotEmpty) nameController.text = name;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> _customize([int slot = 0]) async {
    final safeSlot = slot.clamp(0, 3).toInt();
    final result = await Navigator.push<KillerKilledAvatar>(
      context,
      MaterialPageRoute(
        builder: (_) => KillerKilledAvatarCustomizer(
          initialAvatar: localAvatars[safeSlot],
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      localAvatars[safeSlot] = result;
      if (safeSlot == 0) avatar = result;
    });
    // The shared customizer persists its selection. If we edited another local
    // seat, restore the primary player's saved avatar so other games keep using it.
    if (safeSlot != 0) {
      await KillerKilledAvatarStore.save(localAvatars[0]);
    }
  }

  Future<void> _startLocal() async {
    final storedNames = await PlayerNameStore.loadLocalNames();
    final entered = nameController.text.trim();
    final names = <String>[];
    for (var i = 0; i < humanCount; i++) {
      if (i == 0 && entered.isNotEmpty) {
        names.add(entered);
      } else if (i < storedNames.length && storedNames[i].trim().isNotEmpty) {
        names.add(storedNames[i].trim());
      } else {
        names.add('لاعب ${i + 1}');
      }
    }
    await PlayerNameStore.saveOnlineName(names.first);

    final players = <GuessTimePlayer>[];
    for (var i = 0; i < 4; i++) {
      final human = i < humanCount;
      players.add(
        GuessTimePlayer(
          id: human ? 'local_$i' : 'bot_$i',
          name: human ? names[i] : 'بوت ${i - humanCount + 1}',
          colorIndex: i,
          isBot: !human,
          isLocal: human,
          avatar: human
              ? localAvatars[i]
              : KillerKilledAvatar.random(
                  math.Random(DateTime.now().millisecondsSinceEpoch.hashCode + i),
                ),
        ),
      );
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GuessTimeGameScreen.offline(players: players)),
    );
  }

  Future<void> _createOnline() async {
    await _openOnline(create: true);
  }

  Future<void> _joinOnline() async {
    if (codeController.text.trim().length != 5) {
      setState(() => error = 'اكتب رمز الغرفة المكوّن من 5 أحرف.');
      return;
    }
    await _openOnline(create: false);
  }

  Future<void> _openOnline({required bool create}) async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => error = 'اكتب اسم اللاعب أولاً.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final service = GuessTimeOnlineService();
    try {
      final identity = create
          ? await service.createRoom(name: name, avatar: avatar)
          : await service.joinRoom(code: codeController.text, name: name, avatar: avatar);
      await PlayerNameStore.saveOnlineName(name);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GuessTimeOnlineLobbyScreen(
            identity: identity,
            service: service,
            avatar: avatar,
          ),
        ),
      );
    } on GuessTimeOnlineException catch (e) {
      service.dispose();
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DotBackground(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _topBar()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        children: [
                          _hero(),
                          const SizedBox(height: 18),
                          _rules(),
                          const SizedBox(height: 18),
                          _modeSelector(),
                          const SizedBox(height: 16),
                          _identityCard(),
                          const SizedBox(height: 16),
                          if (mode == _GuessEntryMode.local) _localCard() else _onlineCard(),
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFECEC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFFFB6B6)),
                              ),
                              child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB83232), fontSize: 12)),
                            ),
                          ],
                          const SizedBox(height: 18),
                          if (mode == _GuessEntryMode.local)
                            _primaryButton(label: 'دخول غرفة الوقت', icon: Icons.timer_rounded, onPressed: busy ? null : _startLocal)
                          else
                            Row(
                              children: [
                                Expanded(child: _primaryButton(label: 'إنشاء غرفة', icon: Icons.add_rounded, onPressed: busy ? null : _createOnline)),
                                const SizedBox(width: 10),
                                Expanded(child: _primaryButton(label: 'انضمام', icon: Icons.login_rounded, onPressed: busy ? null : _joinOnline, outlined: true)),
                              ],
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

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        child: Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MundasColors.ink, width: 2),
                  boxShadow: const [BoxShadow(color: MundasColors.ink, offset: Offset(0, 3), blurRadius: 0)],
                ),
                child: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('خمن الوقت', style: TextStyle(fontSize: 23, height: 1.05)),
                  SizedBox(height: 3),
                  Text('احفظ الهدف واضغط في اللحظة الصحيحة', style: TextStyle(color: MundasColors.muted, fontSize: 11.5)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xFFE7F6F2), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFF9FD7CA))),
              child: const Text('5 جولات', style: TextStyle(color: Color(0xFF14796E), fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _hero() => Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: MundasColors.ink, width: 2.2),
          boxShadow: const [BoxShadow(color: MundasColors.ink, offset: Offset(0, 7), blurRadius: 0)],
          gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF071B21), Color(0xFF0D3A43), Color(0xFF071218)]),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(right: -45, top: -50, child: Container(width: 190, height: 190, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF35C77A).withOpacity(.12)))),
            Positioned(left: -28, bottom: -28, child: Icon(Icons.access_time_filled_rounded, size: 210, color: Colors.white.withOpacity(.07))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
                    child: const Text('Surveillance Time Room', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  const Spacer(),
                  const Text('خمن الوقت', style: TextStyle(color: Colors.white, fontSize: 38, height: .95)),
                  const SizedBox(height: 10),
                  Text('28 شاشة، أربعة ألوان، زر واحد... وأقرب شخص للوقت يتصدر.', style: TextStyle(color: Colors.white.withOpacity(.82), fontSize: 13, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _rules() {
    const items = [
      (Icons.visibility_off_rounded, 'احفظ', 'الوقت يختفي'),
      (Icons.touch_app_rounded, 'اضغط', 'بدون عداد ظاهر'),
      (Icons.emoji_events_rounded, '5 جولات', 'الأقل خطأ يفوز'),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.82), borderRadius: BorderRadius.circular(18), border: Border.all(color: MundasColors.line)),
              child: Column(children: [Icon(items[i].$1, color: MundasColors.primary, size: 22), const SizedBox(height: 5), Text(items[i].$2, style: const TextStyle(fontSize: 12)), Text(items[i].$3, style: const TextStyle(fontSize: 9.5, color: MundasColors.muted))]),
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _modeSelector() => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: const Color(0xFFE8F2F0), borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Expanded(child: _modeButton(_GuessEntryMode.local, 'محلي / بوتات', Icons.smart_toy_rounded)),
            Expanded(child: _modeButton(_GuessEntryMode.online, 'أونلاين', Icons.public_rounded)),
          ],
        ),
      );

  Widget _modeButton(_GuessEntryMode value, String label, IconData icon) {
    final selected = mode == value;
    return InkWell(
      onTap: () => setState(() {
        mode = value;
        error = null;
      }),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(14), boxShadow: selected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 8)] : null),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 18, color: selected ? MundasColors.primaryDark : MundasColors.muted), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 12.5, color: selected ? MundasColors.ink : MundasColors.muted))]),
      ),
    );
  }

  Widget _identityCard() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.88), borderRadius: BorderRadius.circular(22), border: Border.all(color: MundasColors.line)),
        child: Row(
          children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: MundasColors.primaryLight, border: Border.all(color: MundasColors.primary)), child: const Icon(Icons.person_rounded, color: MundasColors.primaryDark)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسمك', isDense: true))),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: () => _customize(0), icon: const Icon(Icons.checkroom_rounded, size: 18), label: const Text('الشخصية'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))),
          ],
        ),
      );

  Widget _localCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.88), borderRadius: BorderRadius.circular(22), border: Border.all(color: MundasColors.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('عدد اللاعبين الحقيقيين', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 5),
            const Text('باقي المقاعد تتحول تلقائياً إلى بوتات حتى تظل الغرفة أربعة لاعبين.', style: TextStyle(fontSize: 10.5, color: MundasColors.muted)),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var n = 1; n <= 4; n++) ...[
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => humanCount = n),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 50,
                        decoration: BoxDecoration(color: humanCount == n ? MundasColors.primary : const Color(0xFFF0F5F4), borderRadius: BorderRadius.circular(14), border: Border.all(color: humanCount == n ? MundasColors.primaryDark : MundasColors.line)),
                        alignment: Alignment.center,
                        child: Text('$n', style: TextStyle(color: humanCount == n ? Colors.white : MundasColors.ink, fontSize: 18)),
                      ),
                    ),
                  ),
                  if (n != 4) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 13),
            Row(children: [const Icon(Icons.smart_toy_rounded, size: 18, color: MundasColors.coral), const SizedBox(width: 7), Text('${4 - humanCount} بوت', style: const TextStyle(fontSize: 12.5, color: MundasColors.muted))]),
            const SizedBox(height: 14),
            const Text('شخصيات اللاعبين', style: TextStyle(fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < humanCount; i++)
                  OutlinedButton.icon(
                    onPressed: () => _customize(i),
                    icon: Icon(Icons.checkroom_rounded, size: 16, color: GuessTimePalette.colors[i]),
                    label: Text('لاعب ${i + 1}', style: const TextStyle(fontSize: 10.5)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: GuessTimePalette.colors[i].withOpacity(.55)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _onlineCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.88), borderRadius: BorderRadius.circular(22), border: Border.all(color: MundasColors.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('غرفة أونلاين • 2 إلى 4 لاعبين', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            const Text('أنشئ غرفة جديدة أو اكتب رمز غرفة صديقك. توقيت الضغط يُحسب من الخادم.', style: TextStyle(fontSize: 10.5, color: MundasColors.muted)),
            const SizedBox(height: 14),
            TextField(controller: codeController, textCapitalization: TextCapitalization.characters, maxLength: 5, decoration: const InputDecoration(counterText: '', labelText: 'رمز الغرفة', hintText: 'A7K9P', prefixIcon: Icon(Icons.key_rounded))),
          ],
        ),
      );

  Widget _primaryButton({required String label, required IconData icon, required VoidCallback? onPressed, bool outlined = false}) {
    final child = busy && !outlined
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 20), const SizedBox(width: 7), Text(label)]);
    if (outlined) {
      return SizedBox(height: 54, child: OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(foregroundColor: MundasColors.primaryDark, side: const BorderSide(color: MundasColors.primary, width: 1.6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))), child: child));
    }
    return SizedBox(height: 54, child: FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(backgroundColor: MundasColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)), elevation: 0), child: child));
  }
}
