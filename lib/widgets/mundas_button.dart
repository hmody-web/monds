import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/mundas_colors.dart';

class MundasButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color foreground;
  final bool compact;

  const MundasButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = MundasColors.primary,
    this.foreground = Colors.white,
    this.compact = false,
  });

  @override
  State<MundasButton> createState() => _MundasButtonState();
}

class _MundasButtonState extends State<MundasButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
    if (value) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final color = disabled ? MundasColors.line : widget.color;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        widget.onPressed?.call();
      },
      child: AnimatedTransform(
        pressed: _pressed,
        child: Container(
          height: widget.compact ? 48 : 58,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(widget.compact ? 16 : 20),
            border: Border.all(color: disabled ? MundasColors.line : MundasColors.ink, width: 2),
            boxShadow: _pressed || disabled
                ? const []
                : const [
                    BoxShadow(color: MundasColors.ink, offset: Offset(0, 5), blurRadius: 0),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: widget.foreground, size: 22),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: disabled ? MundasColors.muted : widget.foreground,
                    fontSize: widget.compact ? 15 : 18,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedTransform extends StatelessWidget {
  final bool pressed;
  final Widget child;
  const AnimatedTransform({super.key, required this.pressed, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..translate(0.0, pressed ? 4.0 : 0.0)
          ..scale(pressed ? 0.985 : 1.0),
        child: child,
      );
}
