import 'package:flutter/material.dart';
import '../../core/nav.dart';
import '../../data/word_repository.dart';
import '../../models/game_category.dart';
import '../../widgets/arcade_game_shell.dart';
import 'heads_up_play_screen.dart';

class HeadsUpSetupScreen extends StatefulWidget {
  const HeadsUpSetupScreen({super.key});

  @override
  State<HeadsUpSetupScreen> createState() => _HeadsUpSetupScreenState();
}

class _HeadsUpSetupScreenState extends State<HeadsUpSetupScreen> {
  final WordRepository _repo = WordRepository();
  final Set<String> _selected = <String>{};

  void _start(List<GameCategory> categories) {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر فئة واحدة على الأقل')),
      );
      return;
    }
    final selected =
        categories.where((c) => _selected.contains(c.slug)).toList();
    Navigator.push(
      context,
      mundasRoute(HeadsUpPlayScreen(categories: selected)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GameCategory>>(
      future: _repo.loadCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data;
        final ready = categories != null;

        return ArcadeGameShell(
          title: 'اختر الفئات',
          bottom: ready
              ? Row(
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
                          side: const BorderSide(color: Color(0xFF7A818A)),
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
                            fontSize: 17,
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
                )
              : null,
          child: !ready
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFC547),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    childAspectRatio: 2.1,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = _selected.contains(category.slug);
                    return ArcadePanel(
                      selected: selected,
                      onTap: () => setState(() {
                        if (selected) {
                          _selected.remove(category.slug);
                        } else {
                          _selected.add(category.slug);
                        }
                      }),
                      child: Row(
                        children: [
                          Text(
                            category.emoji,
                            style: const TextStyle(fontSize: 30),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              category.nameAr,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF27C38A),
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
