import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/auth/auth_service.dart';
import 'package:thrower_app/history/game_record.dart';
import 'package:thrower_app/history/test_sessions.dart';
import 'package:thrower_app/history/synced_game_history.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/match.dart';

import '../settings/player_names_test.dart' show MemoryPlayerNamesStore;
import '../ui/account_screen_test.dart' show FakeAuthService;
import 'memory_game_history.dart';

/// A backup in memory: [failing] makes every call throw (no signal).
class MemoryRemoteGames implements RemoteGameStore {
  MemoryRemoteGames([List<GameRecord> games = const []]) : games = {for (final g in games) g.id: g};

  final Map<String, GameRecord> games;
  var failing = false;
  var puts = 0;

  void _check() {
    if (failing) throw Exception('no signal');
  }

  @override
  Future<List<GameRecord>> list() async {
    _check();
    return [...games.values];
  }

  @override
  Future<void> put(GameRecord record) async {
    _check();
    puts++;
    games[record.id] = record;
  }

  @override
  Future<void> remove(String gameId) async {
    _check();
    games.remove(gameId);
  }
}

/// A one-player game that finished on 19 Oct 2026 at 20:[minute].
GameRecord game(int minute, {int score = 5}) => GameRecord(
      id: 'g$minute',
      finishedAt: DateTime(2026, 10, 19, 20, minute),
      mode: PlayMode.solo,
      rounds: 3,
      players: [
        [score, score, score]
      ],
    );

