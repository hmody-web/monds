import 'package:flutter/material.dart';
import '../core/mundas_colors.dart';
import '../core/nav.dart';
import '../widgets/dot_background.dart';
import 'drawing_game_home_screen.dart';
import 'heads_up/heads_up_setup_screen.dart';
import 'killer_killed/killer_killed_home_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 390;

    return Scaffold(
      body: SafeArea(
        child: DotBackground(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, compact ? 16 : 22, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: MundasColors.ink, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: MundasColors.ink,
                                    offset: Offset(0, 4),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.asset(
                                  'assets/images/app_icon.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 13),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('مندس', style: TextStyle(fontSize: 27, height: 1)),
                                  SizedBox(height: 5),
                                  Text(
                                    'ألعاب خفيفة تجمعكم في مكان واحد',
                                    style: TextStyle(
                                      color: MundasColors.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                              decoration: BoxDecoration(
                                color: MundasColors.primaryLight,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: MundasColors.primary, width: 1.3),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videogame_asset_rounded, size: 17, color: MundasColors.primaryDark),
                                  SizedBox(width: 5),
                                  Text('3 ألعاب', style: TextStyle(fontSize: 12.5, color: MundasColors.primaryDark)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 26 : 34),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: .88, end: 1),
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) => Opacity(
                            opacity: value.clamp(0.0, 1.0).toDouble(),
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 26),
                              child: child,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                decoration: BoxDecoration(
                                  color: MundasColors.gold.withOpacity(.32),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('جاهزون؟ 🎉', style: TextStyle(fontSize: 13)),
                              ),
                              const SizedBox(height: 11),
                              Text(
                                'ماذا نلعب\nاليوم؟',
                                style: TextStyle(
                                  fontSize: compact ? 42 : 48,
                                  height: .93,
                                  color: MundasColors.ink,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'اختر لعبة وابدأ فورًا. لا تسجيل، ولا إعدادات معقدة.',
                                style: TextStyle(
                                  color: MundasColors.muted,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    _GameCard(
                      title: 'خمن من الرسم',
                      subtitle: 'ارسموا الكلمة واكشفوا المندس قبل أن يخدع المجموعة.',
                      badge: 'مندس',
                      badgeIcon: Icons.visibility_rounded,
                      color: const Color(0xFF1A9C8F),
                      accent: MundasColors.gold,
                      icon: Icons.draw_rounded,
                      artworkAsset: 'assets/images/draw_guess_card.webp',
                      indexText: '01',
                      onTap: () => Navigator.push(
                        context,
                        mundasRoute(const DrawingGameHomeScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _GameCard(
                      title: 'خمن اللي براسي',
                      subtitle: 'ضع الهاتف على رأسك، ودع من أمامك يساعدك على تخمين الكلمة.',
                      badge: 'من دون عدد محدد',
                      badgeIcon: Icons.all_inclusive_rounded,
                      color: const Color(0xFF168F83),
                      accent: const Color(0xFFFFC857),
                      icon: Icons.phone_android_rounded,
                      artworkAsset: 'assets/images/heads_up_card.webp',
                      indexText: '02',
                      onTap: () => Navigator.push(
                        context,
                        mundasRoute(const HeadsUpSetupScreen()),
                      ),
                    ),

                    const SizedBox(height: 20),
                    _GameCard(
                      title: 'قاتل ومقتول',
                      subtitle: 'تحرّك قبل انتهاء الوقت، اختفِ عن خصومك، ثم اكشفوا مواقعكم وابدأوا إطلاق النار بالتسلسل.',
                      badge: '3D • فردي وأصدقاء',
                      badgeIcon: Icons.my_location_rounded,
                      color: const Color(0xFF111827),
                      accent: const Color(0xFF2F6DFF),
                      icon: Icons.gps_fixed_rounded,
                      artworkAsset: 'assets/images/killer_killed_card.webp',
                      indexText: '03',
                      onTap: () => Navigator.push(
                        context,
                        mundasRoute(const KillerKilledHomeScreen()),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.72),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: MundasColors.line),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 18, color: MundasColors.coral),
                          SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'ثلاث ألعاب مختلفة... والمزيد قادم',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: MundasColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _GameCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData badgeIcon;
  final Color color;
  final Color accent;
  final IconData icon;
  final String? artworkAsset;
  final String indexText;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeIcon,
    required this.color,
    required this.accent,
    required this.icon,
    this.artworkAsset,
    required this.indexText,
    required this.onTap,
  });

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
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
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..translate(0.0, pressed ? 5.0 : 0.0)
          ..scale(pressed ? .988 : 1.0),
        height: widget.artworkAsset == null ? null : 236,
        constraints: widget.artworkAsset == null
            ? const BoxConstraints(minHeight: 222)
            : null,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(31),
          border: Border.all(color: MundasColors.ink, width: 2.3),
          boxShadow: pressed
              ? const []
              : const [
                  BoxShadow(
                    color: MundasColors.ink,
                    offset: Offset(0, 8),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned(
                left: -38,
                top: -54,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(.08),
                    border: Border.all(
                      color: Colors.white.withOpacity(.12),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -32,
                bottom: -46,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.accent.withOpacity(.16),
                  ),
                ),
              ),
              if (widget.artworkAsset != null) ...[
                Positioned(
                  left: -10,
                  bottom: -9,
                  top: 23,
                  width: 188,
                  child: IgnorePointer(
                    child: Image.asset(
                      widget.artworkAsset!,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomLeft,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          stops: const [.28, .62, 1],
                          colors: [
                            widget.color,
                            widget.color.withOpacity(.94),
                            widget.color.withOpacity(.08),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Positioned(
                left: 18,
                top: 16,
                child: Text(
                  widget.indexText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.22),
                    fontSize: 26,
                    height: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(21, 21, 21, 20),
                child: widget.artworkAsset == null
                    ? _buildClassicContent()
                    : _buildArtworkContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassicContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: widget.accent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: MundasColors.ink, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: MundasColors.ink,
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Icon(widget.icon, size: 38, color: MundasColors.ink),
            ),
            const Spacer(),
            _badge(),
          ],
        ),
        const SizedBox(height: 21),
        Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(.88),
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        _startButton(),
      ],
    );
  }

  Widget _buildArtworkContent() {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 58,
          child: SizedBox(
            height: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _badge(),
                ),
                const Spacer(),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.9),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                _startButton(),
              ],
            ),
          ),
        ),
        const Expanded(
          flex: 42,
          child: SizedBox(),
        ),
      ],
    );
  }

  Widget _badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.badgeIcon, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text(
            widget.badge,
            style: const TextStyle(color: Colors.white, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _startButton() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ابدأ اللعب',
                style: TextStyle(color: widget.color, fontSize: 13.5),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_back_rounded, size: 18, color: widget.color),
            ],
          ),
        ),
      ],
    );
  }
}
