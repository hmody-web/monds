import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/guess_time_models.dart';
import '../../models/killer_killed_avatar.dart';
import '../../services/guess_time/guess_time_online_service.dart';
import '../../services/killer_killed/killer_killed_avatar_store.dart';
import '../../services/player_name_store.dart';
import '../../widgets/live_performance_monitor.dart';
import '../../widgets/arcade_game_shell.dart';
import '../killer_killed/killer_killed_avatar_customizer.dart';
import '../killer_killed/killer_killed_avatar_preview.dart';
import 'guess_time_game_screen.dart';
import 'guess_time_online_lobby_screen.dart';

enum _GuessEntryMode { local, online }

class GuessTimeHomeScreen extends StatefulWidget {
  const GuessTimeHomeScreen({
    super.key,
    this.initialOnline = false,
  });

  final bool initialOnline;

  @override
  State<GuessTimeHomeScreen> createState() => _GuessTimeHomeScreenState();
}

class _GuessTimeHomeScreenState extends State<GuessTimeHomeScreen> {
  _GuessEntryMode mode = _GuessEntryMode.local;
  KillerKilledAvatar avatar = KillerKilledAvatar.defaultAvatar;
  final TextEditingController nameController = TextEditingController(text: 'محمد');
  final TextEditingController codeController = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    mode = widget.initialOnline
        ? _GuessEntryMode.online
        : _GuessEntryMode.local;
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
      if (name.isNotEmpty) nameController.text = name;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> _customizeAvatar() async {
    final result = await Navigator.push<KillerKilledAvatar>(
      context,
      MaterialPageRoute(
        builder: (_) => KillerKilledAvatarCustomizer(initialAvatar: avatar),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => avatar = result);
    await KillerKilledAvatarStore.save(result);
  }

  Future<void> _startLocal() async {
    final storedNames = await PlayerNameStore.loadLocalNames();
    final entered = nameController.text.trim();
    final localName = entered.isNotEmpty
        ? entered
        : (storedNames.isNotEmpty && storedNames.first.trim().isNotEmpty
              ? storedNames.first.trim()
              : 'اللاعب');

    await PlayerNameStore.saveOnlineName(localName);

    // Every NEW full game randomizes the human seat. The player is no longer
    // permanently tied to station 1 / the red chair.
    final seatRandom = math.Random(DateTime.now().microsecondsSinceEpoch);
    final localSeat = seatRandom.nextInt(4);
    final players = <GuessTimePlayer>[];
    var botNumber = 1;
    for (var seat = 0; seat < 4; seat++) {
      final human = seat == localSeat;
      players.add(
        GuessTimePlayer(
          id: human ? 'local_0' : 'bot_${botNumber}',
          name: human ? localName : 'بوت ${botNumber}',
          colorIndex: seat,
          isBot: !human,
          isLocal: human,
          avatar: human
              ? avatar
              : KillerKilledAvatar.random(
                  math.Random(DateTime.now().millisecondsSinceEpoch.hashCode + seat * 91),
                ),
        ),
      );
      if (!human) botNumber++;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuessTimeGameScreen.offline(players: players),
      ),
    );
  }

  Future<void> _createOnline() async => _openOnline(create: true);

  Future<void> _joinOnline() async {
    if (codeController.text.trim().length != 5) {
      _showNotice('اكتب رمز غرفة صحيح من 5 أحرف.');
      return;
    }
    await _openOnline(create: false);
  }

