import 'package:flutter/material.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../data/word_repository.dart';
import '../../models/game_category.dart';
import '../../models/local_game_session.dart';
import '../../models/player.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_scaffold.dart';
import 'role_reveal_screen.dart';

class LocalCategoriesScreen extends StatefulWidget {
  final List<Player> players;
  const LocalCategoriesScreen({super.key, required this.players});

  @override
  State<LocalCategoriesScreen> createState() => _LocalCategoriesScreenState();
}

class _LocalCategoriesScreenState extends State<LocalCategoriesScreen> {
  final _repo = WordRepository();
  final Set<String> _selected = {};

  void _start(List<GameCategory> categories) {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر فئة واحدة على الأقل')));
      return;
    }
    final selected = categories.where((e) => _selected.contains(e.slug)).toList();
    final session = LocalGameSession(players: widget.players, selectedCategories: selected);
    Navigator.push(context, mundasRoute(RoleRevealScreen(session: session)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GameCategory>>(
      future: _repo.loadCategories(),
      builder: (context, snap) {
        final categories = snap.data;
        return MundasScaffold(
          title: 'اختيار الفئات',
          bottom: categories == null
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: MundasButton(label: 'ابدأ الجولة', icon: Icons.play_arrow_rounded, onPressed: () => _start(categories)),
                  ),
                ),
          child: categories == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('شنو نوع الكلمات؟', style: TextStyle(fontSize: 27)),
                                const SizedBox(height: 4),
                                Text('${_selected.length} محددة من ${categories.length}', style: const TextStyle(color: MundasColors.muted)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              if (_selected.length == categories.length) {
                                _selected.clear();
                              } else {
                                _selected
                                  ..clear()
                                  ..addAll(categories.map((e) => e.slug));
                              }
                            }),
                            child: Text(_selected.length == categories.length ? 'إلغاء الكل' : 'تحديد الكل'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.55,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, i) {
                          final c = categories[i];
                          final selected = _selected.contains(c.slug);
                          return GestureDetector(
                            onTap: () => setState(() => selected ? _selected.remove(c.slug) : _selected.add(c.slug)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: selected ? MundasColors.primaryLight : Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: selected ? MundasColors.primary : MundasColors.line, width: selected ? 2.2 : 1.4),
                                boxShadow: selected ? const [BoxShadow(color: MundasColors.shadow, offset: Offset(0, 4), blurRadius: 0)] : null,
                              ),
                              child: Row(
                                children: [
                                  Text(c.emoji, style: const TextStyle(fontSize: 28)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(c.nameAr, style: const TextStyle(fontSize: 16), maxLines: 2)),
                                  if (selected) const Icon(Icons.check_circle_rounded, color: MundasColors.primary, size: 22),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
