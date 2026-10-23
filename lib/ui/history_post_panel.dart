import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/game_record.dart';
import '../history/post_status.dart';
import '../leaderboard/leaderboard_service.dart';
import '../providers.dart';
import '../scoring/game_type.dart';
import 'post_score_panel.dart';

/// A kept session's leaderboard status on History's list: "Can be posted",
/// "Posted" or "Cannot be posted" (posting-from-history story, Nigel
/// 2026-10-23), with "Test" for a test session.
class PostStatusLabel extends ConsumerWidget {
  const PostStatusLabel({super.key, required this.game});

  final GameRecord game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = postStatusOf(game, ref.read(clockProvider)(), testTools: ref.read(testToolsProvider));
    final (icon, colour) = switch (status.state) {
      PostState.canPost => (Icons.upload_outlined, theme.colorScheme.primary),
      PostState.posted => (Icons.emoji_events, const Color(0xFF16A34A)),
      PostState.cannotPost => (Icons.block, theme.colorScheme.onSurfaceVariant),
    };
    return Row(
      key: Key('historyStatus-${game.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colour),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            game.test ? 'Test · ${status.label}' : status.label,
            style: theme.textTheme.labelMedium?.copyWith(color: colour, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// On a kept session's page: its leaderboard status and why; and for one
/// that can be posted, **Post score** (on a phone with a leaderboard: the
/// iPhone), asking "I threw from 3 m" for a normal session. A post marks the
/// kept session Posted.
class HistoryPostPanel extends ConsumerStatefulWidget {
  const HistoryPostPanel({super.key, required this.game});

  final GameRecord game;

  @override
  ConsumerState<HistoryPostPanel> createState() => _HistoryPostPanelState();
}

class _HistoryPostPanelState extends ConsumerState<HistoryPostPanel> {
  late GameRecord _game = widget.game;
  var _at3m = false;
  var _posting = false;
  String? _message;

  Future<void> _post(LeaderboardService service) async {
    // Read before waiting: the page may be left while the post is going,
    // and a post that went must still be kept as Posted (never posted twice).
    final history = ref.read(gameHistoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _posting = true;
      _message = null;
    });
    String? message;
    try {
      if (!await service.signIn()) {
        message = "Sign in to Game Center (in the iPhone's Settings) to post, then try again.";
      } else {
        await service.submit(leaderboardFor(_game), _game.totals.single);
        final posted = _game.markedPosted();
        try {
          await history.add(posted);
        } catch (_) {
          // Posted all the same; History may say "Can be posted" until it's kept.
        }
        container.invalidate(keptGamesProvider);
        _game = posted;
        message = 'Posted to the leaderboard: ${posted.totals.single}.';
      }
    } catch (_) {
      message = "Couldn't post the score. Check the signal and try again.";
    }
    if (!mounted) return;
    setState(() {
      _posting = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = ref.watch(leaderboardServiceProvider);
    final status = postStatusOf(_game, ref.read(clockProvider)(), testTools: ref.read(testToolsProvider));
    final askDistance = _game.type != GameType.ranked;
    return Card(
      key: const Key('historyPostPanel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PostStatusLabel(game: _game),
            if (status.reason != null) ...[
              const SizedBox(height: 4),
              Text('Why: ${status.reason}.', key: const Key('historyPostReason')),
            ],
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, key: const Key('historyPostMessage')),
            ],
            if (status.state == PostState.canPost) ...[
              if (service == null) ...[
                const SizedBox(height: 4),
                Text(
                  'Posting is on the iPhone for now.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ] else ...[
                if (askDistance) ThreeMetreTick(value: _at3m, onChanged: (v) => setState(() => _at3m = v)),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('historyPostScore'),
                  onPressed: _posting || (askDistance && !_at3m) ? null : () => _post(service),
                  child: Text(_posting ? 'Posting…' : 'Post score (${_game.totals.single})'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
