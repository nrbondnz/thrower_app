import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/leaderboard/game_center_leaderboard_service.dart';
import 'package:thrower_app/leaderboard/leaderboard_service.dart';

/// The Game Center service against the `games_services` plugin's method
/// channel (no iPhone in a test): what it asks Game Center to do. signIn
/// isn't covered here: it reads the plugin's player stream (an event
/// channel); the device check covers it ([[Device Test Plan]]).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> calls;
  late Object? Function(MethodCall) reply;

  setUp(() {
    calls = [];
    reply = (_) => 'success';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('games_services'),
      (call) async {
        calls.add(call);
        return reply(call);
      },
    );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('games_services'), null),
  );

  test('a score goes to the 3 m leaderboard by its App Store Connect ID', () async {
    await GameCenterLeaderboardService().submit(Leaderboard.ranked3m, 63);
    expect(calls.single.method, 'submitScore');
    expect(calls.single.arguments, containsPair('leaderboardID', 'ranked.3m.5x3'));
    expect(calls.single.arguments, containsPair('value', 63));
  });

  test('a score Game Center refuses (no signal) throws, so Play offers Try again', () async {
    reply = (_) => throw PlatformException(code: 'failed_to_send_score');
    expect(GameCenterLeaderboardService().submit(Leaderboard.ranked3m, 63), throwsA(isA<PlatformException>()));
  });

  test('View leaderboard opens that leaderboard', () async {
    await GameCenterLeaderboardService().show(Leaderboard.ranked3m);
    expect(calls.single.method, 'showLeaderboards');
    expect(calls.single.arguments, containsPair('leaderboardID', 'ranked.3m.5x3'));
  });
}
