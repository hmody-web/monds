import 'package:flutter/material.dart';

Route<T> mundasRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .035), end: Offset.zero).animate(curve),
            child: child,
          ),
        );
      },
    );
