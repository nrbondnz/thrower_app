import Flutter
import GameKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ThrowerGameCenterTables") {
      GameCenterTables.register(messenger: registrar.messenger())
    }
  }
}

/// The leaderboard's weekly tables (backlog #22, 2026-10-23) for
/// `GameCenterLeaderboardService.loadTable` in Dart, on the channel
/// `thrower/game_center`. The games_services plugin can't load last week's
/// full table (only the player's own entry), and loads every player's photo,
/// which the app doesn't show; this loads names and scores only.
///
/// `loadTable` takes `leaderboardID`, `previous` (last week) and `count`
/// (places, from 1). It replies with `entries` (each `rank`, `name`, `score`,
/// `me`), `me` (the player's own entry, if they have a score that week) and
/// `start` (when the week began, milliseconds since 1970). Errors:
/// `signedOut` (not signed in to Game Center), `notFound`, `failed`.
enum GameCenterTables {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "thrower/game_center", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "loadTable",
            let args = call.arguments as? [String: Any],
            let id = args["leaderboardID"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      let previous = args["previous"] as? Bool ?? false
      let count = args["count"] as? Int ?? 25
      // Replies go back on the main thread.
      Task { @MainActor in
        result(await GameCenterTables.loadTable(id: id, previous: previous, count: count))
      }
    }
  }

  @MainActor
  static func loadTable(id: String, previous: Bool, count: Int) async -> Any {
    guard GKLocalPlayer.local.isAuthenticated else {
      return FlutterError(code: "signedOut", message: "Not signed in to Game Center", details: nil)
    }
    do {
      guard let current = try await GKLeaderboard.loadLeaderboards(IDs: [id]).first else {
        return FlutterError(code: "notFound", message: "No leaderboard \(id)", details: nil)
      }
      var board = current
      if previous {
        // The completion form (Review Agent, 2026-10-23): it gives
        // (nil, nil) in a recurring leaderboard's first week, which the async
        // form may not survive, and lets no signal be told apart.
        let (earlier, earlierError): (GKLeaderboard?, Error?) = await withCheckedContinuation { cont in
          current.loadPreviousOccurrence { board, error in cont.resume(returning: (board, error)) }
        }
        if let earlier {
          board = earlier
        } else if let earlierError,
                  (earlierError as NSError).domain == NSURLErrorDomain
                    || (earlierError as? GKError)?.code == .communicationsFailure {
          // No signal: the screen offers Try again.
          return FlutterError(code: "failed", message: earlierError.localizedDescription, details: nil)
        } else {
          // No previous week yet: an empty table ("No results for last week yet").
          return ["entries": [Any]()] as [String: Any]
        }
      }
      // A recurring leaderboard ignores the time scope: each occurrence is
      // its own week.
      let (local, entries, _) = try await board.loadEntries(
        for: .global,
        timeScope: .allTime,
        range: NSRange(location: 1, length: max(1, min(count, 100)))
      )
      let me = GKLocalPlayer.local.gamePlayerID
      func row(_ entry: GKLeaderboard.Entry) -> [String: Any] {
        [
          "rank": entry.rank,
          "name": entry.player.displayName,
          "score": entry.score,
          "me": entry.player.gamePlayerID == me,
        ]
      }
      var reply: [String: Any] = ["entries": entries.map(row)]
      if let local { reply["me"] = row(local) }
      if let start = board.startDate { reply["start"] = Int(start.timeIntervalSince1970 * 1000) }
      return reply
    } catch {
      return FlutterError(code: "failed", message: error.localizedDescription, details: nil)
    }
  }
}
