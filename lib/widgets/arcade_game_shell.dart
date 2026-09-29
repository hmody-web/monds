import 'package:flutter/material.dart';

class ArcadeGameShell extends StatelessWidget {
  const ArcadeGameShell({
    super.key,
    required this.title,
    required this.child,
    this.bottom,
    this.onBack,
    this.maxWidth = 880,
  });

  final String title;
  final Widget child;
  final Widget? bottom;
  final VoidCallback? onBack;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final back = onBack ?? () => Navigator.maybePop(context);
    return Scaffold(
      backgroundColor: const Color(0xFF060A10),
      body: Stack(
        children: [
          const Positioned.fill(child: _ArcadeBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      _ArcadeBackButton(onTap: back),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'PCB',
                            color: Color(0xFFFFC547),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(color: Color(0xAA000000), offset: Offset(0, 3)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: child,
                    ),
                  ),
                ),
                if (bottom != null)
                  SafeArea(
                    top: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: bottom!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ArcadePanel extends StatelessWidget {
  const ArcadePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.selected = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding,
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF17333A).withOpacity(.92)
            : const Color(0xFF101820).withOpacity(.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? const Color(0xFF27C38A) : const Color(0xFF606873),
          width: selected ? 2.2 : 1.25,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x77000000), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return panel;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: panel,
    );
  }
}

class ArcadePrimaryButton extends StatelessWidget {
  const ArcadePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.play_arrow_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 26),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'PCB',
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFFB72822) : const Color(0xFF454A50),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white54,
          disabledBackgroundColor: const Color(0xFF454A50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: enabled ? const Color(0xFFFFC547) : const Color(0xFF666B72),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcadeBackButton extends StatelessWidget {
  const _ArcadeBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A3037),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF9298A0), width: 1.5),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _ArcadeBackground extends StatelessWidget {
  const _ArcadeBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ArcadeBackgroundPainter());
  }
}

class _ArcadeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1521), Color(0xFF07101A), Color(0xFF04070B)],
          stops: [0, .58, 1],
        ).createShader(rect),
    );

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFF8B24).withOpacity(.18), Colors.transparent],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .5, size.height * .18),
          radius: size.width * .48,
        ),
      );
    canvas.drawRect(rect, glow);

    final line = Paint()
      ..color = const Color(0xFF637080).withOpacity(.12)
      ..strokeWidth = 1;
    const step = 34.0;
    for (double y = size.height * .62; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final centerX = size.width / 2;
    for (double x = -size.width; x < size.width * 2; x += step * 1.6) {
      final dx = (x - centerX) * 1.65 + centerX;
      canvas.drawLine(Offset(dx, size.height), Offset(centerX, size.height * .62), line);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcadeBackgroundPainter oldDelegate) => false;
}