  Future<void> _openOnline({required bool create}) async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      _showNotice('اكتب اسمك أولاً.');
      return;
    }
    setState(() => busy = true);
    final service = GuessTimeOnlineService();
    try {
      final identity = create
          ? await service.createRoom(name: name, avatar: avatar)
          : await service.joinRoom(
              code: codeController.text.trim(),
              name: name,
              avatar: avatar,
            );
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
      if (mounted) _showNotice(e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _handlePrimaryStart() async {
    FocusScope.of(context).unfocus();
    if (busy) return;
    if (mode == _GuessEntryMode.local) {
      await _startLocal();
    } else {
      if (codeController.text.trim().isEmpty) {
        await _createOnline();
      } else {
        await _joinOnline();
      }
    }
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      );
  }

  Future<void> _showPlaySettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(14, 18, 14, bottom + 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(.18)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xE61A2234),
                          const Color(0xF0101522),
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x80000000),
                          blurRadius: 28,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'الإعدادات',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.07),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withOpacity(.08)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _sheetModeButton(
                                      selected: mode == _GuessEntryMode.local,
                                      icon: Icons.smart_toy_rounded,
                                      label: 'ضد بوتات',
                                      onTap: () {
                                        setState(() => mode = _GuessEntryMode.local);
                                        setSheetState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _sheetModeButton(
                                      selected: mode == _GuessEntryMode.online,
                                      icon: Icons.groups_rounded,
                                      label: 'أونلاين',
                                      onTap: () {
                                        setState(() => mode = _GuessEntryMode.online);
                                        setSheetState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            _sheetLabel('اسم اللاعب'),
                            const SizedBox(height: 8),
                            _sheetField(
                              controller: nameController,
                              hint: 'اسمك',
                              icon: Icons.person_rounded,
                              textInputAction: TextInputAction.done,
                            ),
                            const SizedBox(height: 16),
                            _sheetLabel('الشخصية'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.06),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.white.withOpacity(.10)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF3D8BFF), Color(0xFF00D1FF)],
                                            ),
                                          ),
                                          child: const Icon(Icons.person_rounded, color: Colors.white),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'الشخصية الحالية',
                                            style: TextStyle(color: Colors.white, fontSize: 14),
                                          ),
                                        ),
                                        FilledButton.icon(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await _customizeAvatar();
                                          },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF3B82F6),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                          icon: const Icon(Icons.checkroom_rounded, size: 18),
                                          label: const Text('تعديل'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (mode == _GuessEntryMode.local) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF13395E).withOpacity(.45),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(.08)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'ستلعب أنت مع 3 بوتات.',
                                        style: TextStyle(color: Colors.white, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              _sheetLabel('رمز الغرفة'),
                              const SizedBox(height: 8),
                              _sheetField(
                                controller: codeController,
                                hint: 'اتركه فارغًا لإنشاء غرفة',
                                icon: Icons.key_rounded,
                                textCapitalization: TextCapitalization.characters,
                                textInputAction: TextInputAction.done,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: busy ? null : _createOnline,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF3B82F6),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 15),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('إنشاء غرفة'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: busy ? null : _joinOnline,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(color: Colors.white.withOpacity(.20)),
                                        padding: const EdgeInsets.symmetric(vertical: 15),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                      icon: const Icon(Icons.login_rounded),
                                      label: const Text('انضمام'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _showHowToPlay() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.72),
      builder: (dialogContext) => const ArcadeDetailsDialog(
        title: 'تفاصيل خمن الوقت',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HowToItem(index: 1, text: 'احفظ الوقت المطلوب جيدًا.'),
            _HowToItem(index: 2, text: 'أوقف العداد في اللحظة الأقرب للوقت.'),
            _HowToItem(index: 3, text: 'الأقرب يفوز بالجولة.'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = mode == _GuessEntryMode.online;
    return ArcadeGameShell(
      title: 'خمن الوقت',
      onDetails: _showHowToPlay,
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ArcadePanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA31A),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFFFDC68), width: 3),
                      boxShadow: const [
                        BoxShadow(color: Color(0x88000000), offset: Offset(0, 7), blurRadius: 0),
                      ],
                    ),
                    child: Icon(
                      online ? Icons.groups_rounded : Icons.timer_rounded,
                      color: const Color(0xFF311006),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    online ? 'اللعب مع صديق' : 'جاهز للتحدي',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PCB',
                      color: Color(0xFFFFF1B0),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ArcadeTextField(
                    controller: nameController,
                    hint: 'اسم اللاعب',
                    icon: Icons.person_rounded,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (online) ...[
                    const SizedBox(height: 14),
                    ArcadeTextField(
                      controller: codeController,
                      hint: 'رمز الغرفة',
                      icon: Icons.key_rounded,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ArcadePrimaryButton(
                            label: 'إنشاء غرفة',
                            icon: Icons.add_circle_outline_rounded,
                            busy: busy,
                            onPressed: busy ? null : _createOnline,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ArcadePrimaryButton(
                            label: 'دخول الغرفة',
                            icon: Icons.login_rounded,
                            busy: busy,
                            onPressed: busy ? null : _joinOnline,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    ArcadePrimaryButton(
                      label: 'ابدأ التحدي',
                      busy: busy,
                      onPressed: busy ? null : _startLocal,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _arcadeHeader({required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 14,
        compact ? 8 : 12,
        compact ? 8 : 14,
        4,
      ),
      child: Row(
        children: [
          _ArcadeSquareButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: 'رجوع',
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(width: compact ? 8 : 14),
          Expanded(
            child: Container(
              height: compact ? 62 : 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFF451C),
                    Color(0xFFD71910),
                    Color(0xFF8A0B08),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFFFD04B),
                  width: 5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xAA000000),
                    offset: Offset(0, 6),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  for (final alignment in const [
                    Alignment(-.96, -.72),
                    Alignment(.96, -.72),
                    Alignment(-.96, .72),
                    Alignment(.96, .72),
                  ])
                    Align(
                      alignment: alignment,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFEA81),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Center(
                    child: Text(
                      'خمن الوقت',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFFFF1A6),
                        fontSize: compact ? 24 : 31,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        shadows: const [
                          Shadow(
                            color: Color(0xFF5A0900),
                            offset: Offset(3, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 14),
          _ArcadeSquareButton(
            icon: Icons.help_outline_rounded,
            tooltip: 'طريقة اللعب',
            onTap: _showHowToPlay,
          ),
        ],
      ),
    );
  }

  Widget _arcadePosterPanel({required bool compact}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFB322),
          width: 4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            offset: Offset(0, 7),
            blurRadius: 0,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/models/arcade_games/guess_time.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFF102E45),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x11000000),
                  Color(0x00000000),
                  Color(0xD9000000),
                ],
                stops: [0, .48, 1],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xD908111A),
                border: Border.all(
                  color: const Color(0xFFFFC63B),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اضغط في اللحظة الأقرب للوقت المطلوب',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _arcadeInfoChip(
                          icon: Icons.timer_outlined,
                          text: 'تحدي توقيت',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _arcadeInfoChip(
                          icon: Icons.people_alt_rounded,
                          text: mode == _GuessEntryMode.online
                              ? 'لعب أون لاين'
                              : 'أنت + 3 بوتات',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _arcadeControlPanel({required bool compact}) {
    final online = mode == _GuessEntryMode.online;

    return Container(
      padding: EdgeInsets.all(compact ? 13 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF102C42),
            Color(0xFF091A29),
            Color(0xFF06121E),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF4FDDEB),
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            offset: Offset(0, 8),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _arcadeModeSelector(),
          const SizedBox(height: 16),
          _arcadePanelLabel(
            online ? 'هوية اللاعب' : 'جاهز للتحدي؟',
            icon: online
                ? Icons.badge_outlined
                : Icons.sports_esports_rounded,
          ),
          const SizedBox(height: 10),
          _arcadeTextField(
            controller: nameController,
            hint: 'اسم اللاعب',
            icon: Icons.person_rounded,
            onChanged: (_) => setState(() {}),
          ),
          if (online) ...[
            const SizedBox(height: 12),
            _arcadeTextField(
              controller: codeController,
              hint: 'رمز الغرفة - اتركه فارغاً لإنشاء غرفة',
              icon: Icons.key_rounded,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _arcadeActionCard(
                  icon: Icons.face_retouching_natural_rounded,
                  title: 'الشخصية',
                  subtitle: 'عدّل مظهرك',
                  onTap: _customizeAvatar,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _arcadeActionCard(
                  icon: Icons.tune_rounded,
                  title: 'الإعدادات',
                  subtitle: 'خيارات اللعب',
                  onTap: _showPlaySettings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _arcadePrimaryButton(),
          if (online) ...[
            const SizedBox(height: 10),
            Text(
              codeController.text.trim().isEmpty
                  ? 'سيتم إنشاء غرفة جديدة وإعطاؤك رمز مشاركة.'
                  : 'سيتم الانضمام إلى الغرفة بهذا الرمز.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB7CEDD),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Text(
              'اللعب المحلي يبدأ مباشرة مع 3 بوتات، ومقعدك يتغير عشوائياً كل جولة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB7CEDD),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _arcadeModeSelector() {
    Widget modeButton({
      required _GuessEntryMode value,
      required String label,
      required IconData icon,
    }) {
      final selected = mode == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => mode = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFF6E1B),
                        Color(0xFFC73B0B),
                      ],
                    )
                  : null,
              color: selected ? null : const Color(0xFF07131E),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFFD254)
                    : const Color(0xFF315268),
                width: 2,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x77000000),
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected
                      ? const Color(0xFFFFF1A4)
                      : const Color(0xFFA7C2D3),
                  size: 20,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFC0D2DD),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF050C13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF284A5F),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          modeButton(
            value: _GuessEntryMode.local,
            label: 'أوف لاين',
            icon: Icons.sports_esports_rounded,
          ),
          const SizedBox(width: 6),
          modeButton(
            value: _GuessEntryMode.online,
            label: 'أون لاين',
            icon: Icons.public_rounded,
          ),
        ],
      ),
    );
  }

  Widget _arcadePanelLabel(
    String text, {
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFA31A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFFFDC68),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF311006),
            size: 19,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFFF1B0),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _arcadeTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF7997AA),
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFFFB62F),
        ),
        filled: true,
        fillColor: const Color(0xFF050D15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF31566E),
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFFFB52B),
            width: 2.5,
          ),
        ),
      ),
    );
  }

  Widget _arcadeActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: const Color(0xFF0A1B29),
          border: Border.all(
            color: const Color(0xFF31566D),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: const Color(0xFFFFB72F),
              size: 27,
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF91AABA),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _arcadePrimaryButton() {
    final online = mode == _GuessEntryMode.online;
    final joining = online && codeController.text.trim().isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: busy ? null : _handlePrimaryStart,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD71910),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF5B2E29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(
              color: Color(0xFFFFD45D),
              width: 4,
            ),
          ),
          elevation: 8,
          shadowColor: Colors.black,
        ),
        child: busy
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFFFE77A),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    online
                        ? (joining
                              ? Icons.login_rounded
                              : Icons.add_circle_outline_rounded)
                        : Icons.play_arrow_rounded,
                    color: const Color(0xFFFFF0A4),
                    size: 28,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    online
                        ? (joining ? 'دخول الغرفة' : 'إنشاء غرفة')
                        : 'ابدأ التحدي',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _arcadeInfoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF112637),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF365E76),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFFFFBF39),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFDCECF5),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetModeButton({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white.withOpacity(.10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _sheetField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0x88FFFFFF)),
        prefixIcon: Icon(icon, color: const Color(0xCCFFFFFF)),
        filled: true,
        fillColor: Colors.white.withOpacity(.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.4),
        ),
      ),
    );
  }

  Widget _sheetLabel(String text) => Text(
        text,
        style: const TextStyle(color: Color(0xFFDCE4F2), fontSize: 12.5),
      );
}


