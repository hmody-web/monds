import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/local_game_session.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_card.dart';
import '../../widgets/mundas_scaffold.dart';
import 'reveal_result_screen.dart';

class VotingScreen extends StatefulWidget {
  final LocalGameSession session;
  const VotingScreen({super.key, required this.session});

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  int voter = 0;
  int? selected;
  bool privacyCover = true;

  List<int> get allowedTargets {
    final runoff = widget.session.runoffCandidates;
    final base = runoff ?? List.generate(widget.session.players.length, (i) => i);
    return base.where((i) => i != voter).toList();
  }

  void _submit() {
    if (selected == null) return;
    HapticFeedback.mediumImpact();
    widget.session.addVote(voter, selected!);
    selected = null;
    if (voter < widget.session.players.length - 1) {
      setState(() {
        voter++;
        privacyCover = true;
      });
      return;
    }
    final resolution = widget.session.resolveVotes();
    if (resolution.isTie) {
      setState(() {
        voter = 0;
        privacyCover = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعادل! جولة تصويت فاصلة بين المتعادلين.')),
      );
    } else {
      Navigator.pushReplacement(
        context,
        mundasRoute(RevealResultScreen(session: widget.session)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.session.players[voter];
    return MundasScaffold(
      title: widget.session.runoffCandidates == null ? 'التصويت' : 'تصويت فاصل',
      showBack: false,
      gameExit: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        child: privacyCover
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: MundasCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🗳️', style: TextStyle(fontSize: 54)),
                        const SizedBox(height: 12),
                        Text('مرر الهاتف إلى ${p.name}', style: const TextStyle(fontSize: 26), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text('التصويت سري. لا تخلي أحد يشوف اختيارك.', style: TextStyle(color: MundasColors.muted), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        SizedBox(width: double.infinity, child: MundasButton(label: 'أنا جاهز للتصويت', icon: Icons.how_to_vote_rounded, onPressed: () => setState(() => privacyCover = false))),
                      ],
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  Text('${p.name}، منو المندس؟', style: const TextStyle(fontSize: 25)),
                  const SizedBox(height: 6),
                  Text('صوّت ${voter + 1} من ${widget.session.players.length}', style: const TextStyle(color: MundasColors.muted)),
                  const SizedBox(height: 18),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.18, crossAxisSpacing: 12, mainAxisSpacing: 12),
                      itemCount: allowedTargets.length,
                      itemBuilder: (_, index) {
                        final targetIndex = allowedTargets[index];
                        final target = widget.session.players[targetIndex];
                        final active = selected == targetIndex;
                        return InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => selected = targetIndex);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: active ? MundasColors.primaryLight : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: active ? MundasColors.primary : MundasColors.line, width: active ? 2.5 : 1.5),
                              boxShadow: active ? const [BoxShadow(color: MundasColors.shadow, offset: Offset(0, 5), blurRadius: 0)] : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(['🕵️','🦊','🐼','🐯','🐸','🦝','🐧','🐻'][target.avatar % 8], style: const TextStyle(fontSize: 38)),
                                const SizedBox(height: 7),
                                Text(target.name, style: const TextStyle(fontSize: 18), overflow: TextOverflow.ellipsis),
                                if (active) const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.check_circle_rounded, color: MundasColors.primary)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(width: double.infinity, child: MundasButton(label: voter == widget.session.players.length - 1 ? 'إظهار النتيجة' : 'تأكيد التصويت', icon: Icons.check_rounded, onPressed: selected == null ? null : _submit)),
                ],
              ),
      ),
    );
  }
}
