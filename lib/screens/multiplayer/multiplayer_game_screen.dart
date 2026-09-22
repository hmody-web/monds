import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/mundas_colors.dart';
import '../../models/online_room.dart';
import '../../services/multiplayer_service.dart';
import '../../widgets/multiplayer_drawing_pad.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_card.dart';
import '../../widgets/mundas_scaffold.dart';
import '../../widgets/suspense_reveal.dart';
import '../../widgets/secret_pull_reveal.dart';
import '../../widgets/imposter_wheel_reveal.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final OnlineIdentity identity;
  final OnlineRoom initialRoom;

  const MultiplayerGameScreen({
    super.key,
    required this.identity,
    required this.initialRoom,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  final service = MultiplayerService();
  late OnlineRoom room;
  Timer? timer;
  bool roleVisible = false;
  bool roleSeen = false;
  bool busy = false;
  bool revealDone = false;
  String? error;
  String? selectedVote;
  String? selectedGuess;
  bool imposterWheelFinished = false;

  bool _polling = false;
  bool _drawingPolling = false;
  bool _roleDragging = false;
  Timer? _drawingTimer;
  List<Map<String, dynamic>> _fastStrokes = const [];
  Map<String, dynamic>? _fastLiveStroke;

  @override
  void initState() {
    super.initState();
    room = widget.initialRoom;
    _fastStrokes = room.strokes;
    _fastLiveStroke = room.liveStroke;
    _schedulePoll(const Duration(milliseconds: 80));
    _syncDrawingPolling();
  }

  @override
  void dispose() {
    timer?.cancel();
    _drawingTimer?.cancel();
    super.dispose();
  }

  void _schedulePoll([Duration? delay]) {
    timer?.cancel();
    if (!mounted) return;
    final cadence = delay ?? const Duration(milliseconds: 520);
    timer = Timer(cadence, _poll);
  }

  void _syncDrawingPolling() {
    if (!mounted) return;
    if (room.phase != 'drawing') {
      _drawingTimer?.cancel();
      _drawingTimer = null;
      return;
    }

    if (_drawingTimer?.isActive == true) return;
    _drawingTimer = Timer(
      const Duration(milliseconds: 90),
      _pollDrawingState,
    );
  }

  Future<void> _pollDrawingState() async {
    if (!mounted || room.phase != 'drawing') return;

    if (_drawingPolling) {
      _drawingTimer = Timer(
        const Duration(milliseconds: 90),
        _pollDrawingState,
      );
      return;
    }

    _drawingPolling = true;
    try {
      final state = await service.drawingState(widget.identity);
      if (!mounted || room.phase != 'drawing') return;

      final strokes = ((state['strokes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);

      final live = state['live_stroke'] is Map
          ? (state['live_stroke'] as Map).cast<String, dynamic>()
          : null;

      setState(() {
        _fastStrokes = strokes;
        _fastLiveStroke = live;
      });
    } catch (_) {
      // تحديث الغرفة الرئيسي يبقى مسؤولاً عن إظهار حالة الاتصال.
    } finally {
      _drawingPolling = false;
      if (mounted && room.phase == 'drawing') {
        _drawingTimer = Timer(
          const Duration(milliseconds: 90),
          _pollDrawingState,
        );
      }
    }
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final r = await service.room(widget.identity, since: room.version);
      if (!mounted) return;
      final changedPhase = r.phase != room.phase;
      setState(() {
        room = r;
        error = null;
        if (r.phase == 'drawing') {
          _fastStrokes = r.strokes;
          _fastLiveStroke = r.liveStroke;
        }
        if (changedPhase) {
          selectedVote = null;
          roleVisible = false;
          roleSeen = false;
          revealDone = false;
          imposterWheelFinished = false;
          selectedGuess = null;
          _roleDragging = false;
        }
      });
      _syncDrawingPolling();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      _polling = false;
      if (mounted) _schedulePoll();
    }
  }

  Future<void> _action(
    String action, [
    Map<String, dynamic>? payload,
  ]) async {
    setState(() => busy = true);
    try {
      await service.action(widget.identity, action, payload);
      await _poll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  OnlinePlayer? get me => room.playerById(widget.identity.playerId);
  bool get isHost => me?.host ?? widget.identity.isHost;

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (room.phase) {
      case 'role_reveal':
        body = _role();
        break;
      case 'drawing':
        body = _drawing();
        break;
      case 'discussion':
        body = _discussion();
        break;
      case 'voting':
        body = _voting();
        break;
      case 'reveal':
        body = _reveal();
        break;
      case 'imposter_guess':
        body = _guess();
        break;
      case 'imposter_reveal':
        body = _imposterReveal();
        break;
      case 'game_over':
        body = _gameOver();
        break;
      default:
        body = const Center(child: CircularProgressIndicator());
    }

    return MundasScaffold(
      title: 'غرفة ${room.code}',
      showBack: false,
      gameExit: true,
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 4),
          child: Icon(
            error == null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: error == null ? MundasColors.primary : MundasColors.coral,
          ),
        ),
      ],
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(key: ValueKey(room.phase), child: body),
      ),
    );
  }

  Widget _role() {
    final secret = room.amImposter ? 'مندس' : (room.secretWord ?? '...');
    final revealColor =
        room.amImposter ? MundasColors.coral : MundasColors.primary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 4),
          child: Column(
            children: [
              Text(
                me?.name ?? 'دورك',
                style: const TextStyle(fontSize: 34),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 7),
              const Text(
                'اجعل الشاشة أمامك وحدك 👀',
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
                  key: ValueKey(
                    'online-secret-${widget.identity.playerId}',
                  ),
                  secret: secret,
                  revealColor: revealColor,
                  onSeen: () {
                    if (mounted) setState(() => roleSeen = true);
                  },
                  onDraggingChanged: (value) {
                    if (mounted) setState(() => _roleDragging = value);
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
                  offset: roleSeen && !_roleDragging
                      ? Offset.zero
                      : const Offset(0, .35),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: roleSeen && !_roleDragging ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !roleSeen || _roleDragging,
                      child: MundasButton(
                        label: busy ? 'لحظة...' : 'فهمت دوري',
                        icon: Icons.check_rounded,
                        onPressed:
                            busy ? null : () => _action('role_seen'),
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
  }

  Widget _drawing() {
    final turn = room.playerById(room.turnPlayerId);
    final mine = room.turnPlayerId == widget.identity.playerId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: MundasColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${room.turnIndex + 1}',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mine
                          ? 'حان دورك للرسم'
                          : '${turn?.name ?? 'لاعب'} يرسم الآن',
                      style: const TextStyle(fontSize: 20),
                    ),
                    Text(
                      mine
                          ? 'أضف تلميحًا واحدًا ذكيًا'
                          : 'يظهر الرسم لديكم مباشرة',
                      style: const TextStyle(
                        color: MundasColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: MultiplayerDrawingPad(
              remoteStrokes: _fastStrokes,
              remoteLiveStroke: _fastLiveStroke,
              enabled: mine && !busy,
              onLiveStroke: (stroke) async {
                // بث الخط الجاري قبل رفع الإصبع، حتى يراه الجميع مباشرة.
                await service.action(
                  widget.identity,
                  'draw_live',
                  {'stroke': stroke},
                );
              },
              onStroke: (stroke) async {
                await service.action(
                  widget.identity,
                  'draw_stroke',
                  {'stroke': stroke},
                );
                await _poll();
              },
            ),
          ),
          if (mine) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: MundasButton(
                label: 'أنهيت دوري',
                icon: Icons.check_rounded,
                onPressed: busy ? null : () => _action('finish_turn'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _discussion() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🗣️', style: TextStyle(fontSize: 72)),
                const Text('وقت النقاش', style: TextStyle(fontSize: 34)),
                const SizedBox(height: 8),
                const Text(
                  'ناقشوا الرسومات من دون ذكر الكلمة السرية. من تعتقدون أنه المندس؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MundasColors.muted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                if (isHost)
                  SizedBox(
                    width: double.infinity,
                    child: MundasButton(
                      label: 'ابدأ التصويت',
                      icon: Icons.how_to_vote_rounded,
                      onPressed: busy ? null : () => _action('start_voting'),
                    ),
                  )
                else
                  const Text(
                    'في انتظار المضيف لبدء التصويت…',
                    style: TextStyle(color: MundasColors.muted),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _voting() {
    final already = me?.voted == true;
    final allowed = room.runoffCandidateIds.isEmpty
        ? room.players
        : room.players
            .where((p) => room.runoffCandidateIds.contains(p.id))
            .toList();

    return Padding(
      padding: const EdgeInsets.all(18),
      child: already
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✅', style: TextStyle(fontSize: 62)),
                  SizedBox(height: 10),
                  Text('تم تسجيل صوتك', style: TextStyle(fontSize: 27)),
                  SizedBox(height: 6),
                  Text(
                    'في انتظار بقية اللاعبين...',
                    style: TextStyle(color: MundasColors.muted),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                const Text('من هو المندس؟', style: TextStyle(fontSize: 28)),
                if (room.runoffCandidateIds.isNotEmpty)
                  const Text(
                    'تصويت فاصل بين المتعادلين',
                    style: TextStyle(color: MundasColors.coral),
                  ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 1.22,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: allowed
                        .where((p) => p.id != widget.identity.playerId)
                        .map((p) {
                      final on = selectedVote == p.id;
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => selectedVote = p.id);
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 170),
                          decoration: BoxDecoration(
                            color: on
                                ? MundasColors.primaryLight
                                : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: on
                                  ? MundasColors.primary
                                  : MundasColors.line,
                              width: on ? 2.5 : 1.5,
                            ),
                            boxShadow: on
                                ? const [
                                    BoxShadow(
                                      color: MundasColors.shadow,
                                      offset: Offset(0, 5),
                                      blurRadius: 0,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ['🕵️','🦊','🐼','🐯','🐸','🦝','🐧','🐻']
                                    [p.avatar % 8],
                                style: const TextStyle(fontSize: 38),
                              ),
                              Text(p.name, style: const TextStyle(fontSize: 18)),
                              if (on)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: MundasColors.primary,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: MundasButton(
                    label: 'تأكيد التصويت',
                    icon: Icons.how_to_vote_rounded,
                    onPressed: selectedVote == null || busy
                        ? null
                        : () => _action(
                              'vote',
                              {'target_player_id': selectedVote},
                            ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _reveal() {
    final accused = room.playerById(room.accusedPlayerId);
    final isImposter = room.accusedIsImposter ?? false;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              SuspenseReveal(
                key: ValueKey('reveal-${room.accusedPlayerId}'),
                accusedName: accused?.name ?? '...',
                isImposter: isImposter,
                onRevealed: () {
                  if (mounted) setState(() => revealDone = true);
                },
              ),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: !revealDone
                    ? const Text(
                        'يتم الآن التحقق... 👀',
                        key: ValueKey('waiting'),
                        style: TextStyle(color: MundasColors.muted),
                      )
                    : isHost
                        ? SizedBox(
                            key: const ValueKey('host-continue'),
                            width: double.infinity,
                            child: MundasButton(
                              label: isImposter
                                  ? 'الفرصة الأخيرة للمندس'
                                  : 'اكشف المندس الحقيقي',
                              icon: Icons.arrow_forward_rounded,
                              color: isImposter
                                  ? MundasColors.coral
                                  : MundasColors.primary,
                              onPressed: busy
                                  ? null
                                  : () => _action('reveal_result'),
                            ),
                          )
                        : const Text(
                            'في انتظار المضيف لمتابعة الجولة…',
                            key: ValueKey('guest-wait'),
                            style: TextStyle(color: MundasColors.muted),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imposterReveal() {
    final imposterName = room.imposterName?.trim().isNotEmpty == true
        ? room.imposterName!
        : 'المندس';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              ImposterWheelReveal(
                key: ValueKey('imposter-wheel-${room.imposterPlayerId}'),
                playerNames: room.players.map((p) => p.name).toList(),
                imposterName: imposterName,
                onFinished: () {
                  if (mounted) {
                    setState(() => imposterWheelFinished = true);
                  }
                },
              ),
              const SizedBox(height: 22),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                opacity: imposterWheelFinished ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !imposterWheelFinished,
                  child: isHost
                      ? SizedBox(
                          width: double.infinity,
                          child: MundasButton(
                            label: 'عرض نتيجة الجولة',
                            icon: Icons.arrow_forward_rounded,
                            color: MundasColors.coral,
                            onPressed: busy
                                ? null
                                : () => _action('finish_imposter_reveal'),
                          ),
                        )
                      : const Text(
                          'في انتظار المضيف لعرض النتيجة…',
                          style: TextStyle(color: MundasColors.muted),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guess() {
    final imposterLabel = room.imposterName?.trim().isNotEmpty == true
        ? room.imposterName!
        : 'المندس';

    if (!room.amImposter) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🕵️', style: TextStyle(fontSize: 70)),
            const SizedBox(height: 10),
            Text(
              '$imposterLabel هو المندس!',
              style: const TextStyle(fontSize: 29, color: MundasColors.coral),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'لديه فرصة أخيرة لاختيار الكلمة السرية',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'في انتظار اختياره…',
              style: TextStyle(color: MundasColors.muted),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              const Text('🕵️', style: TextStyle(fontSize: 72)),
              Text(
                '$imposterLabel، ما الكلمة السرية؟',
                style: const TextStyle(fontSize: 30),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'الفئة: ${room.categoryEmoji ?? ''} ${room.categoryName ?? ''}',
                style: const TextStyle(color: MundasColors.muted),
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر إجابة واحدة من الخيارات الستة',
                style: TextStyle(color: MundasColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.15,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: room.imposterChoices.length,
                itemBuilder: (context, index) {
                  final option = room.imposterChoices[index];
                  final active = selectedGuess == option;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => selectedGuess = option);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? MundasColors.coral : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? MundasColors.ink : MundasColors.line,
                          width: active ? 2.4 : 1.4,
                        ),
                        boxShadow: active
                            ? const [BoxShadow(color: MundasColors.shadow, offset: Offset(0, 5), blurRadius: 0)]
                            : null,
                      ),
                      child: Text(
                        option,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? Colors.white : MundasColors.ink,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: MundasButton(
                  label: 'تأكيد الاختيار',
                  icon: Icons.psychology_alt_rounded,
                  color: MundasColors.coral,
                  onPressed: selectedGuess == null || busy
                      ? null
                      : () => _action('imposter_guess', {'guess': selectedGuess}),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameOver() {
    final imposterWins = room.winner == 'imposter';
    final imposterName = room.imposterName?.trim().isNotEmpty == true
        ? room.imposterName!
        : 'المندس';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Text(
                imposterWins ? '😎' : '🎉',
                style: const TextStyle(fontSize: 86),
              ),
              Text(
                imposterWins ? 'المندس فاز!' : 'الطاقم فاز!',
                style: TextStyle(
                  fontSize: 40,
                  color: imposterWins
                      ? MundasColors.coral
                      : MundasColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8E5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: MundasColors.coral, width: 2),
                ),
                child: Column(
                  children: [
                    const Text(
                      'المندس كان',
                      style: TextStyle(color: MundasColors.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      imposterName,
                      style: const TextStyle(
                        color: MundasColors.coral,
                        fontSize: 34,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              MundasCard(
                child: Column(
                  children: [
                    const Text(
                      'الكلمة السرية',
                      style: TextStyle(color: MundasColors.muted),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      room.secretWord ?? 'تظهر بعد نهاية الجولة',
                      style: const TextStyle(fontSize: 31),
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 26),
                    Text(
                      '${room.categoryEmoji ?? ''} ${room.categoryName ?? ''}',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (isHost)
                SizedBox(
                  width: double.infinity,
                  child: MundasButton(
                    label: 'جولة جديدة بنفس الغرفة',
                    icon: Icons.refresh_rounded,
                    onPressed: busy ? null : () => _action('replay'),
                  ),
                )
              else
                const Text(
                  'في انتظار المضيف لبدء الجولة التالية…',
                  style: TextStyle(color: MundasColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
