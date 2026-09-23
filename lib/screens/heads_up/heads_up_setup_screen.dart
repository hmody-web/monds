import 'package:flutter/material.dart';
import '../../core/mundas_colors.dart';
import '../../core/nav.dart';
import '../../data/word_repository.dart';
import '../../models/game_category.dart';
import '../../widgets/mundas_button.dart';
import '../../widgets/mundas_scaffold.dart';
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

    final selected = categories.where((c) => _selected.contains(c.slug)).toList();
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

        return MundasScaffold(
          title: 'خمن اللي براسي',
          bottom: ready
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: MundasButton(
                      label: _selected.isEmpty
                          ? 'اختر فئة للبدء'
                          : 'ابدأ اللعبة (${_selected.length})',
                      icon: Icons.screen_rotation_alt_rounded,
                      color: const Color(0xFF3F70D9),
                      onPressed: _selected.isEmpty ? null : () => _start(categories),
                    ),
                  ),
                )
              : null,
          child: !ready
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                  children: [
                    const _InstructionsHero(),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('اختر الفئات', style: TextStyle(fontSize: 26)),
                              SizedBox(height: 4),
                              Text(
                                'ستُختار الكلمات عشوائيًا من الفئات المحددة.',
                                style: TextStyle(
                                  color: MundasColors.muted,
                                  fontSize: 12.5,
                                ),
                              ),
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
                          child: Text(
                            _selected.length == categories.length
                                ? 'إلغاء الكل'
                                : 'تحديد الكل',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.55,
                        mainAxisSpacing: 11,
                        crossAxisSpacing: 11,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final selected = _selected.contains(category.slug);
                        return _CategoryTile(
                          category: category,
                          selected: selected,
                          onTap: () => setState(() {
                            if (selected) {
                              _selected.remove(category.slug);
                            } else {
                              _selected.add(category.slug);
                            }
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: MundasColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: MundasColors.line),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.people_alt_outlined, color: MundasColors.primaryDark),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'لا يوجد عدد محدد للاعبين. اتفقوا على الأدوار بينكم، ويمكن تشغيل اللعبة حتى مع لاعب واحد.',
                              style: TextStyle(
                                color: MundasColors.primaryDark,
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _InstructionsHero extends StatelessWidget {
  const _InstructionsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF3F70D9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: MundasColors.ink, width: 2),
        boxShadow: const [
          BoxShadow(
            color: MundasColors.ink,
            offset: Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -26,
            top: -38,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC857),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: MundasColors.ink, width: 2),
                    ),
                    child: const Icon(
                      Icons.phone_android_rounded,
                      color: MundasColors.ink,
                      size: 35,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'خمن اللي براسي',
                          style: TextStyle(color: Colors.white, fontSize: 27, height: 1),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'سريعة، بسيطة، وتصلح لأي عدد من اللاعبين.',
                          style: TextStyle(color: Color(0xFFEAF0FF), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _InstructionStep(
                number: '1',
                text: 'اختر الفئات التي تريد اللعب بها.',
              ),
              const SizedBox(height: 10),
              const _InstructionStep(
                number: '2',
                text: 'اضغط «ابدأ اللعبة» وسيصبح الهاتف بالعرض وبملء الشاشة.',
              ),
              const SizedBox(height: 10),
              const _InstructionStep(
                number: '3',
                text: 'ضع الهاتف على رأسك واطلب من اللاعب الآخر الضغط على الشاشة لإظهار الكلمة.',
              ),
              const SizedBox(height: 10),
              const _InstructionStep(
                number: '4',
                text: 'بعد العد التنازلي حاول معرفة الكلمة، ثم اضغطوا لعرض كلمة جديدة.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            number,
            style: const TextStyle(color: Color(0xFF3F70D9), fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final GameCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8EEFF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF3F70D9) : MundasColors.line,
            width: selected ? 2.1 : 1.3,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: MundasColors.shadow,
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                category.nameAr,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, height: 1.15),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: Color(0xFF3F70D9),
              ),
          ],
        ),
      ),
    );
  }
}
