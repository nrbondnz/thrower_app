import '../scoring/match.dart';

/// One finished game of Play, as kept in the history (game-history story,
/// Nigel 2026-10-16): when it ended, how it was played and each player's
/// round totals. Totals and the winner are worked out from the rounds, so
/// they can't disagree with them. Since version 2 (named-players story,
/// 2026-10-19) also each player's name, if they had one. Immutable.
class GameRecord {
  const GameRecord({
    required this.id,
    required this.finishedAt,
    required this.mode,
    required this.rounds,
    required this.players,
    this.names = const [],
    this.recording,
  });

  /// [match], finished at [at]; [recording] names the Live test recording it
  /// was played on (null for the camera).
  factory GameRecord.fromMatch(Match match, {required DateTime at, String? recording}) => GameRecord(
        id: '${at.microsecondsSinceEpoch}',
        finishedAt: at,
        mode: match.mode,
        rounds: match.maxRounds,
        players: [
          for (final g in match.players) [for (final r in g.rounds) r.total]
        ],
        names: match.names,
        recording: recording,
      );

  /// The format [toJson] writes; [fromJson] reads this version and earlier
  /// ones (version 1 had no names).
  static const version = 2;

  /// Unique within the history (when it finished, in microseconds).
  final String id;
  final DateTime finishedAt;
  final PlayMode mode;

  /// The game's length (3, 5 or 9).
  final int rounds;

  /// Each player's round totals, Player 1 first.
  final List<List<int>> players;

  /// Each player's name, or null (or missing) for none: games kept before
  /// version 2 have none.
  final List<String?> names;

  /// The Live test recording it was played on, or null for the camera.
  final String? recording;

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
        if (p is List<Object?>) [for (final r in p) r is int ? r : throw const FormatException('a round total is not a number')]
        else throw const FormatException('a player is not a list of rounds'),
    ];
    if (players.length != mode.players) throw FormatException('${players.length} players for $modeName');
    final names = switch (json['names']) {
      null => const <String?>[],
      final List<Object?> list when list.length == players.length && list.every((n) => n == null || n is String) =>
        [for (final n in list) cleanName(n as String?)],
      _ => throw const FormatException('"names" is not a name (or null) per player'),
    };
    return GameRecord(
      id: field<String>('id'),
      finishedAt: DateTime.tryParse(field<String>('finishedAt'))?.toLocal() ??
          (throw const FormatException('finishedAt is not a date')),
      mode: mode,
      rounds: field<int>('rounds'),
      players: players,
      names: names,
      recording: json['recording'] is String ? json['recording'] as String : null,
    );
  }
}
