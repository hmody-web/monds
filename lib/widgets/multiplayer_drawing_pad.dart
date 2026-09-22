import 'dart:async';
import 'package:flutter/material.dart';
import '../core/mundas_colors.dart';

class MultiplayerDrawingPad extends StatefulWidget {
  final List<Map<String, dynamic>> remoteStrokes;
  final Map<String, dynamic>? remoteLiveStroke;
  final bool enabled;
  final Future<void> Function(Map<String, dynamic> stroke) onStroke;
  final Future<void> Function(Map<String, dynamic> stroke)? onLiveStroke;

  const MultiplayerDrawingPad({
    super.key,
    required this.remoteStrokes,
    required this.enabled,
    required this.onStroke,
    this.remoteLiveStroke,
    this.onLiveStroke,
  });

  @override
  State<MultiplayerDrawingPad> createState() => _MultiplayerDrawingPadState();
}

class _MultiplayerDrawingPadState extends State<MultiplayerDrawingPad> {
  final List<Offset> current = [];
  final List<Map<String, dynamic>> localEcho = [];
  final colors = const [
    MundasColors.ink,
    MundasColors.coral,
    MundasColors.primary,
    MundasColors.blue,
    Color(0xFFF1A13A),
  ];

  Timer? _liveTimer;
  bool _liveInFlight = false;
  bool _liveDirty = false;
  Size _boardSize = Size.zero;
  int colorIndex = 0;
  double width = 5;

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  List<List<num>> _normalizedPoints(Size size, {int maxPoints = 160}) {
    if (size.width <= 0 || size.height <= 0 || current.isEmpty) {
      return const [];
    }

    final raw = current
        .map(
          (p) => <num>[
            (p.dx / size.width).clamp(0.0, 1.0),
            (p.dy / size.height).clamp(0.0, 1.0),
          ],
        )
        .toList(growable: false);

    if (raw.length <= maxPoints) return raw;

    final sampled = <List<num>>[];
    for (var i = 0; i < maxPoints; i++) {
      final index =
          ((i * (raw.length - 1)) / (maxPoints - 1)).round();
      sampled.add(raw[index]);
    }
    return sampled;
  }

  Map<String, dynamic> _strokeSnapshot(
    Size size, {
    int maxPoints = 160,
  }) {
    return <String, dynamic>{
      'points': _normalizedPoints(size, maxPoints: maxPoints),
      'color': colors[colorIndex].value,
      'width': width,
    };
  }

  void _scheduleLiveSend() {
    if (widget.onLiveStroke == null || _boardSize.isEmpty) return;
    _liveDirty = true;
    if (_liveTimer?.isActive == true || _liveInFlight) return;

    _liveTimer = Timer(
      const Duration(milliseconds: 78),
      _flushLiveStroke,
    );
  }

  Future<void> _flushLiveStroke() async {
    if (!mounted || widget.onLiveStroke == null || current.isEmpty) return;
    if (_liveInFlight) {
      _liveDirty = true;
      return;
    }

    _liveDirty = false;
    _liveInFlight = true;
    final snapshot = _strokeSnapshot(_boardSize, maxPoints: 110);

    try {
      await widget.onLiveStroke!(snapshot);
    } catch (_) {
      // الإرسال النهائي عند رفع الإصبع يبقى المصدر المؤكد للخط.
    } finally {
      _liveInFlight = false;
      if (mounted && _liveDirty && current.isNotEmpty) {
        _liveTimer = Timer(
          const Duration(milliseconds: 55),
          _flushLiveStroke,
        );
      }
    }
  }

  Future<void> _clearRemoteLive() async {
    if (widget.onLiveStroke == null) return;
    try {
      await widget.onLiveStroke!(const {'points': []});
    } catch (_) {
      // لا نوقف الرسم بسبب فشل تحديث مؤقت.
    }
  }

