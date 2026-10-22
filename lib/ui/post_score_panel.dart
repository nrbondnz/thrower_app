import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../leaderboard/leaderboard_service.dart';
import '../providers.dart';

/// At the end of a full ranked game (`Match.postable`), on a phone that can
/// post ([leaderboardServiceProvider]): **Post score**, then whether it went;
/// and **View leaderboard**. Nothing otherwise (e.g. on Android: backlog
/// #21). Story-checkpoint-game-center-scores, Nigel 2026-10-22.
class PostScorePanel extends ConsumerWidget {
  const PostScorePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(leaderboardServiceProvider);
    final match = ref.watch(gameProvider);
    ref.watch(recordingChoiceProvider);
    final post = ref.watch(scorePostProvider);
    if (service == null || !ref.read(scorePostProvider.notifier).canPost) return const SizedBox.shrink();
    final total = match.players.single.total;
    final line = switch (post) {
      ScorePost.ready => null,
      ScorePost.posting => 'Posting…',
      ScorePost.posted => 'Posted to the leaderboard: $total.',
      ScorePost.signedOut => 'Sign in to Game Center (in the iPhone\'s Settings) to post, then try again.',
      ScorePost.failed => "Couldn't post the score. Check the signal and try again.",
    };
    final canTap = post == ScorePost.ready || post == ScorePost.failed || post == ScorePost.signedOut;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (line != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(line, key: const Key('postScoreLine'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            if (canTap)
              FilledButton(
                key: const Key('postScore'),
                onPressed: ref.read(scorePostProvider.notifier).post,
                child: Text(post == ScorePost.ready ? 'Post score ($total)' : 'Try again'),
              ),
            OutlinedButton(
              key: const Key('viewLeaderboard'),
              onPressed: () => _view(context, service),
              child: const Text('View leaderboard'),
            ),
          ],
        ),
      ],
    );
  }

  /// Opens the leaderboard, signing in to Game Center first; says so if it
  /// can't.
  Future<void> _view(BuildContext context, LeaderboardService service) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await service.signIn()) {
        await service.show(Leaderboard.ranked3m);
        return;
      }
    } catch (_) {
      // Falls through to the message.
    }
    messenger.showSnackBar(const SnackBar(
      key: Key('viewLeaderboardFailed'),
      content: Text("Couldn't open the leaderboard. Sign in to Game Center (in the iPhone's Settings) and try again."),
    ));
  }
}
