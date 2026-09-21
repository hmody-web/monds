class GameCategory {
  final String slug;
  final String nameAr;
  final String emoji;
  final List<String> words;

  const GameCategory({
    required this.slug,
    required this.nameAr,
    required this.emoji,
    required this.words,
  });

  factory GameCategory.fromJson(Map<String, dynamic> json) => GameCategory(
        slug: json['slug'] as String,
        nameAr: json['name_ar'] as String,
        emoji: json['emoji'] as String,
        words: (json['words'] as List).cast<String>(),
      );
}
