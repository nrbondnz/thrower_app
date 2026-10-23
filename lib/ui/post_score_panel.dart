import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../leaderboard/leaderboard_service.dart';
import '../providers.dart';
import 'leaderboard_table_screen.dart';
import '../scoring/game_type.dart';

/// At the end of a full ranked game (`Match.postable`), on a phone that can
/// post ([leaderboardServiceProvider]): **Post score**, then whether it went;
/// and **View leaderboard**. Nothing otherwise (e.g. on Android: backlog
/// #21). Story-checkpoint-game-center-scores, Nigel 2026-10-22.
///
/// A normal 5 × 3 game can be posted too (posting-from-history story, Nigel
/// 2026-10-23); Post score then waits for "I threw from 3 m" (Ranked's
/// setup already asked).
class PostScorePanel extends ConsumerStatefulWidget {
  const PostScorePanel({super.key});

  @override
  ConsumerState<PostScorePanel> createState() => _PostScorePanelState();
}

class _PostScorePanelState extends ConsumerState<PostScorePanel> {
  var _at3m = false;

  @override
  Widget build(BuildContext context) {
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
    final askDistance = match.type != GameType.ranked && canTap;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (line != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(line, key: const Key('postScoreLine'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
          ),
        if (askDistance) ThreeMetreTick(value: _at3m, onChanged: (v) => setState(() => _at3m = v), dark: true),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            if (canTap)
              FilledButton(
                key: const Key('postScore'),
                onPressed: askDistance && !_at3m ? null : ref.read(scorePostProvider.notifier).post,
                child: Text(post == ScorePost.ready ? 'Post score ($total)' : 'Try again'),
              ),
            OutlinedButton(
              key: const Key('viewLeaderboard'),
              // The week's tables (backlog #22).
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LeaderboardTableScreen(board: Leaderboard.ranked3m)),
              ),
              child: const Text('View leaderboard'),
            ),
          ],
        ),
      ],
    );
  }

}

/// Opens the leaderboard, signing in to Game Center first; says so if it
/// can't. From the end of a ranked game, and Throw → Leaderboard.
Future<void> viewLeaderboard(BuildContext context, LeaderboardService service,
    {Leaderboard board = Leaderboard.ranked3m}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await service.signIn()) {
        await service.show(board);
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

/// "I threw from 3 m": asked before a normal session is posted (Ranked's
/// setup already asks). Nigel, 2026-10-23.
class ThreeMetreTick extends StatelessWidget {
  const ThreeMetreTick({super.key, required this.value, required this.onChanged, this.dark = false});

  final bool value;
  final ValueChanged<bool> onChanged;

  /// On a camera screen's black panel.
  final bool dark;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        key: const Key('postAt3m'),
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        title: Text(
          'I threw from $rankedDistance m (board to throwing line)',
          style: dark ? const TextStyle(color: Colors.white) : null,
        ),
      );
}
