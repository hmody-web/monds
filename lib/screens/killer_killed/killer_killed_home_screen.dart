import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/killer_killed_avatar.dart';
import '../../services/killer_killed/killer_killed_avatar_store.dart';
import '../../services/killer_killed/killer_killed_package_service.dart';
import '../../services/player_name_store.dart';
import '../../widgets/arcade_game_shell.dart';
import 'killer_killed_arena_screen.dart';

class KillerKilledHomeScreen extends StatefulWidget {
  const KillerKilledHomeScreen({
    super.key,
    this.initialOnline = false,
  });

  final bool initialOnline;

  @override
  State<KillerKilledHomeScreen> createState() => _KillerKilledHomeScreenState();
}

class _KillerKilledHomeScreenState extends State<KillerKilledHomeScreen> {
  final KillerKilledPackageService _package = KillerKilledPackageService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  KillerKilledAvatar avatar = KillerKilledAvatar.defaultAvatar;
  int botCount = 5;
  bool _autoStartWhenReady = false;
  bool _openingArena = false;

  bool get _online => widget.initialOnline;

  @override
  void initState() {
    super.initState();
    _package.addListener(_onPackageChanged);
    _package.initialize();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    final savedAvatar = await KillerKilledAvatarStore.load();
    var name = await PlayerNameStore.loadOnlineName();
    if (name.isEmpty) {
      final names = await PlayerNameStore.loadLocalNames();
      if (names.isNotEmpty) name = names.first.trim();
    }
    if (!mounted) return;
    setState(() {
      avatar = savedAvatar;
      _nameController.text = name.isEmpty ? 'اللاعب' : name;
    });
  }

  void _onPackageChanged() {
    if (!mounted) return;
    setState(() {});
    if (_autoStartWhenReady &&
        _package.status == KillerPackageStatus.installed &&
        !_openingArena) {
      _autoStartWhenReady = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openArena();
      });
    }
  }

  @override
  void dispose() {
    _package.removeListener(_onPackageChanged);
    _package.dispose();
    _nameController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _openArena() async {
    if (_openingArena) return;
    final name = _nameController.text.trim().isEmpty
        ? 'اللاعب'
        : _nameController.text.trim();
    await PlayerNameStore.saveOnlineName(name);
    if (!mounted) return;
    _openingArena = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KillerKilledArenaScreen(
          botCount: botCount,
          playerAvatar: avatar,
          playerName: name,
        ),
      ),
    );
    _openingArena = false;
  }

  Future<void> _startSolo() async {
    FocusScope.of(context).unfocus();
    if (kIsWeb || _package.status == KillerPackageStatus.installed) {
      await _openArena();
      return;
    }
    _autoStartWhenReady = true;
    await _package.startOrResume();
  }

  void _openOnlineRoom({required bool create}) {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _notice('اكتب اسم اللاعب');
      return;
    }
    if (!create && _roomController.text.trim().isEmpty) {
      _notice('اكتب رمز الغرفة');
      return;
    }
    // واجهة قاتل ومقتول الجماعية منفصلة الآن عن الفردي. محرك الغرف الخاص
    // بهذه اللعبة غير موجود في المشروع الحالي، لذلك لا نربطه بخدمة لعبة أخرى.
    _notice(create ? 'إنشاء غرفة قاتل ومقتول غير مربوط بالخادم بعد.' : 'دخول غرفة قاتل ومقتول غير مربوط بالخادم بعد.');
  }

  void _notice(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text, textAlign: TextAlign.center), behavior: SnackBarBehavior.floating));
  }

  Future<void> _showDetails() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.72),
      builder: (_) => const ArcadeDetailsDialog(
        title: 'تفاصيل قاتل ومقتول',
        child: Text(
          'تحرّك خلال الوقت المحدد، تمركز جيدًا، وابقَ آخر لاعب في الجولة.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 15, height: 1.7, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String _startLabel() {
    final status = _package.status;
    if (_autoStartWhenReady ||
        status == KillerPackageStatus.downloading ||
        status == KillerPackageStatus.checking) {
      final pct = (_package.progress * 100).clamp(0, 100).round();
      return pct > 0 ? 'يرجى الانتظار $pct%' : 'يرجى الانتظار';
    }
    return 'ابدأ';
  }

  @override
  Widget build(BuildContext context) {
    return ArcadeGameShell(
      title: 'قاتل ومقتول',
      onDetails: _showDetails,
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ArcadePanel(
              padding: const EdgeInsets.all(20),
              child: _online ? _onlineContent() : _soloContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _soloContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'جاهز للمعركة',
          style: TextStyle(
            fontFamily: 'PCB',
            color: Color(0xFFFFF1B0),
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        ArcadeTextField(
          controller: _nameController,
          hint: 'الاسم داخل اللعبة',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF050D15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF31566E), width: 2),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: botCount > 1 ? () => setState(() => botCount--) : null,
                icon: const Icon(Icons.remove_circle_rounded),
                color: const Color(0xFFFFB62F),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('عدد البوتات', style: TextStyle(color: Color(0xFF91AABA), fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      '$botCount',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: botCount < 9 ? () => setState(() => botCount++) : null,
                icon: const Icon(Icons.add_circle_rounded),
                color: const Color(0xFFFFB62F),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ArcadePrimaryButton(
          label: _startLabel(),
          busy: _autoStartWhenReady || _package.status == KillerPackageStatus.downloading,
          onPressed: _startSolo,
        ),
      ],
    );
  }

  Widget _onlineContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'اللعب مع صديق',
          style: TextStyle(
            fontFamily: 'PCB',
            color: Color(0xFFFFF1B0),
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        ArcadeTextField(
          controller: _nameController,
          hint: 'اسم اللاعب',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 12),
        ArcadeTextField(
          controller: _roomController,
          hint: 'رمز الغرفة',
          icon: Icons.key_rounded,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: ArcadePrimaryButton(
                label: 'إنشاء غرفة',
                icon: Icons.add_circle_outline_rounded,
                onPressed: () => _openOnlineRoom(create: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ArcadePrimaryButton(
                label: 'دخول الغرفة',
                icon: Icons.login_rounded,
                onPressed: () => _openOnlineRoom(create: false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
