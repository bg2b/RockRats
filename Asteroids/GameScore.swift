//
//  GameScore.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import Foundation
import GameKit

/// An end-of-game score, plus info about when it happened and the player that earned it
struct GameScore: Equatable {
  /// The Game Center ID of the player
  let playerID: String
  /// An optional name to diplay for this score
  let playerName: String?
  /// The score earned
  let points: Int
  /// The interval since the reference date that the score was earned
  let date: TimeInterval

  /// Make a null score; this is used internally by the high scores scene when there
  /// are no other scores to show
  init() {
    playerID = ""
    playerName = nil
    points = 0
    date = Date().timeIntervalSinceReferenceDate
  }

  /// Make a score for the current player
  ///
  /// To show the high score screen and just highlight the current player's entries,
  /// pass the scene constructor a score made by this initializer with 0 for the
  /// points.
  ///
  /// - Parameter points: The points earned
  init(points: Int) {
    playerID = UserData.currentPlayerID.value
    playerName = UserData.playerNames.value[playerID]
    self.points = points
    date = Date().timeIntervalSinceReferenceDate
  }

  /// Make a score from a Game Center `GKLeaderboard.Entry`
  ///
  /// The display name can be specified explicitly if showing the Game Center alias
  /// of the player isn't desired.
  ///
  /// - Todo:
  ///   Check what happens if displayName is `nil` and the alias in the score has
  ///   characters that aren't in our font.
  init(entry: GKLeaderboard.Entry, displayName: String? = nil) {
    playerID = entry.player.primaryPlayerID
    // I'm deliberately using alias instead of displayName because I don't like iOS
    // 12's "Me".
    // Originally I was using the displayName and filtering it like this
    //   String(score.player.displayName.filter { $0.isASCII })
    // with the filtering necessary to get rid of iOS 12's quote marks.  Should
    // filtering still be used?
    playerName = displayName ?? entry.player.alias
    points = entry.score
    date = entry.date.timeIntervalSinceReferenceDate
  }

  /// Make a score from a dictionary
  ///
  /// Used when reconstructing scores as saved in `UserData`
  ///
  /// - Parameter dict: The dictionary representation (see the `encode` method)
  init?(fromDict dict: [String: Any]) {
    guard let playerID = dict["playerID"] as? String else { return nil }
    let playerName = dict["playerName"] as? String ?? nil
    guard let points = dict["points"] as? Int else { return nil }
    guard let date = dict["date"] as? Double else { return nil }
    // Now that I've switched to new-style player IDs, convert locally-saved scores
    // during decoding.  After being converted, the updated IDs will be used when
    // scores are saved.
    self.playerID = newPlayerID(playerID)
    self.playerName = playerName
    self.points = points
    self.date = date
  }

  /// Make a copy of the score, but change the displayed name
  ///
  /// I use this when getting the local high scores from `UserData` to make the high
  /// score scene.  It's possible that the player has changed their Game Center alias
  /// since the score was made/saved, and this is used to replace the name in the
  /// saved score with whatever name I currently have for the player.
  ///
  /// - Parameters:
  ///   - score: The original score
  ///   - newName: The desired player name
  init(score: GameScore, newName: String) {
    playerID = score.playerID
    playerName = newName
    points = score.points
    date = score.date
  }

  /// Encode a score as a dictionary for saving in `UserData`
  /// - Returns: The encoded score
  func encode() -> [String: Any] {
    var result = [String: Any]()
    result["playerID"] = playerID
    if let playerName {
      result["playerName"] = playerName
    }
    result["points"] = points
    result["date"] = date
    return result
  }
}

/// See if two `GameScore`s represent the same score
/// - Parameters:
///   - score1: The first score
///   - score2: The second score
/// - Returns: `true` means same points, very close date
func sameScore(_ score1: GameScore, _ score2: GameScore) -> Bool {
  // The date on different returns from Game Center seems to get munged a little, so
  // allow some slack when comparing.  Originally I was also checking playerID, but I
  // think Game Center also tweaks those a little between leaderboards, maybe some
  // privacy something?  I found that on the daily and weekly leaderboards, I'd get
  // what was obviously the same score but with different IDs.
  return score1.points == score2.points && abs(score1.date - score2.date) <= 1
}
