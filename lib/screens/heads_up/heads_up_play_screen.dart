import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/mundas_colors.dart';
import '../../models/game_category.dart';

enum _HeadsUpStage { waiting, countdown, word }

class HeadsUpPlayScreen extends StatefulWidget {
  final List<GameCategory> categories;

  const HeadsUpPlayScreen({
    super.key,
    required this.categories,
  });

  @override
  State<HeadsUpPlayScreen> createState() => _HeadsUpPlayScreenState();
}

class _HeadsUpPlayScreenState extends State<HeadsUpPlayScreen>
    with TickerProviderStateMixin {
  final math.Random _random = math.Random();
  late final AnimationController _pulseController;
  late final AnimationController _hintController;
  late List<_HeadsUpWord> _deck;

  _HeadsUpStage _stage = _HeadsUpStage.waiting;
  _HeadsUpWord? _current;
  int _deckIndex = 0;
  int _countdown = 3;
  int _shownCount = 0;
  int _countdownRun = 0;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
      lowerBound: 0,
      upperBound: 1,
    )..repeat(reverse: true);
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _buildDeck();
    unawaited(_enterLandscapeMode());
  }

  void _buildDeck() {
    _deck = <_HeadsUpWord>[
      for (final category in widget.categories)
        for (final word in category.words)
          _HeadsUpWord(
            word: word,
            categoryName: category.nameAr,
            emoji: category.emoji,
          ),
    ]..shuffle(_random);
    _deckIndex = 0;
  }

  Future<void> _enterLandscapeMode() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [],
      );
    } catch (_) {
      // بعض المنصات مثل الويب تتجاهل أوامر تدوير الشاشة وملء الشاشة.
    }
  }

  Future<void> _restorePortraitMode() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFFF4FAF8),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownRun++;
    _pulseController.dispose();
    _hintController.dispose();
    unawaited(_restorePortraitMode());
    super.dispose();
  }

  Future<void> _handleScreenTap() async {
    if (_leaving || _stage == _HeadsUpStage.countdown) return;

    if (_stage == _HeadsUpStage.waiting) {
      await _startCountdown();
      return;
    }

    _showNextWord();
  }

  Future<void> _startCountdown() async {
    final run = ++_countdownRun;
    setState(() {
      _stage = _HeadsUpStage.countdown;
      _countdown = 3;
    });

    for (var value = 3; value >= 1; value--) {
      if (!mounted || run != _countdownRun) return;
      setState(() => _countdown = value);
      HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (!mounted || run != _countdownRun) return;
    _showNextWord();
  }

  void _showNextWord() {
    if (_deck.isEmpty) return;
    if (_deckIndex >= _deck.length) {
      _buildDeck();
    }

    var next = _deck[_deckIndex++];
    if (_current != null && _deck.length > 1 && next.word == _current!.word) {
      if (_deckIndex >= _deck.length) _buildDeck();
      next = _deck[_deckIndex++];
    }

    HapticFeedback.selectionClick();
    setState(() {
      _current = next;
      _shownCount++;
      _stage = _HeadsUpStage.word;
    });
  }

  Future<void> _requestExit() async {
    if (_leaving) return;

    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: MundasColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(
                color: MundasColors.ink,
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout_rounded, color: MundasColors.coral, size: 34),
              const SizedBox(height: 10),
              const Text('إنهاء اللعبة؟', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 7),
              const Text(
                'ستعود إلى اختيار الفئات.',
                style: TextStyle(color: MundasColors.muted, fontSize: 13.5),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('متابعة اللعب'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: MundasColors.coral),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('إنهاء'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (leave == true && mounted) {
      _leaving = true;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _requestExit();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF315FC0),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleScreenTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _LandscapeBackground(),
              SafeArea(
                minimum: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      child: IconButton(
                        tooltip: 'إنهاء اللعبة',
                        onPressed: _requestExit,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(.17),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded, size: 25),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.13),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(.16)),
                        ),
                        child: Text(
                          _stage == _HeadsUpStage.word
                              ? 'الكلمة $_shownCount'
                              : '${widget.categories.length} فئة',
                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        ),
                      ),
                    ),
                    Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        reverseDuration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: .88, end: 1).animate(animation),
                            child: child,
                          ),
                        ),
                        child: switch (_stage) {
                          _HeadsUpStage.waiting => _WaitingView(
                              key: const ValueKey('waiting'),
                              hintController: _hintController,
                            ),
                          _HeadsUpStage.countdown => _CountdownView(
                              key: ValueKey('countdown-$_countdown'),
                              value: _countdown,
                            ),
                          _HeadsUpStage.word => _WordView(
                              key: ValueKey(_current?.word ?? ''),
                              current: _current!,
                              pulseController: _pulseController,
                            ),
                        },
                      ),
                    ),
                    if (_stage == _HeadsUpStage.word)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.13),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.touch_app_rounded, size: 17, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'اضغط على الشاشة لعرض كلمة جديدة',
                                  style: TextStyle(color: Colors.white, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  final Animation<double> hintController;

  const _WaitingView({super.key, required this.hintController});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: hintController,
              builder: (context, child) {
                final lift = math.sin(hintController.value * math.pi) * 7;
                return Transform.translate(
                  offset: Offset(0, -lift),
                  child: child,
                );
              },
              child: const _PhoneHeadGraphic(),
            ),
            const SizedBox(height: 18),
            const Text(
              'ضع الهاتف على رأسك',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                height: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'اطلب من اللاعب الآخر الضغط على الشاشة لإظهار كلمتك',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(.86),
                fontSize: 16,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 17),
            AnimatedBuilder(
              animation: hintController,
              builder: (context, child) => Transform.scale(
                scale: .98 + (.04 * hintController.value),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC857),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: MundasColors.ink, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: MundasColors.ink,
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded, color: MundasColors.ink, size: 19),
                    SizedBox(width: 7),
                    Text(
                      'اضغط للبدء',
                      style: TextStyle(color: MundasColors.ink, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownView extends StatelessWidget {
  final int value;

  const _CountdownView({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 132,
            height: .8,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'استعد... لا تنظر إلى الشاشة 👀',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _WordView extends StatelessWidget {
  final _HeadsUpWord current;
  final Animation<double> pulseController;

  const _WordView({
    super.key,
    required this.current,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxWidth = math.min(size.width * .78, 760.0);
    final maxHeight = size.height * .55;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(.18)),
          ),
          child: Text(
            '${current.emoji} ${current.categoryName}',
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
          ),
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: pulseController,
          builder: (context, child) {
            final pulse = math.sin(pulseController.value * math.pi);
            return Transform.scale(
              scale: 1 + (.018 * pulse),
              child: child,
            );
          },
          child: Container(
            width: maxWidth,
            height: maxHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: MundasColors.ink, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: MundasColors.ink,
                  offset: Offset(0, 9),
                  blurRadius: 0,
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                current.word,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  color: MundasColors.ink,
                  fontSize: 82,
                  height: .98,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneHeadGraphic extends StatelessWidget {
  const _PhoneHeadGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 88,
              height: 69,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD6B4),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(44),
                  bottom: Radius.circular(24),
                ),
                border: Border.all(color: MundasColors.ink, width: 2.5),
              ),
              child: const Align(
                alignment: Alignment(0, .3),
                child: Icon(Icons.sentiment_satisfied_alt_rounded, color: MundasColors.ink, size: 39),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Transform.rotate(
              angle: -.035,
              child: Container(
                width: 102,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MundasColors.ink, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: MundasColors.ink,
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.question_mark_rounded, color: Color(0xFF3F70D9), size: 25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandscapeBackground extends StatelessWidget {
  const _LandscapeBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF3F70D9)),
        Positioned(
          top: -130,
          right: -70,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(.055),
            ),
          ),
        ),
        Positioned(
          bottom: -160,
          left: -90,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFC857).withOpacity(.10),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeadsUpWord {
  final String word;
  final String categoryName;
  final String emoji;

  const _HeadsUpWord({
    required this.word,
    required this.categoryName,
    required this.emoji,
  });
}
