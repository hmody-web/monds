import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/mundas_colors.dart';

class SecretPullReveal extends StatefulWidget {
  final String secret;
  final Color revealColor;
  final ValueChanged<bool>? onDraggingChanged;
  final VoidCallback? onSeen;

  const SecretPullReveal({
    super.key,
    required this.secret,
    required this.revealColor,
    this.onDraggingChanged,
    this.onSeen,
  });

  @override
  State<SecretPullReveal> createState() => _SecretPullRevealState();
}

class _SecretPullRevealState extends State<SecretPullReveal>
    with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _wordController;

  double _rawPull = 0;
  bool _dragging = false;
  bool _reportedSeen = false;
  bool _thresholdHaptic = false;
  bool _wordStarted = false;
  int _lastResistanceTick = -1;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat(reverse: true);
    _wordController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    _wordController.dispose();
    super.dispose();
  }

  void _start(DragStartDetails _) {
    HapticFeedback.selectionClick();
    setState(() => _dragging = true);
    widget.onDraggingChanged?.call(true);
  }

  void _update(DragUpdateDetails details, double travel) {
    if (travel <= 0) return;
    final next = math.max(0.0, _rawPull - details.delta.dy);
    final progress = (math.min(next, travel) / travel).clamp(0.0, 1.0).toDouble();
    final overPull = math.max(0.0, next - travel);

    if (progress > .14 && !_wordStarted) {
      _wordStarted = true;
      _wordController.forward(from: 0);
    }

    if (progress >= .58 && !_thresholdHaptic) {
      _thresholdHaptic = true;
      HapticFeedback.mediumImpact();
      if (!_reportedSeen) {
        _reportedSeen = true;
        widget.onSeen?.call();
      }
    } else if (progress < .45) {
      _thresholdHaptic = false;
    }

    if (overPull > 0) {
      final tick = (overPull / 34).floor();
      if (tick != _lastResistanceTick) {
        _lastResistanceTick = tick;
        HapticFeedback.selectionClick();
      }
    } else {
      _lastResistanceTick = -1;
    }

    setState(() => _rawPull = next);
  }

  void _release() {
    HapticFeedback.lightImpact();
    setState(() {
      _dragging = false;
      _rawPull = 0;
      _wordStarted = false;
      _lastResistanceTick = -1;
    });
    _wordController.reset();
    widget.onDraggingChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : screenHeight;

        final maxVisibleHeight = math.min(
          availableHeight,
          math.max(120.0, screenHeight * .35),
        );
        final collapsedHeight = math.min(100.0, maxVisibleHeight);
        final travel = math.max(1.0, maxVisibleHeight - collapsedHeight);
        final visiblePull = math.min(_rawPull, travel);
        final progress = (visiblePull / travel).clamp(0.0, 1.0).toDouble();
        final overPull = math.max(0.0, _rawPull - travel);

        final resistance = 1 - math.exp(-overPull / 72.0);
        final microWobble = overPull <= 0
            ? 0.0
            : math.sin(overPull / 7.5) * (1.4 * resistance);
        final pushBack = 10.0 * resistance + microWobble;
        final panelVisibleHeight = collapsedHeight + visiblePull;
        final panelTotalHeight = panelVisibleHeight + safeBottom;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: -safeBottom,
              height: maxVisibleHeight + safeBottom,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: _idleController,
                  builder: (context, child) {
                    // نبض فيزيائي من الحافة السفلية نفسها:
                    // القاع يبقى ثابتاً، والنافذة تتمدد قليلاً للأعلى،
                    // لذلك لا يظهر أي فراغ أبيض ولا نحتاج طبقة خلفية مربعة.
                    final idlePulse = !_dragging && _rawPull == 0
                        ? math.sin(_idleController.value * math.pi)
                        : 0.0;

                    return Transform.translate(
                      offset: Offset(0, pushBack),
                      child: Transform.scale(
                        alignment: Alignment.bottomCenter,
                        scaleX: 1 + (.016 * resistance),
                        scaleY:
                            1 + (.045 * idlePulse) - (.022 * resistance),
                        child: child,
                      ),
                    );
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _start,
                    onVerticalDragUpdate: (d) => _update(d, travel),
                    onVerticalDragEnd: (_) => _release(),
                    onVerticalDragCancel: _release,
                    child: AnimatedContainer(
                      duration: _dragging
                          ? Duration.zero
                          : const Duration(milliseconds: 680),
                      curve: Curves.easeOutBack,
                      height: panelTotalHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          MundasColors.ink,
                          widget.revealColor,
                          Curves.easeOut.transform(progress),
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(34 + (8 * resistance)),
                        ),
                        border: Border.all(
                          color: MundasColors.ink,
                          width: 2.2,
                        ),
                        boxShadow: [
                          const BoxShadow(
                            color: MundasColors.shadow,
                            offset: Offset(0, -6),
                            blurRadius: 0,
                          ),
                          if (resistance > .02)
                            BoxShadow(
                              color: widget.revealColor.withOpacity(
                                .18 + (.22 * resistance),
                              ),
                              blurRadius: 20 + (18 * resistance),
                              spreadRadius: 2 + (4 * resistance),
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32 + (8 * resistance)),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: .09 + (.11 * progress),
                                    child: CustomPaint(
                                      painter: _SecretPatternPainter(
                                        progress: progress,
                                        resistance: resistance,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.topCenter,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 90),
                                  margin: const EdgeInsets.only(top: 12),
                                  width: 58 + (18 * resistance),
                                  height: 6 - (1.2 * resistance),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.82),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                              Center(
                                child: progress < .13
                                    ? _PullInstruction(
                                        pulse: _idleController,
                                      )
                                    : _AnimatedSecretWord(
                                        controller: _wordController,
                                        secret: widget.secret,
                                        progress: progress,
                                        resistance: resistance,
                                      ),
                              ),
                            ],
                          ),
                      ),
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