class _ArcadeSquareButton extends StatelessWidget {
  const _ArcadeSquareButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFF7C1E),
                  Color(0xFFD7460E),
                  Color(0xFF8A2307),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFD658),
                width: 3,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xAA000000),
                  offset: Offset(0, 5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFF1A9),
              size: 27,
            ),
          ),
        ),
      ),
    );
  }
}

class _GuessTimeArcadeBackground extends StatelessWidget {
  const _GuessTimeArcadeBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.2),
              radius: 1.05,
              colors: [
                Color(0xFF18405C),
                Color(0xFF092033),
                Color(0xFF03070D),
              ],
              stops: [0, .58, 1],
            ),
          ),
        ),
        CustomPaint(
          painter: _GuessTimeArcadeBackdropPainter(),
        ),
      ],
    );
  }
}

class _GuessTimeArcadeBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tile = 52.0;
    final a = Paint()..color = const Color(0xFF143D56).withOpacity(.26);
    final b = Paint()..color = const Color(0xFF0C2D43).withOpacity(.20);

    var row = 0;
    for (double y = 0; y < size.height * .76; y += tile) {
      var col = 0;
      for (double x = 0; x < size.width; x += tile) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, tile + 1, tile + 1),
          ((row + col) % 2 == 0) ? a : b,
        );
        col++;
      }
      row++;
    }

    final floorTop = size.height * .80;
    const floorTile = 44.0;
    var fy = 0;
    for (double y = floorTop; y < size.height; y += floorTile) {
      var fx = 0;
      for (double x = 0; x < size.width; x += floorTile) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, floorTile + 1, floorTile + 1),
          Paint()
            ..color = ((fx + fy) % 2 == 0)
                ? const Color(0xFF8D1B11).withOpacity(.34)
                : const Color(0xFF3F0B08).withOpacity(.42),
        );
        fx++;
      }
      fy++;
    }

    for (final x in <double>[
      size.width * .15,
      size.width * .50,
      size.width * .85,
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, 42),
            width: 76,
            height: 14,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFFFA31B).withOpacity(.70),
      );
    }

    final vignette = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: .86,
        colors: [
          Color(0x00000000),
          Color(0x55000000),
          Color(0xBB000000),
        ],
        stops: [0, .72, 1],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _GuessTimeBackdrop extends StatelessWidget {
  const _GuessTimeBackdrop();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: compact ? 1.8 : 0.8, sigmaY: compact ? 1.8 : 0.8),
                child: Image.asset(
                  'assets/images/guess_time_home_bg.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: compact ? .22 : .12,
                child: Transform.scale(
                  scale: compact ? 1.14 : 1.06,
                  child: Image.asset(
                    'assets/images/guess_time_home_bg.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CinematicAvatarStage extends StatefulWidget {
  const _CinematicAvatarStage({
    required this.avatar,
    required this.expanded,
  });

  final KillerKilledAvatar avatar;
  final bool expanded;

  @override
  State<_CinematicAvatarStage> createState() => _CinematicAvatarStageState();
}

class _CinematicAvatarStageState extends State<_CinematicAvatarStage> {
  Timer? _idleTimer;
  double _idleSeconds = 0;

  @override
  void initState() {
    super.initState();
    // The lobby used to animate at the display refresh rate even when nobody
    // touched the phone. A calm 7 Hz idle pulse is more than enough for the
    // breathing/light effect and saves a lot of unnecessary work while the
    // player stays on this page.
    _idleTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      if (!mounted) return;
      setState(() => _idleSeconds += .14);
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageWidth = widget.expanded
            ? math.min(680.0, constraints.maxWidth * .72)
            : math.min(470.0, constraints.maxWidth * 1.08);
        final stageHeight = widget.expanded
            ? math.min(860.0, constraints.maxHeight * 1.16)
            : math.min(690.0, constraints.maxHeight * 1.22);

        final wave = (math.sin(_idleSeconds * 1.85) + 1) * .5;
        final wave2 = (math.sin(_idleSeconds * 1.15 + 1.6) + 1) * .5;
        final breatheY = lerpDouble(4, -4, wave) ?? 0;
        final breatheScale = lerpDouble(.996, 1.006, wave) ?? 1;
        final glowScale = lerpDouble(.96, 1.04, wave) ?? 1;

        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: widget.expanded ? 12 : 8,
              child: Transform.scale(
                scale: glowScale,
                child: Container(
                  width: stageWidth * .76,
                  height: widget.expanded ? 92 : 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(.50),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD33D).withOpacity(.16),
                        blurRadius: widget.expanded ? 48 : 36,
                        spreadRadius: widget.expanded ? 14 : 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: widget.expanded ? 5 : 2,
              child: Container(
                width: stageWidth * .64,
                height: widget.expanded ? 48 : 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF485266), Color(0xFF171C27), Color(0xFF080B10)],
                  ),
                  border: Border.all(color: const Color(0x55FFFFFF)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 9)),
                  ],
                ),
              ),
            ),
            Positioned(
              // Keep the feet planted on the pedestal. The camera framing
              // handles the head room, so the widget itself no longer floats.
              bottom: widget.expanded ? -34 : -38,
              child: Transform.translate(
                offset: Offset(0, breatheY),
                child: Transform.scale(
                  scale: breatheScale,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: stageWidth,
                    height: stageHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        KillerKilledAvatarPreview(
                          avatar: widget.avatar,
                          interactive: true,
                          compact: false,
                          fullBodyFraming: true,
                        ),
                        // Cheap cinematic colour spill matching the yellow/blue
                        // background. It gives the model a two-tone light feel
                        // without adding extra realtime 3D lights or bloom.
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1.0 + wave2 * .18, -.15),
                                end: Alignment(1.0 - wave * .12, .15),
                                colors: [
                                  const Color(0x283A8DFF),
                                  Colors.transparent,
                                  const Color(0x30FFD23D),
                                ],
                                stops: const [0, .52, 1],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GameStartButton extends StatefulWidget {
  const _GameStartButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  State<_GameStartButton> createState() => _GameStartButtonState();
}

class _GameStartButtonState extends State<_GameStartButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => pressed = true),
      onTapCancel: widget.onTap == null ? null : () => setState(() => pressed = false),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => pressed = false);
              widget.onTap?.call();
            },
      child: AnimatedScale(
        scale: pressed ? .96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 220,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE46B), Color(0xFFFFC400), Color(0xFFE89000)],
            ),
            border: Border.all(color: const Color(0xFFFFF2A5), width: 1.6),
            boxShadow: [
              const BoxShadow(color: Color(0xFF5B3300), offset: Offset(0, 7), blurRadius: 0),
              BoxShadow(
                color: const Color(0xFFFFC400).withOpacity(.34),
                blurRadius: 26,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CustomPaint(painter: _GameButtonStripePainter()),
                ),
              ),
              if (widget.loading)
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF17120A)),
                )
              else
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Color(0xFF17120A), size: 31),
                    SizedBox(width: 5),
                    Text(
                      'ابدأ',
                      style: TextStyle(
                        color: Color(0xFF17120A),
                        fontSize: 25,
                        height: 1,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameButtonStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x12FFFFFF);
    const stripe = 24.0;
    for (double x = -size.height; x < size.width + size.height; x += stripe * 2) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + stripe, size.height)
        ..lineTo(x + stripe + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GameMiniButton extends StatelessWidget {
  const _GameMiniButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3D475B), Color(0xFF171C27)],
            ),
            border: Border.all(color: const Color(0x55FFFFFF)),
            boxShadow: const [
              BoxShadow(color: Color(0xB0000000), offset: Offset(0, 5), blurRadius: 0),
            ],
          ),
          child: Icon(icon, color: const Color(0xFFFFD33D), size: 23),
        ),
      ),
    );
  }
}

