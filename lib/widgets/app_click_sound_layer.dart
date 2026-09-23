import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_audio_service.dart';

class AppClickSoundLayer extends StatefulWidget {
  const AppClickSoundLayer({super.key, required this.child});

  final Widget child;

  @override
  State<AppClickSoundLayer> createState() => _AppClickSoundLayerState();
}

class _TapCandidate {
  _TapCandidate(this.position, this.startedAt);

  final Offset position;
  final DateTime startedAt;
  bool moved = false;
}

class _AppClickSoundLayerState extends State<AppClickSoundLayer> {
  final Map<int, _TapCandidate> _candidates = {};

  void _down(PointerDownEvent event) {
    _candidates[event.pointer] = _TapCandidate(event.position, DateTime.now());
  }

  void _move(PointerMoveEvent event) {
    final candidate = _candidates[event.pointer];
    if (candidate == null || candidate.moved) return;
    if ((event.position - candidate.position).distance > 11) {
      candidate.moved = true;
    }
  }

  void _up(PointerUpEvent event) {
    final candidate = _candidates.remove(event.pointer);
    if (candidate == null || candidate.moved || AppAudioService.suppressGlobalClick) return;
    final held = DateTime.now().difference(candidate.startedAt);
    if (held > const Duration(milliseconds: 360)) return;
    unawaited(AppAudioService.playClick());
  }

  void _cancel(PointerCancelEvent event) {
    _candidates.remove(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: widget.child,
    );
  }
}
