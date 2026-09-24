import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/killer_killed_config.dart';
import '../../core/mundas_colors.dart';
import '../../models/killer_killed_avatar.dart';
import '../../services/killer_killed/killer_killed_avatar_store.dart';
import '../../widgets/dot_background.dart';
import 'package:mundas/services/killer_killed/killer_killed_package_service.dart';
import '../../services/player_name_store.dart';
import 'killer_killed_arena_screen.dart';
import 'killer_killed_avatar_customizer.dart';
import 'killer_killed_avatar_preview.dart';

enum _PlayMode { solo, friends }

class KillerKilledHomeScreen extends StatefulWidget {
  const KillerKilledHomeScreen({super.key});

  @override
  State<KillerKilledHomeScreen> createState() => _KillerKilledHomeScreenState();
}

class _KillerKilledHomeScreenState extends State<KillerKilledHomeScreen> {
  _PlayMode mode = _PlayMode.solo;
  int botCount = 5;
  KillerKilledAvatar avatar = KillerKilledAvatar.defaultAvatar;
  String playerName = 'محمد';
  final KillerKilledPackageService _package = KillerKilledPackageService();

  @override
  void initState() {
    super.initState();
    _package.addListener(_onPackageChanged);
    _package.initialize();
    _loadPlayerName();
    _loadAvatar();
  }


  Future<void> _loadPlayerName() async {
    var name = await PlayerNameStore.loadOnlineName();
    if (name.isEmpty) {
      final localNames = await PlayerNameStore.loadLocalNames();
      if (localNames.isNotEmpty) name = localNames.first.trim();
    }
    if (mounted && name.isNotEmpty) setState(() => playerName = name);
  }

  Future<void> _loadAvatar() async {
    final saved = await KillerKilledAvatarStore.load();
    if (mounted) setState(() => avatar = saved);
  }

