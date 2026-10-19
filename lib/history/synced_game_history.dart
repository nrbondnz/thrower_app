import 'dart:async';

import 'game_history.dart';
import 'game_record.dart';

/// Where a signed-in app user's kept games are backed up (accounts Task 4: the
/// Amplify backend's `KeptGame` rows, owned by the user). An interface, like
/// [GameHistory]; tests use a fake.
abstract interface class RemoteGameStore {
  /// Every game backed up for this user.
  Future<List<GameRecord>> list();

  /// Backs up [record] (replacing the copy with its `id`, e.g. after a score
  /// correction re-keeps a finished game).
  Future<void> put(GameRecord record);

  /// Removes the backup of the game with [gameId] (nothing if none).
  Future<void> remove(String gameId);
}

/// How a [SyncedGameHistory.sync] went.
typedef SyncResult = ({int downloaded, int uploaded});

/// The kept games: the phone's own [local] history, the source of truth
/// (offline-first: nothing waits for the network), backed up to [remote] while
/// someone is signed in (null otherwise). Adding, deleting and clearing reach
/// the backup too; a backup that fails (no signal) is left for the next
/// [sync], which merges both ways by game `id`.
///
/// Known limit: a game deleted while signed out (or offline) is still in the
/// backup, so the next sync brings it back.
class SyncedGameHistory implements GameHistory {
  SyncedGameHistory(this.local, this.remote);

  final GameHistory local;

  /// The signed-in user's backup, or null when no one is signed in.
  final RemoteGameStore? Function() remote;

  @override
  Future<List<GameRecord>> load() => local.load();

  @override
  Future<void> add(GameRecord record) async {
    await local.add(record);
    _backUp((r) => r.put(record));
  }

  @override
  Future<void> delete(String id) async {
    await local.delete(id);
    _backUp((r) => r.remove(id));
  }

  /// Clear history clears the backup too: otherwise the next sign-in would
  /// bring every game back.
  @override
  Future<void> clear() async {
    final games = await local.load();
    await local.clear();
    _backUp((r) async {
      for (final g in games) {
        await r.remove(g.id);
      }
    });
  }

  /// Merges the phone's games and the backup: games only in the backup are
  /// kept on the phone (a new phone, or another of the user's phones); games
  /// only on the phone are backed up. Null when no one is signed in. Throws
  /// what the backup throws (no signal): the caller says so and tries later.
  Future<SyncResult?> sync() async {
    final r = remote();
    if (r == null) return null;
    final backedUp = await r.list();
    final onPhone = await local.load();
    final phoneIds = {for (final g in onPhone) g.id};
    final backupIds = {for (final g in backedUp) g.id};
    var downloaded = 0, uploaded = 0;
    for (final g in backedUp.where((g) => !phoneIds.contains(g.id))) {
      await local.add(g);
      downloaded++;
    }
    for (final g in onPhone.where((g) => !backupIds.contains(g.id))) {
      await r.put(g);
      uploaded++;
    }
    return (downloaded: downloaded, uploaded: uploaded);
  }

  /// Runs [change] on the backup if someone is signed in, without waiting
  /// and without failing the phone's own change; [sync] catches up later.
  void _backUp(Future<void> Function(RemoteGameStore) change) {
    final r = remote();
    if (r != null) unawaited(change(r).catchError((Object _) {}));
  }
}
