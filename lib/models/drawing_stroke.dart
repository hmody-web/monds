import 'dart:ui';

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final int ownerIndex;

  const DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.ownerIndex,
  });

  Map<String, dynamic> toNormalizedJson(Size size) => {
        'points': points
            .map((p) => [
                  (p.dx / size.width).clamp(0.0, 1.0),
                  (p.dy / size.height).clamp(0.0, 1.0),
                ])
            .toList(),
        'color': color.value,
        'width': width,
        'owner': ownerIndex,
      };

  factory DrawingStroke.fromNormalizedJson(Map<String, dynamic> json, Size size) {
    final raw = (json['points'] as List?) ?? const [];
    return DrawingStroke(
      points: raw
          .map((e) => e as List)
          .map((e) => Offset((e[0] as num).toDouble() * size.width, (e[1] as num).toDouble() * size.height))
          .toList(),
      color: Color((json['color'] as num?)?.toInt() ?? 0xFF183330),
      width: (json['width'] as num?)?.toDouble() ?? 4,
      ownerIndex: (json['owner'] as num?)?.toInt() ?? 0,
    );
  }
}
