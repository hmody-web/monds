import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/mundas_colors.dart';

/// نافذة سرية تسحب من أسفل الشاشة لكشف الكلمة/المندس.
/// الارتفاع الأقصى 35% من المساحة المتاحة. بعد الوصول للحد يحصل
/// Stretch بصري فقط من غير زيادة الارتفاع الفعلي.
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

class _SecretPullRevealState extends State<SecretPullReveal> {
  double _rawPull = 0;
  bool _dragging = false;
  bool _reportedSeen = false;
  bool _thresholdHaptic = false;

  void _start(DragStartDetails _) {
    setState(() => _dragging = true);
    widget.onDraggingChanged?.call(true);
  }

  void _update(DragUpdateDetails details, double travel) {
    if (travel <= 0) return;
    final next = math.max(0.0, _rawPull - details.delta.dy);
    setState(() => _rawPull = next);

    final progress = (_rawPull / travel).clamp(0.0, 1.0);
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
  }

  void _release() {
    HapticFeedback.selectionClick();
    setState(() {
      _dragging = false;
      _rawPull = 0;
    });
    widget.onDraggingChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;

        final screenHeight = MediaQuery.sizeOf(context).height;
        final maxHeight = math.min(
          availableHeight,
          math.max(120.0, screenHeight * .35),
        );
        final collapsedHeight = math.min(88.0, maxHeight);
        final travel = math.max(1.0, maxHeight - collapsedHeight);
        final visiblePull = math.min(_rawPull, travel);
        final progress = (visiblePull / travel).clamp(0.0, 1.0);
        final overPull = math.max(0.0, _rawPull - travel);
        final elastic = (overPull / 110).clamp(0.0, 1.0);

        // الارتفاع لا يتجاوز maxHeight نهائياً.
        final panelHeight = collapsedHeight + visiblePull;

        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: maxHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ClipRect(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _start,
                    onVerticalDragUpdate: (d) => _update(d, travel),
                    onVerticalDragEnd: (_) => _release(),
                    onVerticalDragCancel: _release,
                    child: AnimatedContainer(
                      duration: _dragging
                          ? Duration.zero
                          : const Duration(milliseconds: 720),
                      curve: Curves.easeOutBack,
                      height: panelHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          MundasColors.ink,
                          widget.revealColor,
                          Curves.easeOut.transform(progress),
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(34),
                        ),
                        border: Border.all(
                          color: MundasColors.ink,
                          width: 2.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: MundasColors.shadow,
                            offset: Offset(0, -6),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: .10 + (.10 * progress),
                                  child: CustomPaint(
                                    painter: _SecretPatternPainter(progress),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.topCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                margin: const EdgeInsets.only(top: 13),
                                width: 58 + (elastic * 18),
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.78),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(
                                        begin: .86,
                                        end: 1,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutBack,
                                        ),
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: progress < .18
                                    ? const Icon(
                                        Icons.keyboard_double_arrow_up_rounded,
                                        key: ValueKey('pull'),
                                        color: Colors.white,
                                        size: 35,
                                      )
                                    : Transform.scale(
                                        key: const ValueKey('secret'),
                                        // Stretch بصري داخلي فقط؛ الContainer نفسه
                                        // يبقى محدوداً بـ 35%.
                                        scaleX: 1 + (.035 * elastic),
                                        scaleY: 1 - (.018 * elastic),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                          ),
                                          child: Text(
                                            widget.secret,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 42 + (progress * 7),
                                              height: 1.05,
                                              shadows: const [
                                                Shadow(
                                                  color: Color(0x33000000),
                                                  offset: Offset(0, 3),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                          ),
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
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SecretPatternPainter extends CustomPainter {
  final double progress;
  const _SecretPatternPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final gap = 34.0;
    final offset = progress * 14;
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
    return oldDelegate.progress != progress;
  }
}
