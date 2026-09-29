import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_config.dart';
import '../../core/nav.dart';
import '../../widgets/arcade_game_shell.dart';
import '../../models/player.dart';
import '../../services/player_name_store.dart';
import 'local_categories_screen.dart';

class LocalPlayersScreen extends StatefulWidget {
  const LocalPlayersScreen({super.key});

  @override
  State<LocalPlayersScreen> createState() => _LocalPlayersScreenState();
}

class _LocalPlayersScreenState extends State<LocalPlayersScreen> {
  final _uuid = const Uuid();
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  final avatars = ['🕵️','😎','🤠','🥸','🤓','😺','🐼','🦊','🐸','🐯','🐧','🐻'];
  Timer? _saveTimer;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSavedNames();
  }

  Future<void> _loadSavedNames() async {
    final saved = await PlayerNameStore.loadLocalNames();
    if (!mounted) return;

    final wanted = saved.length < AppConfig.minPlayers
        ? AppConfig.minPlayers
        : (saved.length > AppConfig.maxPlayers
            ? AppConfig.maxPlayers
            : saved.length);

    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _controllers
      ..clear()
      ..addAll(List.generate(wanted, (i) {
        final value = i < saved.length ? saved[i].trim() : '';
        return TextEditingController(text: value);
      }));
    _focusNodes
      ..clear()
      ..addAll(List.generate(wanted, (_) {
        final node = FocusNode();
        node.addListener(() {
          if (mounted) setState(() {});
        });
        return node;
      }));

    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _persistNames();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _persistNames);
  }

  void _persistNames() {
    unawaited(
      PlayerNameStore.saveLocalNames(
        _controllers.map((e) => e.text.trim()).toList(growable: false),
      ),
    );
  }

  void _add() {
    if (_controllers.length >= AppConfig.maxPlayers) return;
    final node = FocusNode();
    node.addListener(() {
      if (mounted) setState(() {});
    });
    setState(() {
      _controllers.add(TextEditingController());
      _focusNodes.add(node);
    });
    _scheduleSave();
  }

  void _remove(int index) {
    if (_controllers.length <= AppConfig.minPlayers) return;
    final c = _controllers.removeAt(index);
    final f = _focusNodes.removeAt(index);
    c.dispose();
    f.dispose();
    setState(() {});
    _scheduleSave();
  }

  void _next() {
    final names = List.generate(_controllers.length, (i) {
      final typed = _controllers[i].text.trim();
      return typed.isEmpty ? 'لاعب ${i + 1}' : typed;
    });

    _persistNames();

    final players = List.generate(
      names.length,
      (i) => Player(
        id: _uuid.v4(),
        name: names[i],
        avatar: i % avatars.length,
      ),
    );
    Navigator.push(
      context,
      mundasRoute(LocalCategoriesScreen(players: players)),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const ArcadeGameShell(
        title: 'خمن من الرسم',
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFC547)),
        ),
      );
    }

    return ArcadeGameShell(
      title: 'خمن من الرسم',
      bottom: ArcadePrimaryButton(
        label: 'التالي',
        icon: Icons.arrow_back_rounded,
        onPressed: _next,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        physics: const BouncingScrollPhysics(),
        children: [
          const Text(
            'أسماء اللاعبين',
            style: TextStyle(
              fontFamily: 'PCB',
              color: Color(0xFFFFC547),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < _controllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ArcadePanel(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF24303B),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        avatars[i % avatars.length],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        maxLength: 18,
                        onChanged: (_) => _scheduleSave(),
                        style: const TextStyle(color: Colors.white),
                        cursorColor: const Color(0xFFFFC547),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: _focusNodes[i].hasFocus
                              ? ''
                              : 'لاعب ${i + 1}',
                          hintStyle: const TextStyle(color: Color(0xFF9299A3)),
                          filled: true,
                          fillColor: const Color(0xFF0B1118),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _controllers.length > AppConfig.minPlayers
                          ? () => _remove(i)
                          : null,
                      color: const Color(0xFFFF6A5E),
                      disabledColor: const Color(0xFF555B63),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
          if (_controllers.length < AppConfig.maxPlayers)
            OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة لاعب'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFC547),
                minimumSize: const Size.fromHeight(54),
                side: const BorderSide(color: Color(0xFF747B84), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