class _PullInstruction extends StatelessWidget {
  final Animation<double> pulse;
  const _PullInstruction({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = math.sin(pulse.value * math.pi);
        return Transform.translate(
          offset: Offset(0, -2.5 * t),
          child: Opacity(
            opacity: .78 + (.22 * t),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_double_arrow_up_rounded,
                  color: Colors.white,
                  size: 33,
                ),
                SizedBox(height: 1),
                Text(
                  'اسحب للكشف',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedSecretWord extends StatelessWidget {
  final AnimationController controller;
  final String secret;
  final double progress;
  final double resistance;

  const _AnimatedSecretWord({
    required this.controller,
    required this.secret,
    required this.progress,
    required this.resistance,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeOutBack.transform(controller.value);
        final opacity = Curves.easeOut.transform(
          controller.value.clamp(0.0, 1.0).toDouble(),
        );
        final scale = (.70 + (.30 * t)) * (1 + (.035 * resistance));
        final y = 24 * (1 - Curves.easeOutCubic.transform(controller.value));
        final angle = (1 - controller.value) * .045;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, y),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scaleX: scale,
                scaleY: scale * (1 - (.025 * resistance)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Color(0xFFEFFFFC)],
                    ).createShader(rect),
                    child: Text(
                      secret,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 43 + (progress * 7),
                        height: 1.02,
                        shadows: const [
                          Shadow(
                            color: Color(0x55000000),
                            offset: Offset(0, 4),
                            blurRadius: 13,
                          ),
                          Shadow(
                            color: Color(0x55FFFFFF),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SecretPatternPainter extends CustomPainter {
  final double progress;
  final double resistance;

  const _SecretPatternPainter({
    required this.progress,
    required this.resistance,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final gap = 34.0 - (3 * resistance);
    final offset = progress * 14 + (resistance * 9);
    for (double x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
        Offset(x + offset, size.height),
        Offset(x + size.height + offset, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SecretPatternPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.resistance != resistance;
  }
}
