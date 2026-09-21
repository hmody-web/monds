import 'package:flutter/material.dart';
import '../core/mundas_colors.dart';

class MultiplayerDrawingPad extends StatefulWidget {
  final List<Map<String, dynamic>> remoteStrokes;
  final bool enabled;
  final Future<void> Function(Map<String, dynamic> stroke) onStroke;
  const MultiplayerDrawingPad({super.key, required this.remoteStrokes, required this.enabled, required this.onStroke});

  @override
  State<MultiplayerDrawingPad> createState() => _MultiplayerDrawingPadState();
}

class _MultiplayerDrawingPadState extends State<MultiplayerDrawingPad> {
  final List<Offset> current = [];
  final colors = const [MundasColors.ink, MundasColors.coral, MundasColors.primary, MundasColors.blue, Color(0xFFF1A13A)];
  int colorIndex = 0;
  double width = 5;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          return GestureDetector(
            onPanStart: widget.enabled ? (d) => setState(() => current..clear()..add(d.localPosition)) : null,
            onPanUpdate: widget.enabled ? (d) => setState(() => current.add(d.localPosition)) : null,
            onPanEnd: widget.enabled ? (_) async {
              if (current.length < 2) return;
              final stroke = {
                'points': current.map((p) => [(p.dx / size.width).clamp(0.0, 1.0), (p.dy / size.height).clamp(0.0, 1.0)]).toList(),
                'color': colors[colorIndex].value,
                'width': width,
              };
              final copy = List<Offset>.from(current);
              setState(() => current.clear());
              try { await widget.onStroke(stroke); } catch (_) { if (mounted) setState(() => current.addAll(copy)); }
            } : null,
            child: CustomPaint(
              painter: _PadPainter(widget.remoteStrokes, current, colors[colorIndex], width),
              child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), border: Border.all(color: MundasColors.line, width: 1.5))),
            ),
          );
        }),
      ),
      const SizedBox(height: 10),
      Row(children: [
        ...List.generate(colors.length, (i) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: InkWell(
            onTap: widget.enabled ? () => setState(() => colorIndex = i) : null,
            child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: 34, height: 34, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle, border: Border.all(color: colorIndex == i ? MundasColors.ink : Colors.white, width: colorIndex == i ? 3 : 2))),
          ),
        )),
        const Spacer(),
        IconButton.filledTonal(onPressed: widget.enabled ? () => setState(() => width = width == 5 ? 9 : width == 9 ? 3 : 5) : null, icon: const Icon(Icons.line_weight_rounded)),
      ]),
    ]);
  }
}

class _PadPainter extends CustomPainter {
  final List<Map<String, dynamic>> remote;
  final List<Offset> current;
  final Color currentColor;
  final double currentWidth;
  _PadPainter(this.remote, this.current, this.currentColor, this.currentWidth);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in remote) {
      final ptsRaw = (s['points'] as List?) ?? const [];
      if (ptsRaw.length < 2) continue;
      final p = Paint()
        ..color = Color((s['color'] as num?)?.toInt() ?? MundasColors.ink.value)
        ..strokeWidth = (s['width'] as num?)?.toDouble() ?? 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < ptsRaw.length; i++) {
        final v = ptsRaw[i] as List;
        final o = Offset((v[0] as num).toDouble() * size.width, (v[1] as num).toDouble() * size.height);
        if (i == 0) path.moveTo(o.dx, o.dy); else path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, p);
    }
    if (current.length > 1) {
      final p = Paint()..color = currentColor..strokeWidth = currentWidth..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
      final path = Path()..moveTo(current.first.dx, current.first.dy);
      for (final o in current.skip(1)) { path.lineTo(o.dx, o.dy); }
      canvas.drawPath(path, p);
    }
  }
  @override
  bool shouldRepaint(covariant _PadPainter oldDelegate) => true;
}
