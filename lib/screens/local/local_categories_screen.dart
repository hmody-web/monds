import 'package:flutter/material.dart';
import '../../core/nav.dart';
import '../../data/word_repository.dart';
import '../../models/game_category.dart';
import '../../models/local_game_session.dart';
import '../../models/player.dart';
import '../../widgets/arcade_game_shell.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر فئة واحدة على الأقل')),
      );
      return;
    }
    final selected =
        categories.where((e) => _selected.contains(e.slug)).toList();
    final session = LocalGameSession(
      players: widget.players,
      selectedCategories: selected,
    );
    Navigator.push(
      context,
      mundasRoute(RoleRevealScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GameCategory>>(
      future: _repo.loadCategories(),
      builder: (context, snap) {
        final categories = snap.data;
        return ArcadeGameShell(
          title: 'اختيار الفئات',
          bottom: categories == null
              ? null
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          if (_selected.length == categories.length) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(categories.map((e) => e.slug));
                          }
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFC547),
                          side: const BorderSide(color: Color(0xFF747B84)),
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _selected.length == categories.length
                              ? 'إلغاء الكل'
                              : 'تحديد الكل',
                          style: const TextStyle(
                            fontFamily: 'PCB',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ArcadePrimaryButton(
                        label: 'ابدأ',
                        onPressed:
                            _selected.isEmpty ? null : () => _start(categories),
                      ),
                    ),
                  ],
                ),
          child: categories == null
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFC547),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    childAspectRatio: 2.1,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, i) {
                    final c = categories[i];
                    final selected = _selected.contains(c.slug);
                    return ArcadePanel(
                      selected: selected,
                      onTap: () => setState(() => selected
                          ? _selected.remove(c.slug)
                          : _selected.add(c.slug)),
                      child: Row(
                        children: [
                          Text(c.emoji, style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c.nameAr,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF27C38A),
                              size: 22,
                            ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
