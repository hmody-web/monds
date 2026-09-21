class Player {
  final String id;
  final String name;
  final int avatar;

  const Player({required this.id, required this.name, required this.avatar});

  Player copyWith({String? name, int? avatar}) => Player(
        id: id,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
      );
}