class _GameIdentityTag extends StatelessWidget {
  const _GameIdentityTag({required this.name, required this.online});

  final String name;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xCC111722),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 7))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_rounded, color: Color(0xFFFFD33D), size: 19),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameModeTag extends StatelessWidget {
  const _GameModeTag({required this.online, required this.onTap});

  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xCC111722),
          border: Border.all(color: const Color(0x33FFFFFF)),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 7))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              online ? Icons.public_rounded : Icons.smart_toy_rounded,
              color: const Color(0xFFFFD33D),
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              online ? 'أونلاين' : '3 بوتات',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCircleButton extends StatefulWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => pressed = true),
      onTapCancel: () => setState(() => pressed = false),
      onTapUp: (_) {
        setState(() => pressed = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, pressed ? 4 : 0, 0),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.highlighted
                  ? const [Color(0xFFFFE36B), Color(0xFFFFBA00)]
                  : const [Color(0xFF414B5D), Color(0xFF171C26)],
            ),
            border: Border.all(
              color: widget.highlighted ? const Color(0xFFFFF2AE) : const Color(0x55FFFFFF),
              width: 1.3,
            ),
            boxShadow: pressed
                ? const []
                : [
                    BoxShadow(
                      color: widget.highlighted ? const Color(0xFF7A4800) : const Color(0xAA000000),
                      offset: const Offset(0, 5),
                      blurRadius: 0,
                    ),
                    if (widget.highlighted)
                      BoxShadow(
                        color: const Color(0xFFFFC400).withOpacity(.22),
                        blurRadius: 16,
                      ),
                  ],
          ),
          child: Icon(
            widget.icon,
            color: widget.highlighted ? const Color(0xFF17120A) : Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _MiniPillButton extends StatelessWidget {
  const _MiniPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(.12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFFFD24A)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _HowToItem extends StatelessWidget {
  const _HowToItem({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFFFFD24A), Color(0xFFFF9E2C)]),
            ),
            child: Text(
              '$index',
              style: const TextStyle(color: Colors.black, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 14.2, height: 1.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
