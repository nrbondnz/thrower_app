import '../scoring/game_type.dart';
import '../scoring/match.dart';

/// One finished game of Play, as kept in the history (game-history story,
/// Nigel 2026-10-16): when it ended, how it was played and each player's
/// round totals. Totals and the winner are worked out from the rounds, so
/// they can't disagree with them. Since version 2 (named-players story,
/// 2026-10-19) also each player's name, if they had one; since version 3
/// (more-game-types story, 2026-10-20) the [type] of game. Immutable.
class GameRecord {
  const GameRecord({
    required this.id,
    required this.finishedAt,
    required this.mode,
    required this.rounds,
    required this.players,
    this.names = const [],
    this.recording,
    this.type = GameType.scoring,
    this.knives,
  });

  /// [match], finished at [at]; [recording] names the Live test recording it
  /// was played on (null for the camera).
  factory GameRecord.fromMatch(Match match, {required DateTime at, String? recording}) => GameRecord(
    id: '${at.microsecondsSinceEpoch}',
    finishedAt: at,
    mode: match.mode,
    rounds: match.maxRounds,
    players: [
      for (final g in match.players) [for (final r in g.rounds) r.total],
    ],
    names: match.names,
    recording: recording,
    type: match.type,
    knives: [
      for (final g in match.players)
        [
          for (final r in g.rounds) [for (final t in r.throws) t.score],
        ],
    ],
  );

  /// The format [toJson] writes; [fromJson] reads this version and earlier
  /// ones (version 1 had no names; versions 1 and 2 only Scoring games).
  static const version = 3;

  /// Unique within the history (when it finished, in microseconds).
  final String id;
  final DateTime finishedAt;
  final PlayMode mode;

  /// The game's length in rounds (one of [GameType.roundChoices]).
  final int rounds;

  /// Each player's round totals, Player 1 first.
  final List<List<int>> players;

  /// Each player's name, or null (or missing) for none: games kept before
  /// version 2 have none.
  final List<String?> names;

  /// The Live test recording it was played on, or null for the camera.
  final String? recording;

  /// Which game it was: Scoring for games kept before version 3.
  final GameType type;

  /// Each knife's score, by player then round (app-design story,
  /// 2026-10-23, for the stats: `ThrowStats`). Null for a game kept before
  /// then, which has only its round totals. An extra field, so the format's
  /// [version] is unchanged: older builds read the game and ignore it.
  final List<List<List<int>>>? knives;

  /// [player]'s name, or "Player N" without one.
  String nameOf(int player) => names.elementAtOrNull(player) ?? playerNumber(player);

  bool get liveTest => recording != null;

  List<int> get totals => [for (final p in players) p.fold(0, (a, b) => a + b)];

  /// Finished with Finish game before its last round (as far as the record
  /// shows: fewer rounds than [rounds] for someone).
  bool get finishedEarly => players.any((p) => p.length < rounds);

  /// The rounds the result was judged on (as `Match.countedRounds`): as
  /// many as every player played.
  int get countedRounds => players.map((p) => p.length).reduce((a, b) => a < b ? a : b);

  /// Each player's total over the [countedRounds].
  List<int> get countedTotals => [for (final p in players) p.take(countedRounds).fold(0, (a, b) => a + b)];

  /// The winner (0 for Player 1) of a two-player game, on the
  /// [countedTotals]; null for one player or a draw (as `Match.winner`).
  int? get winner {
    if (players.length < 2) return null;
    final t = countedTotals;
    final best = t.reduce((a, b) => a > b ? a : b);
    return t.where((x) => x == best).length == 1 ? t.indexOf(best) : null;
  }

  bool get draw => players.length > 1 && winner == null;

  Map<String, Object?> toJson() => {
    'id': id,
    'finishedAt': finishedAt.toUtc().toIso8601String(),
    'mode': mode.name,
    'rounds': rounds,
    'players': players,
    if (names.any((n) => n != null)) 'names': names,
    if (recording != null) 'recording': recording,
    // Written only for the newer types, so a Scoring game stays as
    // version 2 wrote it.
    if (type != GameType.scoring) 'type': type.name,
    'knives': ?knives,
  };

  /// Throws [FormatException] if [json] isn't a record this version can
  /// read.
  factory GameRecord.fromJson(Object? json) {
    if (json is! Map<String, Object?>) throw const FormatException('a game is not an object');
    T field<T>(String name) {
      final v = json[name];
      if (v is! T) throw FormatException('a game\'s "$name" is missing or the wrong type');
      return v;
    }

    final modeName = field<String>('mode');
    final mode = PlayMode.values.where((m) => m.name == modeName).firstOrNull;
    if (mode == null) throw FormatException('unknown mode "$modeName"');
    final players = [
      for (final p in field<List<Object?>>('players'))
        if (p is List<Object?>)
          [for (final r in p) r is int ? r : throw const FormatException('a round total is not a number')]
        else
          throw const FormatException('a player is not a list of rounds'),
    ];
    if (players.length != mode.players) throw FormatException('${players.length} players for $modeName');
    final names = switch (json['names']) {
      null => const <String?>[],
      final List<Object?> list when list.length == players.length && list.every((n) => n == null || n is String) => [
        for (final n in list) cleanName(n as String?),
      ],
      _ => throw const FormatException('"names" is not a name (or null) per player'),
    };
    final type = switch (json['type']) {
      null => GameType.scoring,
      final String name =>
        GameType.values.where((t) => t.name == name).firstOrNull ??
            (throw FormatException('unknown game type "$name"')),
      _ => throw const FormatException('"type" is not a game type'),
    };
    // Each knife's score: a game kept before 2026-10-23 has none, and one
    // that can't be read loses them, not the game.
    List<List<List<int>>>? knives;
    try {
      knives = switch (json['knives']) {
        final List<Object?> ps when ps.length == players.length => [
          for (final p in ps)
            [
              for (final r in p as List<Object?>) [for (final k in r as List<Object?>) k as int],
            ],
        ],
        _ => null,
      };
    } on TypeError {
      knives = null;
    }
    return GameRecord(
      knives: knives,
      id: field<String>('id'),
      finishedAt:
          DateTime.tryParse(field<String>('finishedAt'))?.toLocal() ??
          (throw const FormatException('finishedAt is not a date')),
      mode: mode,
      rounds: field<int>('rounds'),
      players: players,
      names: names,
      recording: json['recording'] is String ? json['recording'] as String : null,
      type: type,
    );
  }
}