/// App user accounts story, Task 4: the phone's History, backed up while
/// someone is signed in.
void main() {
  late MemoryGameHistory phone;
  late MemoryRemoteGames backup;
  MemoryRemoteGames? signedIn;
  late SyncedGameHistory history;

  setUp(() {
    phone = MemoryGameHistory();
    backup = MemoryRemoteGames();
    signedIn = backup;
    history = SyncedGameHistory(phone, () => signedIn);
  });

  group('signed out', () {
    setUp(() => signedIn = null);

    test('games are kept on the phone only', () async {
      await history.add(game(1));
      expect(phone.games.map((g) => g.id), ['g1']);
      expect(backup.games, isEmpty);
    });

    test('nothing to sync', () async {
      expect(await history.sync(), isNull);
    });
  });

  group('signed in', () {
    test('a kept game is backed up too', () async {
      await history.add(game(1));
      await pumpEventQueue();
      expect(backup.games.keys, ['g1']);
    });

    test('a re-kept game (a score corrected after the end) replaces its backup', () async {
      await history.add(game(1));
      await history.add(game(1, score: 4));
      await pumpEventQueue();
      expect(backup.games['g1']!.totals, [12]);
    });

    test('deleting a game deletes its backup', () async {
      await history.add(game(1));
      await history.delete('g1');
      await pumpEventQueue();
      expect(backup.games, isEmpty);
    });

    test('Clear history clears the backup too', () async {
      await history.add(game(1));
      await history.add(game(2));
      await history.clear();
      await pumpEventQueue();
      expect((phone.games.length, backup.games.length), (0, 0));
    });

    test('no signal: the game is still kept on the phone, and the next sync backs it up', () async {
      backup.failing = true;
      await history.add(game(1));
      await pumpEventQueue();
      expect(phone.games.map((g) => g.id), ['g1']);
      backup.failing = false;
      final result = await history.sync();
      expect((result!.uploaded, result.downloaded), (1, 0));
      expect(backup.games.keys, ['g1']);
    });
  });

  // The known limit (Traceability Agent, 2026-10-19): a delete with no signal
  // isn't remembered, so the next sync brings the game back. Decision for
  // Nigel: keep the limit, or remember pending deletes (tombstones).
  test('known limit: a game deleted with no signal comes back at the next sync', () async {
    await history.add(game(1));
    await pumpEventQueue();
    backup.failing = true;
    await history.delete('g1');
    await pumpEventQueue();
    backup.failing = false;
    await history.sync();
    expect(phone.games.map((g) => g.id), ['g1']);
  });

  group('sync (on signing in)', () {
    test('a new phone gets the backed-up games; the phone\'s own are backed up', () async {
      backup.games['g1'] = game(1);
      phone.games.add(game(2));
      final result = await history.sync();
      expect((result!.downloaded, result.uploaded), (1, 1));
      expect({for (final g in await phone.load()) g.id}, {'g1', 'g2'});
      expect(backup.games.keys.toSet(), {'g1', 'g2'});
    });

    test('twice in a row: nothing more to do', () async {
      backup.games['g1'] = game(1);
      await history.sync();
      final again = await history.sync();
      expect((again!.downloaded, again.uploaded), (0, 0));
    });

    test('no signal: the sync fails, the phone\'s games untouched', () async {
      phone.games.add(game(2));
      backup.failing = true;
      await expectLater(history.sync(), throwsException);
      expect(phone.games.length, 1);
    });
  });

  group('the app\'s backup (providers)', () {
    late ProviderContainer container;
    late MemoryPlayerNamesStore namesBackup;
    late MemoryPlayerNamesStore namesOnPhone;

    ProviderContainer make({AppUser? user = const AppUser(id: 'sub-1', displayName: 'jo@example.com')}) {
      namesBackup = MemoryPlayerNamesStore();
      namesOnPhone = MemoryPlayerNamesStore();
      late final ProviderContainer c;
      c = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(FakeAuthService(user)),
        backupFactoryProvider.overrideWithValue((id) => (
              games: backup,
              names: namesBackup,
              erase: () async {
                for (final g in await backup.list()) {
                  await backup.remove(g.id);
                }
                namesBackup.kept = const [];
              },
            )),
        playerNamesStoreProvider.overrideWithValue(namesOnPhone),
        gameHistoryProvider.overrideWith((ref) => SyncedGameHistory(phone, () => c.read(backupProvider)?.games)),
      ]);
      addTearDown(c.dispose);
      c.listen(backupStatusProvider, (_, _) {});
      return c;
    }

    test('signed in: the backup is the user\'s', () async {
      container = make();
      await pumpEventQueue();
      expect(container.read(backupProvider), isNotNull);
    });

    test('signed out: no backup', () async {
      container = make(user: null);
      await pumpEventQueue();
      expect(container.read(backupProvider), isNull);
      expect(container.read(backupStatusProvider), isA<BackupOff>());
    });

    test('signing in merges the games, and says how it went', () async {
      backup.games['g1'] = game(1);
      phone.games.add(game(2));
      container = make();
      await pumpEventQueue(times: 50);
      final status = container.read(backupStatusProvider);
      expect(status, isA<BackupDone>());
      expect(((status as BackupDone).result.downloaded, status.result.uploaded), (1, 1));
    });

    test('a new phone (no names) takes the backed-up names', () async {
      container = make();
      namesBackup.kept = ['Mark', 'Sam'];
      await pumpEventQueue(times: 50);
      expect(container.read(playerNamesProvider), ['Mark', 'Sam']);
      expect(namesOnPhone.kept, ['Mark', 'Sam']);
    });

    test("the phone's names are backed up; a name changed later too", () async {
      container = make();
      await pumpEventQueue(times: 50);
      container.read(playerNamesProvider.notifier).set(['Jo', 'Sam']);
      await pumpEventQueue();
      expect(namesBackup.kept, ['Jo', 'Sam']);
    });

    test('no signal: the status says so, and Back up now tries again', () async {
      backup.failing = true;
      container = make();
      await pumpEventQueue(times: 50);
      expect(container.read(backupStatusProvider), isA<BackupFailed>());
      backup.failing = false;
      await container.read(backupStatusProvider.notifier).backUpNow();
      expect(container.read(backupStatusProvider), isA<BackupDone>());
    });

    // Task 5.
    test('Delete account: erases the backup, then the account; the phone keeps its games', () async {
      backup.games['g1'] = game(1);
      phone.games.add(game(2));
      container = make();
      await pumpEventQueue(times: 50);
      final auth = container.read(authServiceProvider)! as FakeAuthService;
      await container.read(deleteAccountProvider)();
      expect(backup.games, isEmpty);
      expect(auth.deleted, isTrue);
      expect(phone.games.map((g) => g.id).toSet(), {'g1', 'g2'}, reason: 'merged onto the phone before; kept');
    });

    test('Delete account with no signal: throws, and the account is still there', () async {
      container = make();
      await pumpEventQueue(times: 50);
      backup.failing = true;
      await expectLater(container.read(deleteAccountProvider)(), throwsException);
      expect((container.read(authServiceProvider)! as FakeAuthService).deleted, isFalse);
    });
  });

  // Review Agent, 2026-10-23: test sessions stay on the phone, so they can't
  // reach the user's other phones (an App Store build among them).
  group('test sessions', () {
    final made = makeTestSessions(DateTime(2026, 10, 25, 12));

    test('are not backed up when kept', () async {
      await history.add(made.first);
      await pumpEventQueue();
      expect(backup.games, isEmpty);
    });

    test('are not uploaded by a sync', () async {
      await phone.add(made.first);
      final result = await history.sync();
      expect((result?.uploaded, backup.games.isEmpty), (0, true));
    });

    test('one already in a backup is not brought down', () async {
      backup.games[made.first.id] = made.first;
      await history.sync();
      expect(phone.games, isEmpty);
    });
  });
}
