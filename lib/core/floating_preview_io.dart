import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

const _windowSize = Size(438, 918);
const _minimumWindowSize = Size(420, 320);
const _phoneRadius = 38.0;
const _frameThickness = 7.0;
const _dragAreaHeight = 25.0;

bool get _isWindows => Platform.isWindows;

Future<void> configureFloatingPreviewWindow() async {
  if (!_isWindows) return;

  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: _windowSize,
    minimumSize: _minimumWindowSize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setResizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
    await windowManager.focus();
  });
}

class FloatingPreviewShell extends StatelessWidget {
  const FloatingPreviewShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!_isWindows) return child;

    return DragToResizeArea(
      resizeEdgeSize: 12,
      enableResizeEdges: const [
        ResizeEdge.top,
        ResizeEdge.bottom,
        ResizeEdge.left,
        ResizeEdge.right,
        ResizeEdge.topLeft,
        ResizeEdge.topRight,
        ResizeEdge.bottomLeft,
        ResizeEdge.bottomRight,
      ],
      child: ColoredBox(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0C),
            borderRadius: BorderRadius.circular(_phoneRadius),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                spreadRadius: 1,
                offset: Offset(0, 6),
                color: Color(0x55000000),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_phoneRadius),
            child: Column(
              children: [
                _DragHandle(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _frameThickness,
                      0,
                      _frameThickness,
                      _frameThickness,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        _phoneRadius - _frameThickness,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        // Desktop-style title strip: double-click toggles maximize/restore.
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: const SizedBox(
        height: _dragAreaHeight,
        width: double.infinity,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFF333333),
              borderRadius: BorderRadius.all(Radius.circular(100)),
            ),
            child: SizedBox(width: 74, height: 5),
          ),
        ),
      ),
    );
  }
}
