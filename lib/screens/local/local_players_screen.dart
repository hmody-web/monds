import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_config.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../models/player.dart';
import '../../services/player_name_store.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_scaffold.dart';
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
      return const MundasScaffold(
        title: 'من سيلعب؟',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return MundasScaffold(
      title: 'من سيلعب؟',
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: SizedBox(
          width: double.infinity,
          child: MundasButton(
            label: 'التالي',
            icon: Icons.arrow_back_rounded,
            onPressed: _next,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        children: [
          const Text('أضف أسماء اللاعبين', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            '${AppConfig.minPlayers} إلى ${AppConfig.maxPlayers} لاعبين • الجهاز ينتقل بينهم',
            style: const TextStyle(color: MundasColors.muted),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < _controllers.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MundasColors.line, width: 1.5),
              ),
              child: Row(
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
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: _focusNodes[i].hasFocus ? '' : 'لاعب ${i + 1}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _controllers.length > AppConfig.minPlayers
                        ? () => _remove(i)
                        : null,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          if (_controllers.length < AppConfig.maxPlayers)
            OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة لاعب'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                side: const BorderSide(color: MundasColors.primary, width: 1.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