  Future<void> _openAvatarCustomizer() async {
    final result = await Navigator.push<KillerKilledAvatar>(
      context,
      MaterialPageRoute(
        builder: (_) => KillerKilledAvatarCustomizer(initialAvatar: avatar),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => avatar = result);
  }

  void _onPackageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _package.removeListener(_onPackageChanged);
    _package.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DotBackground(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _topBar(context)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        children: [
                          _hero(),
                          const SizedBox(height: 18),
                          _rulesStrip(),
                          const SizedBox(height: 18),
                          _modeSelector(),
                          const SizedBox(height: 16),
                          if (mode == _PlayMode.solo) _soloOptions() else _friendsOptions(),
                          const SizedBox(height: 16),
                          _identityCard(),
                          const SizedBox(height: 16),
                          _gamePackageCard(),
                          const SizedBox(height: 20),
                          _primaryButton(),
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

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MundasColors.ink, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: MundasColors.ink,
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  KillerKilledConfig.gameName,
                  style: TextStyle(fontSize: 23, height: 1.05),
                ),
                SizedBox(height: 3),
                Text(
                  'اختفِ، تمركز، ثم يأتي دور الرصاصة',
                  style: TextStyle(color: MundasColors.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE9EFFF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFB8C9FF)),
            ),
            child: const Text(
              '3D',
              style: TextStyle(color: Color(0xFF2457D6), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      height: 276,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: MundasColors.ink, width: 2.2),
        boxShadow: const [
          BoxShadow(
            color: MundasColors.ink,
            offset: Offset(0, 7),
            blurRadius: 0,
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF0A1020),
            Color(0xFF111D38),
            Color(0xFF0C1325),
          ],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -40,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2F6DFF).withOpacity(.16),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -22,
            width: 225,
            height: 268,
            child: Image.asset(
              'assets/images/killer_killed_card.webp',
              fit: BoxFit.contain,
              alignment: Alignment.bottomLeft,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      const Color(0xFF0A1020),
                      const Color(0xFF0A1020).withOpacity(.90),
                      Colors.transparent,
                    ],
                    stops: const [.16, .55, 1],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  flex: 58,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(.22)),
                        ),
                        child: const Text(
                          'Neo‑Noir Rooftop',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'قاتل ومقتول',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          height: .95,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        '8 ثوانٍ للحركة بعيدًا عن أعين الجميع، ثم يتجمد الكل وتظهر المواقع.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.82),
                          fontSize: 12.3,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(flex: 42, child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rulesStrip() {
    const items = [
      (Icons.timer_rounded, '8 ثوانٍ', 'حركة مخفية'),
      (Icons.favorite_rounded, '3 قلوب', 'إقصاء تدريجي'),
      (Icons.gps_fixed_rounded, 'بالتسلسل', 'إطلاق تلقائي'),
    ];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.82),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MundasColors.line),
              ),
              child: Column(
                children: [
                  Icon(items[i].$1, size: 20, color: const Color(0xFF2457D6)),
                  const SizedBox(height: 5),
                  Text(items[i].$2, style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text(
                    items[i].$3,
                    style: const TextStyle(fontSize: 9.5, color: MundasColors.muted),
                  ),
                ],
              ),
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _modeSelector() {
    return _section(
      title: 'طريقة اللعب',
      child: Row(
        children: [
          Expanded(
            child: _modeTile(
              selected: mode == _PlayMode.solo,
              icon: Icons.smart_toy_rounded,
              title: 'فردي',
              subtitle: 'أنت ضد البوتات',
              onTap: () => setState(() => mode = _PlayMode.solo),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _modeTile(
              selected: mode == _PlayMode.friends,
              icon: Icons.groups_2_rounded,
              title: 'مع الأصدقاء',
              subtitle: 'غرفة خاصة',
              onTap: () => setState(() => mode = _PlayMode.friends),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTile({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF0FF) : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF2F6DFF) : MundasColors.line,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF2F6DFF) : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : MundasColors.ink,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10.5, color: MundasColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _soloOptions() {
    return _section(
      title: 'عدد البوتات',
      trailing: Text(
        '$botCount بوت',
        style: const TextStyle(color: Color(0xFF2457D6), fontSize: 12.5),
      ),
      child: Column(
        children: [
          Slider(
            value: botCount.toDouble(),
            min: KillerKilledConfig.minBots.toDouble(),
            max: KillerKilledConfig.maxBots.toDouble(),
            divisions: KillerKilledConfig.maxBots - KillerKilledConfig.minBots,
            label: '$botCount',
            onChanged: (value) => setState(() => botCount = value.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('3', style: TextStyle(fontSize: 10.5, color: MundasColors.muted)),
              Text('8', style: TextStyle(fontSize: 10.5, color: MundasColors.muted)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'البوتات تتحرك بشكل غير متوقع، وتصويبها يخطئ ويصيب بنسب متفاوتة.',
            style: TextStyle(fontSize: 10.5, color: MundasColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _friendsOptions() {
    return _section(
      title: 'الغرفة',
      child: Row(
        children: [
          Expanded(
            child: _smallAction(
              icon: Icons.add_circle_outline_rounded,
              label: 'إنشاء غرفة',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _smallAction(
              icon: Icons.key_rounded,
              label: 'دخول بكود',
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallAction({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MundasColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: const Color(0xFF2457D6)),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _identityCard() {
    return _section(
      title: 'شخصيتي',
      trailing: TextButton.icon(
        onPressed: _openAvatarCustomizer,
        icon: const Icon(Icons.tune_rounded, size: 17),
        label: const Text('تخصيص'),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _openAvatarCustomizer,
            child: Container(
              height: 168,
              decoration: BoxDecoration(
                color: const Color(0xFF07100F),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF219587).withOpacity(.55)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Expanded(
                    flex: 43,
                    child: KillerKilledAvatarPreview(
                      avatar: avatar,
                      compact: true,
                      interactive: false,
                    ),
                  ),
                  Expanded(
                    flex: 57,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            playerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'اختَر الشعر والقبعة والنظارات والملابس والبنطلون والأحذية والإكسسوارات كما تريد.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10.2,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 11),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF219587).withOpacity(.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF5ED9C7).withOpacity(.45),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.smart_toy_rounded,
                                  color: Color(0xFF7FE6D7),
                                  size: 15,
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'البوتات تغيّر سكناتها عشوائيًا بكل مباراة',
                                    style: TextStyle(
                                      color: Color(0xFFC7FFF7),
                                      fontSize: 9.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.favorite_rounded, color: Color(0xFFE84A5F), size: 18),
              SizedBox(width: 4),
              Icon(Icons.favorite_rounded, color: Color(0xFFE84A5F), size: 18),
              SizedBox(width: 4),
              Icon(Icons.favorite_rounded, color: Color(0xFFE84A5F), size: 18),
              Spacer(),
              Text(
                'اضغط على الشخصية لتعديل السكن',
                style: TextStyle(fontSize: 9.7, color: MundasColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gamePackageCard() {
    final status = _package.status;
    final progress = _package.progress;
    final total = _package.totalBytes;
    final downloaded = _package.downloadedBytes;

    String bytes(int value) {
      if (value >= 1024 * 1024 * 1024) return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      if (value >= 1024 * 1024) return '${(value / (1024 * 1024)).toStringAsFixed(0)} MB';
      return '${(value / 1024).toStringAsFixed(0)} KB';
    }

    final installed = status == KillerPackageStatus.installed;
    final downloading = status == KillerPackageStatus.downloading;
    final paused = status == KillerPackageStatus.paused;

    return _section(
      title: 'ملفات اللعبة',
      trailing: installed
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 16, color: Color(0xFF14B87A)),
                SizedBox(width: 4),
                Text('جاهزة', style: TextStyle(color: Color(0xFF14B87A), fontSize: 11.5)),
              ],
            )
          : null,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: MundasColors.line),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: installed ? const Color(0xFFE8F8F2) : const Color(0xFFEAF0FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    installed ? Icons.offline_pin_rounded : Icons.cloud_download_rounded,
                    color: installed ? const Color(0xFF14B87A) : const Color(0xFF2457D6),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        installed ? 'اللعبة محفوظة على الجهاز' : 'حزمة 3D منفصلة',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        kIsWeb
                            ? 'Chrome للمعاينة فقط؛ التنزيل الحقيقي يعمل على iPhone وAndroid.'
                            : installed
                                ? 'يمكن تشغيل اللعب الفردي لاحقًا حتى بدون إنترنت.'
                                : 'يمكن إيقاف التنزيل واستئنافه من نفس النقطة.',
                        style: const TextStyle(fontSize: 10.2, color: MundasColors.muted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (downloading || paused) ...[
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: total == null ? null : progress,
                  backgroundColor: const Color(0xFFE4E7EC),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF2F6DFF)),
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Text(
                    total == null ? bytes(downloaded) : '${bytes(downloaded)} / ${bytes(total)}',
                    style: const TextStyle(fontSize: 10, color: MundasColors.muted),
                  ),
                  const Spacer(),
                  if (downloading)
                    TextButton.icon(
                      onPressed: _package.pause,
                      icon: const Icon(Icons.pause_rounded, size: 17),
                      label: const Text('إيقاف مؤقت'),
                    )
                  else
                    TextButton.icon(
                      onPressed: _package.startOrResume,
                      icon: const Icon(Icons.play_arrow_rounded, size: 17),
                      label: const Text('استئناف'),
                    ),
                  TextButton(
                    onPressed: _package.cancel,
                    child: const Text('إلغاء'),
                  ),
                ],
              ),
            ] else if (!installed && status != KillerPackageStatus.checking) ...[
              const SizedBox(height: 11),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: kIsWeb ? null : _package.startOrResume,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(status == KillerPackageStatus.error ? 'إعادة محاولة التنزيل' : 'تنزيل ملفات اللعبة'),
                ),
              ),
            ],
            if (_package.errorMessage != null && _package.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _package.errorMessage!,
                style: const TextStyle(fontSize: 9.5, color: Color(0xFFE84A5F), height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _primaryButton() {
    final installed = _package.status == KillerPackageStatus.installed;
    final canPreview = kIsWeb;
    final canPlay = mode == _PlayMode.solo && (installed || canPreview);

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: mode == _PlayMode.friends
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الغرف الجماعية ستُربط بالخادم بعد تثبيت محرك الجولة الفردية.')),
                );
              }
            : canPlay
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KillerKilledArenaScreen(
                          botCount: botCount,
                          playerAvatar: avatar,
                          playerName: playerName,
                        ),
                      ),
                    );
                  }
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('نزّل ملفات اللعبة أولاً، وبعدها تشتغل أوفلاين.')),
                    );
                  },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
            side: const BorderSide(color: MundasColors.ink, width: 2),
          ),
        ),
        child: Text(
          mode == _PlayMode.solo
              ? (canPreview ? 'تشغيل نموذج اللعب ضد $botCount بوتات' : 'ابدأ ضد $botCount بوتات')
              : 'متابعة إلى الغرفة',
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.88),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: MundasColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 14.5)),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}
