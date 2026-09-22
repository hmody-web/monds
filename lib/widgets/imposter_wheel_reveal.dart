import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/mundas_colors.dart';

class ImposterWheelReveal extends StatefulWidget {
  final List<String> playerNames;
  final String imposterName;
  final VoidCallback? onFinished;

  const ImposterWheelReveal({
    super.key,
    required this.playerNames,
    required this.imposterName,
    this.onFinished,
  });

  @override
  State<ImposterWheelReveal> createState() => _ImposterWheelRevealState();
}

class _ImposterWheelRevealState extends State<ImposterWheelReveal>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _celebrate;
  late final List<String> _slots;
  late final double _endRotation;
  late final int _targetIndex;
  int _lastTick = -1;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final source = widget.playerNames.isEmpty
        ? <String>[widget.imposterName]
        : widget.playerNames;
    _slots = List<String>.generate(
      math.max(24, source.length * 8),
      (i) => source[i % source.length],
    );
    var targetIndex = _slots.lastIndexOf(widget.imposterName);
    if (targetIndex < 0) targetIndex = _slots.length - 1;
    _targetIndex = targetIndex;
    final step = (math.pi * 2) / _slots.length;
    _endRotation = (math.pi * 2 * 8.0) - (_targetIndex * step);

    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4700),
    )
      ..addListener(_tickHaptic)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          setState(() => _finished = true);
          _celebrate.forward(from: 0);
          widget.onFinished?.call();
        }
      });
    _celebrate = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _spin.forward();
    });
  }

  void _tickHaptic() {
    final step = (math.pi * 2) / _slots.length;
    final tick = (_rotationFor(_spin.value) / step).floor();
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticFeedback.selectionClick();
    }
  }

  double _rotationFor(double t) =>
      _endRotation * Curves.easeOutCubic.transform(t);

  @override
  void dispose() {
    _spin.dispose();
    _celebrate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: Text(
            _finished ? 'المندس هو' : 'جارٍ كشف المندس...',
            key: ValueKey(_finished),
            style: TextStyle(
              fontSize: _finished ? 31 : 23,
              color: _finished ? MundasColors.coral : MundasColors.ink,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, 520.0);
            final diameter = math.max(330.0, width * 1.10);
            final viewportHeight = diameter * .58;
            final radius = diameter * .40;
            final center = Offset(width / 2, diameter / 2 + 26);
            final step = (math.pi * 2) / _slots.length;
            return SizedBox(
              width: width,
              height: viewportHeight,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: (width - diameter) / 2,
                    top: 30,
                    width: diameter,
                    height: diameter,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MundasColors.primaryLight,
                        border: Border.all(
                          color: MundasColors.ink,
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: MundasColors.shadow,
                            offset: Offset(0, 9),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (context, _) {
                      final rotation = _rotationFor(_spin.value);
                      final paintOrder = List<int>.generate(
                        _slots.length,
                        (index) => index,
                      );

                      // العنصر الذي يتوقف عليه السهم يجب أن يُرسم أخيراً
                      // حتى لا يغطيه أي مربع اسم مجاور.
                      if (_finished) {
                        paintOrder.remove(_targetIndex);
                        paintOrder.add(_targetIndex);
                      }

                      return Stack(
                        clipBehavior: Clip.none,
                        children: paintOrder.map((i) {
                          final angle = (i * step) + rotation;
                          final x = center.dx + math.sin(angle) * radius;
                          final y = center.dy - math.cos(angle) * radius;
                          final facing = math.cos(angle);
                          final visible = y > 26 && y < viewportHeight + 36;
                          final scale = (.74 + (.28 * math.max(0.0, facing)))
                              .clamp(.72, 1.05).toDouble();
                          final selected = _finished && i == _targetIndex;
                          return Positioned(
                            left: x - 72,
                            top: y - 25,
                            width: 144,
                            height: 50,
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 120),
                                opacity: visible ? 1 : 0,
                                child: Transform.scale(
                                  scale: selected ? scale * 1.16 : scale,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 260),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? MundasColors.coral
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: selected
                                            ? MundasColors.ink
                                            : MundasColors.line,
                                        width: selected ? 2.5 : 1.4,
                                      ),
                                      boxShadow: selected
                                          ? const [
                                              BoxShadow(
                                                color: MundasColors.shadow,
                                                offset: Offset(0, 5),
                                                blurRadius: 0,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      _slots[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: selected
                                            ? Colors.white
                                            : MundasColors.ink,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  Positioned(
                    top: 2,
                    left: width / 2 - 26,
                    child: AnimatedBuilder(
                      animation: _spin,
                      builder: (context, child) {
                        final bounce = math.sin(_spin.value * math.pi * 30) *
                            (1 - _spin.value) * 5;
                        return Transform.translate(
                          offset: Offset(0, bounce),
                          child: child,
                        );
                      },
                      child: const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 54,
                        color: MundasColors.coral,
                      ),
                    ),
                  ),
                  if (_finished)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _celebrate,
                          builder: (context, _) => CustomPaint(
                            painter: _SparkPainter(_celebrate.value),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          child: _finished
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: .65, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      child: child,
                    ),
                    child: Text(
                      widget.imposterName,
                      style: const TextStyle(
                        color: MundasColors.coral,
                        fontSize: 42,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SparkPainter extends CustomPainter {
  final double t;
  const _SparkPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .32);
    for (var i = 0; i < 18; i++) {
      final angle = (math.pi * 2 / 18) * i;
      final distance = 34 + (112 * Curves.easeOut.transform(t));
      final p = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final paint = Paint()
        ..color = (i.isEven ? MundasColors.coral : MundasColors.primary)
            .withOpacity((1 - t).clamp(0.0, 1.0).toDouble());
      canvas.drawCircle(p, 3.5 + (2 * (1 - t)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) => oldDelegate.t != t;
}