  Future<void> _finishStroke(Size size) async {
    _liveTimer?.cancel();

    if (current.length < 2 || size.width <= 0 || size.height <= 0) {
      if (mounted) setState(current.clear);
      await _clearRemoteLive();
      return;
    }

    final stroke = _strokeSnapshot(size);
    final echo = Map<String, dynamic>.from(stroke);

    if (mounted) {
      setState(() {
        localEcho.add(echo);
        current.clear();
      });
    }

    try {
      await widget.onStroke(stroke);
      Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() => localEcho.remove(echo));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => localEcho.remove(echo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRemote = <Map<String, dynamic>>[
      ...widget.remoteStrokes,
      if (widget.remoteLiveStroke != null) widget.remoteLiveStroke!,
      ...localEcho,
    ];

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              _boardSize = size;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: MundasColors.line,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: MundasColors.shadow,
                      offset: Offset(0, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: widget.enabled
                      ? (d) {
                          setState(() {
                            current
                              ..clear()
                              ..add(d.localPosition);
                          });
                          _scheduleLiveSend();
                        }
                      : null,
                  onPanUpdate: widget.enabled
                      ? (d) {
                          // تجاهل النقاط الملتصقة جداً حتى يبقى البث خفيفاً،
                          // مع الحفاظ على شكل الخط السلس.
                          final p = d.localPosition;
                          if (current.isEmpty ||
                              (p - current.last).distance >= 1.6) {
                            setState(() => current.add(p));
                            _scheduleLiveSend();
                          }
                        }
                      : null,
                  onPanEnd: widget.enabled
                      ? (_) => _finishStroke(size)
                      : null,
                  onPanCancel: widget.enabled
                      ? () {
                          _liveTimer?.cancel();
                          setState(current.clear);
                          unawaited(_clearRemoteLive());
                        }
                      : null,
                  child: CustomPaint(
                    foregroundPainter: _PadPainter(
                      allRemote,
                      current,
                      colors[colorIndex],
                      width,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ...List.generate(
              colors.length,
              (i) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: InkWell(
                  onTap: widget.enabled
                      ? () => setState(() => colorIndex = i)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorIndex == i
                            ? MundasColors.ink
                            : Colors.white,
                        width: colorIndex == i ? 3 : 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            IconButton.filledTonal(
              onPressed: widget.enabled
                  ? () => setState(
                        () => width = width == 5
                            ? 9
                            : width == 9
                                ? 3
                                : 5,
                      )
                  : null,
              icon: const Icon(Icons.line_weight_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _PadPainter extends CustomPainter {
  final List<Map<String, dynamic>> remote;
  final List<Offset> current;
  final Color currentColor;
  final double currentWidth;

  _PadPainter(
    this.remote,
    this.current,
    this.currentColor,
    this.currentWidth,
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in remote) {
      final ptsRaw = (s['points'] as List?) ?? const [];
      if (ptsRaw.isEmpty) continue;

      final paint = Paint()
        ..color = Color(
          (s['color'] as num?)?.toInt() ?? MundasColors.ink.value,
        )
        ..strokeWidth = (s['width'] as num?)?.toDouble() ?? 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      Offset? first;
      final path = Path();

      for (var i = 0; i < ptsRaw.length; i++) {
        final point = ptsRaw[i];
        if (point is! List || point.length < 2) continue;

        final offset = Offset(
          (point[0] as num).toDouble() * size.width,
          (point[1] as num).toDouble() * size.height,
        );

        first ??= offset;
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }

      if (ptsRaw.length == 1 && first != null) {
        canvas.drawCircle(first, paint.strokeWidth / 2, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }

    if (current.isNotEmpty) {
      final paint = Paint()
        ..color = currentColor
        ..strokeWidth = currentWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (current.length == 1) {
        canvas.drawCircle(current.first, currentWidth / 2, paint);
      } else {
        final path = Path()
          ..moveTo(current.first.dx, current.first.dy);
        for (final offset in current.skip(1)) {
          path.lineTo(offset.dx, offset.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PadPainter oldDelegate) => true;
}
