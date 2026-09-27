import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/guess_time_models.dart';
import '../../models/killer_killed_avatar.dart';
import '../../services/guess_time/guess_time_online_service.dart';
import '../../services/killer_killed/killer_killed_avatar_store.dart';
import '../../services/player_name_store.dart';
import '../killer_killed/killer_killed_avatar_customizer.dart';
import '../killer_killed/killer_killed_avatar_preview.dart';
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
  KillerKilledAvatar avatar = KillerKilledAvatar.defaultAvatar;
  final TextEditingController nameController = TextEditingController(text: 'محمد');
  final TextEditingController codeController = TextEditingController();
  bool busy = false;

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

    final players = <GuessTimePlayer>[
      GuessTimePlayer(
        id: 'local_0',
        name: localName,
        colorIndex: 0,
        isBot: false,
        isLocal: true,
        avatar: avatar,
      ),
    ];

    for (var i = 1; i < 4; i++) {
      players.add(
        GuessTimePlayer(
          id: 'bot_$i',
          name: 'بوت $i',
          colorIndex: i,
          isBot: true,
          isLocal: false,
          avatar: KillerKilledAvatar.random(
            math.Random(DateTime.now().millisecondsSinceEpoch.hashCode + i * 91),
          ),
        ),
      );
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
      barrierColor: Colors.black.withOpacity(.55),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(.18)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xEE171F30), Color(0xF5101520)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'طريقة اللعب',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...const [
                    _HowToItem(index: 1, text: 'شاهد الوقت المطلوب على الشاشة الكبيرة واحفظه جيدًا.'),
                    _HowToItem(index: 2, text: 'عند اختفاء العداد، اضغط زرّك في اللحظة التي تعتقد أنها مطابقة.'),
                    _HowToItem(index: 3, text: 'الأقرب إلى الوقت المطلوب يفوز بالجولة.'),
                    _HowToItem(index: 4, text: 'بعد خمس جولات يتم إقصاء الأضعف وتستمر اللعبة حتى يبقى فائز واحد.'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _GuessTimeBackdrop(),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(.24),
                    Colors.transparent,
                    Colors.black.withOpacity(.18),
                    Colors.black.withOpacity(.68),
                  ],
                  stops: const [0, .28, .58, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, .45),
                    radius: .74,
                    colors: [
                      const Color(0xFFFFD33D).withOpacity(.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1380 : 820),
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        // The avatar arena intentionally starts high and is allowed
                        // to paint behind the title/HUD. This keeps tall hats/hair
                        // from being cut by an invisible top boundary.
                        Positioned.fill(
                          top: wide ? 30 : 20,
                          bottom: wide ? 88 : 104,
                          child: _avatarArena(expanded: wide),
                        ),
                        Positioned(
                          top: wide ? 72 : 64,
                          left: 0,
                          right: 0,
                          child: _gameTitle(wide: wide),
                        ),
                        Positioned(
                          top: 8,
                          left: 16,
                          right: 16,
                          child: _topBar(),
                        ),
                        Positioned(
                          bottom: wide ? 22 : 18,
                          left: 18,
                          right: 18,
                          child: _bottomGameControls(wide: wide),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        _GlassCircleButton(
          icon: Icons.arrow_forward_rounded,
          onTap: () => Navigator.pop(context),
        ),
        const Spacer(),
        _GlassCircleButton(
          icon: Icons.help_outline_rounded,
          onTap: _showHowToPlay,
        ),
        const SizedBox(width: 10),
        _GlassCircleButton(
          icon: Icons.groups_rounded,
          highlighted: true,
          onTap: _showPlaySettings,
        ),
      ],
    );
  }

  Widget _gameTitle({required bool wide}) {
    return IgnorePointer(
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFD64A)],
            ).createShader(rect),
            child: Text(
              'خمن الوقت',
              style: TextStyle(
                color: Colors.white,
                fontSize: wide ? 42 : 30,
                height: .9,
                shadows: const [
                  Shadow(color: Color(0xCC000000), blurRadius: 18, offset: Offset(0, 4)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: wide ? 112 : 84,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [Colors.transparent, Color(0xFFFFD33D), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarArena({required bool expanded}) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          bottom: expanded ? 18 : 14,
          child: IgnorePointer(
            child: Container(
              width: expanded ? 610 : 390,
              height: expanded ? 138 : 94,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(.30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD33D).withOpacity(.17),
                    blurRadius: expanded ? 70 : 48,
                    spreadRadius: expanded ? 18 : 10,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          bottom: expanded ? -8 : -4,
          child: _CinematicAvatarStage(
            avatar: avatar,
            expanded: expanded,
          ),
        ),
        Positioned(
          bottom: expanded ? 30 : 24,
          right: expanded ? 86 : 22,
          child: _GameMiniButton(
            icon: Icons.checkroom_rounded,
            tooltip: 'تعديل الشخصية',
            onTap: _customizeAvatar,
          ),
        ),
      ],
    );
  }

  Widget _bottomGameControls({required bool wide}) {
    final name = nameController.text.trim().isEmpty ? 'اللاعب' : nameController.text.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (wide)
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: _GameIdentityTag(
                name: name,
                online: mode == _GuessEntryMode.online,
              ),
            ),
          )
        else
          const Spacer(),
        _GameStartButton(
          loading: busy,
          onTap: busy ? null : _handlePrimaryStart,
        ),
        if (wide)
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.bottomEnd,
              child: _GameModeTag(
                online: mode == _GuessEntryMode.online,
                onTap: _showPlaySettings,
              ),
            ),
          )
        else
          const Spacer(),
      ],
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

class _CinematicAvatarStageState extends State<_CinematicAvatarStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
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

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeInOutSine.transform(_controller.value);
            final breatheY = lerpDouble(7, -7, t) ?? 0;
            final breatheScale = lerpDouble(.993, 1.012, t) ?? 1;
            final glowScale = lerpDouble(.94, 1.07, t) ?? 1;

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
                  bottom: widget.expanded ? -18 : -22,
                  child: Transform.translate(
                    offset: Offset(0, breatheY),
                    child: Transform.scale(
                      scale: breatheScale,
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: stageWidth,
                        height: stageHeight,
                        child: KillerKilledAvatarPreview(
                          avatar: widget.avatar,
                          interactive: true,
                          compact: false,
                          fullBodyFraming: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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
