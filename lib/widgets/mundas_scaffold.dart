import 'package:flutter/material.dart';
import '../core/mundas_colors.dart';
import 'dot_background.dart';

class MundasScaffold extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool showBack;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool gameExit;

  const MundasScaffold({
    super.key,
    this.title,
    required this.child,
    this.showBack = true,
    this.actions,
    this.bottom,
    this.gameExit = false,
  });

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: MundasColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(
                color: MundasColors.ink,
                offset: Offset(0, 7),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE7E4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 34,
                  color: MundasColors.coral,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'تطلع من هذا الكيم؟',
                style: TextStyle(fontSize: 26),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'إذا خرجت راح تترك الجولة الحالية وترجع للصفحة الرئيسية.',
                style: TextStyle(
                  color: MundasColors.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: MundasColors.line, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: const Text('أبقى'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: MundasColors.coral,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: const Text('إي، اطلع'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldExit == true && context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trailing = <Widget>[
      if (actions != null) ...actions!,
      if (gameExit)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: IconButton.filledTonal(
            tooltip: 'الخروج من الكيم',
            onPressed: () => _confirmExit(context),
            icon: const Icon(Icons.logout_rounded, color: MundasColors.coral),
          ),
        ),
    ];

    return Scaffold(
      body: SafeArea(
        child: DotBackground(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Builder(
                  builder: (context) {
                    final slots = trailing.isEmpty ? 1 : trailing.length;
                    final sideWidth = 48.0 * slots + (slots > 1 ? 4.0 * (slots - 1) : 0);
                    return Row(
                      children: [
                        SizedBox(
                          width: sideWidth,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: showBack
                                ? IconButton.filledTonal(
                                    onPressed: () => Navigator.maybePop(context),
                                    icon: const Icon(Icons.arrow_forward_rounded),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 21,
                              color: MundasColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: sideWidth,
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: trailing.isNotEmpty
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: trailing,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
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
