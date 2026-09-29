import 'package:flutter/material.dart';

class ArcadeGameShell extends StatelessWidget {
  const ArcadeGameShell({
    super.key,
    required this.title,
    required this.child,
    this.bottom,
    this.onBack,
    this.onDetails,
    this.maxWidth = 880,
  });

  final String title;
  final Widget child;
  final Widget? bottom;
  final VoidCallback? onBack;
  final VoidCallback? onDetails;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final back = onBack ?? () => Navigator.maybePop(context);
    final compact = MediaQuery.sizeOf(context).width < 620;
    return Scaffold(
      backgroundColor: const Color(0xFF03070D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _ArcadeBackground(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(compact ? 8 : 14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(compact ? 22 : 30),
                  color: const Color(0xFF441D0B),
                  border: Border.all(
                    color: const Color(0xFFFFA21A),
                    width: compact ? 8 : 12,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0xAA000000), offset: Offset(0, 12), blurRadius: 26),
                    BoxShadow(color: Color(0x55FF9B00), blurRadius: 24),
                  ],
                ),
                child: Container(
                  margin: EdgeInsets.all(compact ? 5 : 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(compact ? 16 : 22),
                    border: Border.all(color: const Color(0xFF52E5F2), width: 3),
                    color: const Color(0xFF071522),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 8 : 14,
                          compact ? 8 : 12,
                          compact ? 8 : 14,
                          5,
                        ),
                        child: Row(
                          children: [
                            _ArcadeSquareButton(
                              icon: Icons.arrow_forward_rounded,
                              onTap: back,
                            ),
                            SizedBox(width: compact ? 8 : 14),
                            Expanded(
                              child: Container(
                                height: compact ? 62 : 76,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFFFF451C), Color(0xFFD71910), Color(0xFF8A0B08)],
                                  ),
                                  border: Border.all(color: const Color(0xFFFFD04B), width: 5),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0xAA000000), offset: Offset(0, 6), blurRadius: 0),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    for (final alignment in const [
                                      Alignment(-.96, -.72), Alignment(.96, -.72),
                                      Alignment(-.96, .72), Alignment(.96, .72),
                                    ])
                                      Align(
                                        alignment: alignment,
                                        child: Container(
                                          margin: const EdgeInsets.all(8),
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFFEA81),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                        child: Text(
                                          title,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'PCB',
                                            color: const Color(0xFFFFF1A6),
                                            fontSize: compact ? 22 : 29,
                                            fontWeight: FontWeight.w900,
                                            height: 1,
                                            shadows: const [
                                              Shadow(color: Color(0xFF5A0900), offset: Offset(3, 4), blurRadius: 0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (onDetails != null) ...[
                              SizedBox(width: compact ? 8 : 14),
                              _ArcadeSquareButton(
                                icon: Icons.info_outline_rounded,
                                onTap: onDetails!,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                compact ? 10 : 18,
                                10,
                                compact ? 10 : 18,
                                compact ? 10 : 16,
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                      if (bottom != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 10 : 18,
                              0,
                              compact ? 10 : 18,
                              compact ? 10 : 16,
                            ),
                            child: bottom!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF102C42), Color(0xFF091A29), Color(0xFF06121E)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? const Color(0xFFFFC547) : const Color(0xFF4FDDEB),
          width: selected ? 3 : 2.3,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x88000000), offset: Offset(0, 8), blurRadius: 0),
        ],
      ),
      child: child,
    );
    if (onTap == null) return panel;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: panel,
    );
  }
}

class ArcadeTextField extends StatelessWidget {
  const ArcadeTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon = Icons.person_rounded,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF7997AA), fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB62F)),
        filled: true,
        fillColor: const Color(0xFF050D15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF31566E), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFFB52B), width: 2.5),
        ),
      ),
    );
  }
}

class ArcadePrimaryButton extends StatelessWidget {
  const ArcadePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.play_arrow_rounded,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD71910),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF5B2E29),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFFFD45D), width: 4),
          ),
          elevation: 8,
          shadowColor: Colors.black,
        ),
        child: busy
            ? const SizedBox(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFFFE77A)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: const Color(0xFFFFF0A4), size: 27),
                  const SizedBox(width: 9),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'PCB',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class ArcadeDetailsDialog extends StatelessWidget {
  const ArcadeDetailsDialog({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF55240C),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFA21A), width: 7),
            boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 30, offset: Offset(0, 14))],
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF071522),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF52E5F2), width: 2.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF451C), Color(0xFFD71910), Color(0xFF8A0B08)],
                    ),
                    border: Border.all(color: const Color(0xFFFFD04B), width: 3),
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PCB',
                      color: Color(0xFFFFF1A6),
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                child,
                const SizedBox(height: 14),
                ArcadePrimaryButton(
                  label: 'رجوع',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcadeSquareButton extends StatelessWidget {
  const _ArcadeSquareButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFF8D18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFD04B), width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0xAA000000), offset: Offset(0, 5), blurRadius: 0),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

class _ArcadeBackground extends StatelessWidget {
  const _ArcadeBackground();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ArcadeBackgroundPainter());
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
        Rect.fromCircle(center: Offset(size.width * .5, size.height * .18), radius: size.width * .48),
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
