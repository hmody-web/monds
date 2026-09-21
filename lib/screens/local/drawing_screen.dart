import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/drawing_stroke.dart';
import '../../models/local_game_session.dart';
import '../../widgets/drawing_board.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_scaffold.dart';
import 'discussion_screen.dart';

class DrawingScreen extends StatefulWidget {
  final LocalGameSession session;
  const DrawingScreen({super.key, required this.session});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  bool _ready = false;

  void _finishTurn() {
    HapticFeedback.selectionClick();
    if (widget.session.isLastDrawer) {
      Navigator.pushReplacement(context, mundasRoute(DiscussionScreen(session: widget.session)));
      return;
    }
    widget.session.nextDrawer();
    setState(() => _ready = false);
  }

  void _undo() {
    for (var i = widget.session.strokes.length - 1; i >= 0; i--) {
      if (widget.session.strokes[i].ownerIndex == widget.session.drawIndex) {
        setState(() => widget.session.strokes.removeAt(i));
        HapticFeedback.selectionClick();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = widget.session.currentDrawer;
    return MundasScaffold(
      title: 'الرسم المشترك',
      showBack: false,
      actions: [
        IconButton.filledTonal(onPressed: _ready ? _undo : null, icon: const Icon(Icons.undo_rounded)),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: MundasColors.primaryLight, shape: BoxShape.circle),
                  child: Text('${widget.session.drawIndex + 1}', style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_ready ? '${drawer.name} يرسم الآن' : 'مرر الهاتف إلى ${drawer.name}', style: const TextStyle(fontSize: 19)),
                      Text(_ready ? 'أضف تلميحك بدون ما تكشف الكلمة' : 'البقية لا يشوفون الشاشة', style: const TextStyle(color: MundasColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: widget.session.turnInk,
                minHeight: 8,
                backgroundColor: MundasColors.line,
                valueColor: AlwaysStoppedAnimation(widget.session.turnInk < .22 ? MundasColors.coral : MundasColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  DrawingBoard(
                    strokes: widget.session.strokes,
                    ownerIndex: widget.session.drawIndex,
                    enabled: _ready,
                    ink: widget.session.turnInk,
                    onInkChanged: (v) {
                      widget.session.turnInk = v;
                      if (v <= 0 && mounted) {
                        setState(() {});
                      }
                    },
                    onStrokeFinished: (DrawingStroke stroke) => setState(() => widget.session.strokes.add(stroke)),
                  ),
                  if (!_ready)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(color: MundasColors.background.withOpacity(.93), borderRadius: BorderRadius.circular(28)),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.phone_android_rounded, size: 58, color: MundasColors.primary),
                                const SizedBox(height: 14),
                                Text('جاهز يا ${drawer.name}؟', style: const TextStyle(fontSize: 28)),
                                const SizedBox(height: 8),
                                const Text('اضغط لما يصير الهاتف بيدك. راح تشوف الرسم السابق وتضيف تلميحك.', textAlign: TextAlign.center, style: TextStyle(color: MundasColors.muted, height: 1.5)),
                                const SizedBox(height: 20),
                                MundasButton(label: 'أنا جاهز', icon: Icons.brush_rounded, onPressed: () => setState(() => _ready = true)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            if (_ready)
              SizedBox(
                width: double.infinity,
                child: MundasButton(
                  label: widget.session.isLastDrawer ? 'إنهاء الرسم' : 'خلصت دوري',
                  icon: Icons.check_rounded,
                  onPressed: _finishTurn,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
