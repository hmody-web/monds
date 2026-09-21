import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/local_game_session.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_scaffold.dart';
import 'drawing_screen.dart';

class RoleRevealScreen extends StatefulWidget {
  final LocalGameSession session;
  const RoleRevealScreen({super.key, required this.session});

  @override
  State<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<RoleRevealScreen> with SingleTickerProviderStateMixin {
  Timer? _holdTimer;
  bool _revealed = false;
  bool _seen = false;
  double _holdProgress = 0;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    _holdTimer?.cancel();
    setState(() => _holdProgress = 1);
    _holdTimer = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _revealed = true;
        _seen = true;
      });
    });
  }

  void _hide() {
    _holdTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _holdProgress = 0;
      _revealed = false;
    });
  }

  void _next() {
    if (!widget.session.isLastReveal) {
      widget.session.nextReveal();
      setState(() {
        _revealed = false;
        _seen = false;
        _holdProgress = 0;
      });
    } else {
      Navigator.pushReplacement(context, mundasRoute(DrawingScreen(session: widget.session)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.session.currentRevealPlayer;
    final imposter = widget.session.currentRevealIsImposter;
    return MundasScaffold(
      title: 'كشف الدور',
      showBack: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Text('مرر الهاتف إلى', style: TextStyle(fontSize: 16, color: MundasColors.muted.withOpacity(.9))),
                const SizedBox(height: 4),
                Text(p.name, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 8),
                const Text('وخلي البقية ما يشوفون الشاشة 👀', style: TextStyle(color: MundasColors.muted)),
                const SizedBox(height: 30),
                GestureDetector(
                  onTapDown: _down,
                  onTapUp: (_) => _hide(),
                  onTapCancel: _hide,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    height: 330,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _revealed
                          ? (imposter ? MundasColors.coral : MundasColors.primary)
                          : MundasColors.ink,
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: MundasColors.ink, width: 2.5),
                      boxShadow: const [BoxShadow(color: MundasColors.ink, offset: Offset(0, 8), blurRadius: 0)],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, animation) => ScaleTransition(scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack), child: child),
                      child: _revealed
                          ? _RevealedCard(key: const ValueKey('revealed'), imposter: imposter, session: widget.session)
                          : _HiddenCard(key: const ValueKey('hidden'), pulse: _pulse, holdProgress: _holdProgress),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedOpacity(
                  opacity: _seen && !_revealed ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_seen || _revealed,
                    child: SizedBox(
                      width: double.infinity,
                      child: MundasButton(
                        label: widget.session.isLastReveal ? 'ابدأ الرسم' : 'فهمت دوري',
                        icon: Icons.check_rounded,
                        onPressed: _next,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HiddenCard extends StatelessWidget {
  final AnimationController pulse;
  final double holdProgress;
  const _HiddenCard({super.key, required this.pulse, required this.holdProgress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween(begin: .95, end: 1.04).animate(CurvedAnimation(parent: pulse, curve: Curves.easeInOut)),
            child: const Icon(Icons.visibility_off_rounded, size: 64, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text('دورك مخفي', style: TextStyle(color: Colors.white, fontSize: 28)),
          const SizedBox(height: 10),
          const Text('اضغط مطولاً حتى يظهر', style: TextStyle(color: Color(0xFFC9D9D7), fontSize: 15)),
          const SizedBox(height: 22),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: holdProgress),
            duration: const Duration(milliseconds: 420),
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 7,
              borderRadius: BorderRadius.circular(9),
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(MundasColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealedCard extends StatelessWidget {
  final bool imposter;
  final LocalGameSession session;
  const _RevealedCard({super.key, required this.imposter, required this.session});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: imposter
            ? [
                const Text('🕵️', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                const Text('أنت المندس', style: TextStyle(color: Colors.white, fontSize: 36)),
                const SizedBox(height: 10),
                const Text('ما عندك كلمة. راقب الرسم وخليهم ما يكشفوك.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 15, height: 1.45)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(16)),
                  child: Text('تلميح الفئة: ${session.category.nameAr}', style: const TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ]
            : [
                Text(session.category.emoji, style: const TextStyle(fontSize: 58)),
                const SizedBox(height: 12),
                const Text('كلمتك هي', style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 6),
                Text(session.secretWord, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 40)),
                const SizedBox(height: 16),
                const Text('ارسم تلميحاً ذكيّاً بدون ما تعطي الإجابة للمندس.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, height: 1.45)),
              ],
      ),
    );
  }
}
