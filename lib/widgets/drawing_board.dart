import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/mundas_colors.dart';
import '../models/drawing_stroke.dart';

class DrawingBoard extends StatefulWidget {
  final List<DrawingStroke> strokes;
  final int ownerIndex;
  final bool enabled;
  final double ink;
  final ValueChanged<double> onInkChanged;
  final ValueChanged<DrawingStroke> onStrokeFinished;

  const DrawingBoard({
    super.key,
    required this.strokes,
    required this.ownerIndex,
    required this.enabled,
    required this.ink,
    required this.onInkChanged,
    required this.onStrokeFinished,
  });

  @override
  State<DrawingBoard> createState() => _DrawingBoardState();
}

class _DrawingBoardState extends State<DrawingBoard> {
  final List<Offset> _current = [];
  Color _color = MundasColors.ink;
  double _width = 4.5;
  double _inkRemaining = 1;

  static const palette = [
    MundasColors.ink,
    MundasColors.primary,
    MundasColors.coral,
    MundasColors.blue,
    MundasColors.gold,
  ];

  @override
  void initState() {
    super.initState();
    _inkRemaining = widget.ink;
  }

  @override
  void didUpdateWidget(covariant DrawingBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerIndex != widget.ownerIndex || oldWidget.ink != widget.ink) {
      _inkRemaining = widget.ink;
      _current.clear();
    }
  }

  void _start(DragStartDetails d) {
    if (!widget.enabled || _inkRemaining <= 0) return;
    setState(() => _current
      ..clear()
      ..add(d.localPosition));
  }

  void _update(DragUpdateDetails d, Size size) {
    if (!widget.enabled || _inkRemaining <= 0 || _current.isEmpty) return;
    final p = d.localPosition;
    final last = _current.last;
    final dist = (p - last).distance;
    final denominator = math.max(size.width, size.height);
    final cost = dist / (denominator * 4.8);
    final nextInk = (_inkRemaining - cost).clamp(0.0, 1.0);
    if (nextInk == _inkRemaining) return;
    setState(() {
      _inkRemaining = nextInk;
      _current.add(p);
    });
    widget.onInkChanged(_inkRemaining);
    if (_inkRemaining <= 0) _finish();
  }

  void _finish() {
    if (_current.length < 2) {
      setState(_current.clear);
      return;
    }
    final stroke = DrawingStroke(
      points: List.unmodifiable(_current),
      color: _color,
      width: _width,
      ownerIndex: widget.ownerIndex,
    );
    widget.onStrokeFinished(stroke);
    setState(_current.clear);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: MundasColors.ink, width: 2),
                  boxShadow: const [BoxShadow(color: MundasColors.shadow, offset: Offset(0, 6), blurRadius: 0)],
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _start,
                  onPanUpdate: (d) => _update(d, size),
                  onPanEnd: (_) => _finish(),
                  child: CustomPaint(
                    painter: _DrawingPainter(strokes: widget.strokes, current: _current, currentColor: _color, currentWidth: _width),
                    size: Size.infinite,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final c in palette)
              GestureDetector(
                onTap: widget.enabled ? () => setState(() => _color = c) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: _color == c ? 34 : 29,
                  height: _color == c ? 34 : 29,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: MundasColors.shadow, blurRadius: 4)],
                  ),
                ),
              ),
            const SizedBox(width: 8),
            PopupMenuButton<double>(
              enabled: widget.enabled,
              onSelected: (v) => setState(() => _width = v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 3, child: Text('قلم رفيع')),
                PopupMenuItem(value: 5, child: Text('قلم متوسط')),
                PopupMenuItem(value: 8, child: Text('قلم عريض')),
              ],
              icon: const Icon(Icons.line_weight_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<Offset> current;
  final Color currentColor;
  final double currentWidth;

  _DrawingPainter({required this.strokes, required this.current, required this.currentColor, required this.currentWidth});

  void _draw(Canvas canvas, List<Offset> points, Color color, double width) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      _draw(canvas, s.points, s.color, s.width);
    }
    _draw(canvas, current, currentColor, currentWidth);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
