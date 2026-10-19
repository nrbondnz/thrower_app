import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';

import '../history/game_record.dart';
import '../history/synced_game_history.dart';
import '../settings/player_names_store.dart';

/// The signed-in user's backup on the Amplify backend (accounts Task 4;
/// `amplify/data/resource.ts`): GraphQL on the `KeptGame` and `PlayerNameList`
/// models, signed with the user's Cognito session (owner-only rows). Not
/// unit-tested: it is Amplify's static API; [SyncedGameHistory] and the
/// names' sync are tested with fakes, and this is checked on the device.
class AmplifyBackup implements RemoteGameStore, PlayerNamesStore {
  AmplifyBackup(this.userId);

  /// The signed-in user's Cognito `sub` (`AppUser.id`).
  final String userId;

  String _gameRowId(String gameId) => '$userId:$gameId';

  Future<Map<String, Object?>> _run(String document, Map<String, Object?> variables) async {
    final response = await Amplify.API
        .query(request: GraphQLRequest<String>(document: document, variables: variables))
        .response;
    if (response.hasErrors) throw ApiOperationException(response.errors.map((e) => e.message).join('; '));
    final data = response.data;
    return data == null ? const {} : jsonDecode(data) as Map<String, Object?>;
  }

  Future<Map<String, Object?>> _mutate(String document, Map<String, Object?> variables) async {
    final response = await Amplify.API
        .mutate(request: GraphQLRequest<String>(document: document, variables: variables))
        .response;
    if (response.hasErrors) throw ApiOperationException(response.errors.map((e) => e.message).join('; '));
    final data = response.data;
    return data == null ? const {} : jsonDecode(data) as Map<String, Object?>;
  }

  /// A row that's already there: create fails with a conditional check.
  static bool _exists(ApiException e) => e.message.contains('ConditionalCheckFailed');

  /// AWSJSON comes back as a JSON string.
  static Object? _json(Object? value) => value is String ? jsonDecode(value) : value;

  @override
  Future<List<GameRecord>> list() async {
    const document = r'''
      query ListKeptGames($nextToken: String) {
        listKeptGames(limit: 1000, nextToken: $nextToken) { items { record } nextToken }
      }''';
    final games = <GameRecord>[];
    String? next;
    do {
      final page = (await _run(document, {'nextToken': next}))['listKeptGames'] as Map<String, Object?>;
      for (final item in (page['items'] as List<Object?>).cast<Map<String, Object?>>()) {
        try {
          games.add(GameRecord.fromJson(_json(item['record'])));
        } on FormatException {
          // A game from a newer app version, or damaged: left in the backup.
        }
      }
      next = page['nextToken'] as String?;
    } while (next != null);
    return games;
  }

  @override
  Future<void> put(GameRecord record) async {
    final input = {
      'id': _gameRowId(record.id),
      'gameId': record.id,
      'finishedAt': record.finishedAt.toUtc().toIso8601String(),
      'record': jsonEncode(record.toJson()),
    };
    try {
      await _mutate(r'mutation C($input: CreateKeptGameInput!) { createKeptGame(input: $input) { id } }', {
        'input': input,
      });
    } on ApiException catch (e) {
      if (!_exists(e)) rethrow;
      await _mutate(r'mutation U($input: UpdateKeptGameInput!) { updateKeptGame(input: $input) { id } }', {
        'input': input,
      });
    }
  }

  @override
  Future<void> remove(String gameId) async {
    await _mutate(r'mutation D($input: DeleteKeptGameInput!) { deleteKeptGame(input: $input) { id } }', {
      'input': {'id': _gameRowId(gameId)},
    });
  }

  /// Erases everything backed up for this user (deleting the account): every
  /// game row, then the names. By row id, without reading the games, so a
  /// game this app can't read (a newer version's) is erased too (Traceability
  /// Agent, 2026-10-19: [list] skips those, which would have left them behind).
  Future<void> erase() async {
    const document = r'''
      query ListKeptGameIds($nextToken: String) {
        listKeptGames(limit: 1000, nextToken: $nextToken) { items { id } nextToken }
      }''';
    final ids = <String>[];
    String? next;
    do {
      final page = (await _run(document, {'nextToken': next}))['listKeptGames'] as Map<String, Object?>;
      ids.addAll([for (final item in (page['items'] as List<Object?>).cast<Map<String, Object?>>()) item['id'] as String]);
      next = page['nextToken'] as String?;
    } while (next != null);
    for (final id in ids) {
      await _mutate(r'mutation D($input: DeleteKeptGameInput!) { deleteKeptGame(input: $input) { id } }', {
        'input': {'id': id},
      });
    }
    try {
      await _mutate(r'mutation D($input: DeletePlayerNameListInput!) { deletePlayerNameList(input: $input) { id } }', {
        'input': {'id': userId},
      });
    } on ApiException catch (e) {
      // No names were ever backed up.
      if (!e.message.contains('ConditionalCheckFailed')) rethrow;
    }
  }

  /// The names backed up for this user, or none.
  @override
  Future<List<String?>> load() async {
    final row = (await _run(r'query G($id: ID!) { getPlayerNameList(id: $id) { names } }', {
      'id': userId,
    }))['getPlayerNameList'];
    if (row is! Map<String, Object?>) return const [];
    final names = _json(row['names']);
    return names is List<Object?> ? [for (final n in names) n is String ? n : null] : const [];
  }

  @override
  Future<void> save(List<String?> names) async {
    final input = {'id': userId, 'names': jsonEncode(names)};
    try {
      await _mutate(r'mutation C($input: CreatePlayerNameListInput!) { createPlayerNameList(input: $input) { id } }', {
        'input': input,
      });
    } on ApiException catch (e) {
      if (!_exists(e)) rethrow;
      await _mutate(r'mutation U($input: UpdatePlayerNameListInput!) { updatePlayerNameList(input: $input) { id } }', {
        'input': input,
      });
    }
  }
}
