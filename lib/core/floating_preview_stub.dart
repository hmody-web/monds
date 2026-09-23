import 'package:flutter/widgets.dart';

Future<void> configureFloatingPreviewWindow() async {}

class FloatingPreviewShell extends StatelessWidget {
  const FloatingPreviewShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
