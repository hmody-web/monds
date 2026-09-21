import 'dart:math';
import 'drawing_stroke.dart';
import 'game_category.dart';
import 'player.dart';

class LocalGameSession {
  final List<Player> players;
  final List<GameCategory> selectedCategories;
  final Random _random;

  late GameCategory category;
  late String secretWord;
  late int imposterIndex;

  int revealIndex = 0;
  int drawIndex = 0;
  double turnInk = 1;
  final List<DrawingStroke> strokes = [];
  final Map<int, int> votes = {};
  List<int>? runoffCandidates;
  int? accusedIndex;
  bool? guessCorrect;

  LocalGameSession({
    required this.players,
    required this.selectedCategories,
    Random? random,
  }) : _random = random ?? Random.secure() {
    startRound();
  }

  void startRound() {
    category = selectedCategories[_random.nextInt(selectedCategories.length)];
    secretWord = category.words[_random.nextInt(category.words.length)];
    imposterIndex = _random.nextInt(players.length);
    revealIndex = 0;
    drawIndex = 0;
    turnInk = 1;
    strokes.clear();
    votes.clear();
    runoffCandidates = null;
    accusedIndex = null;
    guessCorrect = null;
  }

  Player get currentRevealPlayer => players[revealIndex];
  Player get currentDrawer => players[drawIndex];
  bool get currentRevealIsImposter => revealIndex == imposterIndex;
  bool get isLastReveal => revealIndex >= players.length - 1;
  bool get isLastDrawer => drawIndex >= players.length - 1;

  void nextReveal() => revealIndex = (revealIndex + 1).clamp(0, players.length - 1);

  void nextDrawer() {
    if (!isLastDrawer) {
      drawIndex++;
      turnInk = 1;
    }
  }

  void addVote(int voterIndex, int targetIndex) => votes[voterIndex] = targetIndex;

  VoteResolution resolveVotes() {
    final eligibleVotes = runoffCandidates == null
        ? votes.values
        : votes.values.where((target) => runoffCandidates!.contains(target));
    final counts = <int, int>{};
    for (final target in eligibleVotes) {
      counts[target] = (counts[target] ?? 0) + 1;
    }
    if (counts.isEmpty) return const VoteResolution.tie([]);
    final maxVotes = counts.values.reduce(max);
    final leaders = counts.entries.where((e) => e.value == maxVotes).map((e) => e.key).toList();
    if (leaders.length > 1) {
      runoffCandidates = leaders;
      votes.clear();
      return VoteResolution.tie(leaders);
    }
    accusedIndex = leaders.single;
    runoffCandidates = null;
    return VoteResolution.accused(leaders.single);
  }
}

class VoteResolution {
  final int? accusedIndex;
  final List<int> tieCandidates;
  const VoteResolution._({this.accusedIndex, this.tieCandidates = const []});
  const VoteResolution.accused(int index) : this._(accusedIndex: index);
  const VoteResolution.tie(List<int> candidates) : this._(tieCandidates: candidates);
  bool get isTie => accusedIndex == null;
}
