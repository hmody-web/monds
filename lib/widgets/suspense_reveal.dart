import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/mundas_colors.dart';

class SuspenseReveal extends StatefulWidget {
  final String accusedName;
  final bool isImposter;
  final VoidCallback? onRevealed;

  const SuspenseReveal({
    super.key,
    required this.accusedName,
    required this.isImposter,
    this.onRevealed,
  });

  @override
  State<SuspenseReveal> createState() => _SuspenseRevealState();
}

class _SuspenseRevealState extends State<SuspenseReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _statusTimer;
  Timer? _revealTimer;
  int _stage = 0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    _statusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _stage = 1);
    });

    _revealTimer = Timer(const Duration(milliseconds: 3400), () {
      if (!mounted) return;
      _pulse.stop();
      HapticFeedback.heavyImpact();
      setState(() => _revealed = true);
      widget.onRevealed?.call();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _revealTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_revealed) return _finalReveal();

    final label = _stage == 0 ? 'نراجع الأصوات...' : 'جاري الكشف...';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) {
            final t = _pulse.value;
            final scale = .92 + (t * .13);
            final angle = math.sin(t * math.pi * 2) * .035;
            return Transform.rotate(
              angle: angle,
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Container(
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MundasColors.ink,
              border: Border.all(color: MundasColors.primary, width: 4),
              boxShadow: [
                BoxShadow(
                  color: MundasColors.primary.withOpacity(.28),
                  blurRadius: 30,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.visibility_rounded,
              color: Colors.white,
              size: 58,
            ),
          ),
        ),
        const SizedBox(height: 26),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            label,
            key: ValueKey(label),
            style: const TextStyle(fontSize: 30),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.accusedName,
          style: const TextStyle(
            fontSize: 39,
            color: MundasColors.ink,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 3300),
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 9,
              backgroundColor: MundasColors.line,
              valueColor: AlwaysStoppedAnimation(
                Color.lerp(MundasColors.primary, MundasColors.coral, value)!,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'لحظات... والهوية تنكشف 👀',
          style: TextStyle(color: MundasColors.muted, fontSize: 14),
        ),
      ],
    );
  }

  Widget _finalReveal() {
    final color = widget.isImposter ? MundasColors.coral : MundasColors.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .72, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (_, value, child) => Transform.scale(scale: value, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: MundasColors.ink, width: 2.4),
          boxShadow: const [
            BoxShadow(
              color: MundasColors.ink,
              offset: Offset(0, 8),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              widget.isImposter ? '😈' : '😳',
              style: const TextStyle(fontSize: 78),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isImposter ? 'انكشف المندس!' : 'مو هو المندس!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.accusedName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 43,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.isImposter
                  ? 'أمسكتوه... بس بعد عنده فرصة أخيرة يخمّن الكلمة.'
                  : 'اختياركم كان غلط... المندس الحقيقي بعده بينكم.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
