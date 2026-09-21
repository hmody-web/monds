import 'package:flutter/material.dart';
import '../core/mundas_colors.dart';
import 'dot_background.dart';

class MundasScaffold extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool showBack;
  final List<Widget>? actions;
  final Widget? bottom;

  const MundasScaffold({
    super.key,
    this.title,
    required this.child,
    this.showBack = true,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: DotBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    if (showBack)
                      IconButton.filledTonal(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_forward_rounded),
                      )
                    else
                      const SizedBox(width: 48),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 21, color: MundasColors.ink),
                      ),
                    ),
                    if (actions != null) ...actions! else const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(child: child),
              if (bottom != null) bottom!,
            ],
          ),
        ),
      ),
    );
  }
}
