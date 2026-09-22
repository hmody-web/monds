import 'package:flutter/material.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/local_game_session.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_scaffold.dart';
import '../../widgets/secret_pull_reveal.dart';
import 'drawing_screen.dart';

class RoleRevealScreen extends StatefulWidget {
  final LocalGameSession session;
  const RoleRevealScreen({super.key, required this.session});

  @override
  State<RoleRevealScreen> createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<RoleRevealScreen> {
  bool _seen = false;
  bool _dragging = false;

  void _next() {
    if (!widget.session.isLastReveal) {
      widget.session.nextReveal();
      setState(() {
        _seen = false;
        _dragging = false;
      });
    } else {
      Navigator.pushReplacement(
        context,
        mundasRoute(DrawingScreen(session: widget.session)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.session.currentRevealPlayer;
    final isImposter = widget.session.currentRevealIsImposter;
    final secret = isImposter ? 'مندس' : widget.session.secretWord;

    return MundasScaffold(
      title: 'كشف الدور',
      showBack: false,
      gameExit: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 4),
                child: Column(
                  children: [
                    Text(
                      'مرر الهاتف إلى',
                      style: TextStyle(
                        fontSize: 15,
                        color: MundasColors.muted.withOpacity(.92),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      player.name,
                      style: const TextStyle(fontSize: 35),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'خلي الشاشة إلك وحدك 👀',
                      style: TextStyle(
                        color: MundasColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SecretPullReveal(
                        key: ValueKey('local-secret-${widget.session.revealIndex}'),
                        secret: secret,
                        revealColor: isImposter
                            ? MundasColors.coral
                            : MundasColors.primary,
                        onSeen: () {
                          if (mounted) setState(() => _seen = true);
                        },
                        onDraggingChanged: (value) {
                          if (mounted) setState(() => _dragging = value);
                        },
                      ),
                    ),
                    Positioned(
                      left: 22,
                      right: 22,
                      bottom: MediaQuery.sizeOf(context).height * .37,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        offset: _seen && !_dragging
                            ? Offset.zero
                            : const Offset(0, .35),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _seen && !_dragging ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !_seen || _dragging,
                            child: MundasButton(
                              label: widget.session.isLastReveal
                                  ? 'ابدأ الرسم'
                                  : 'فهمت دوري',
                              icon: Icons.check_rounded,
                              onPressed: _next,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
