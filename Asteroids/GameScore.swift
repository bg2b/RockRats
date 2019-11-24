//
//  GameScore.swift
//  Asteroids
//
//  Created by David Long on 11/1/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import Foundation
import GameKit

struct GameScore: Equatable {
  let playerID: String
  let playerName: String?
  let points: Int
  let date: TimeInterval  // Since reference date

  init() {
    playerID = ""
    playerName = nil
    points = 0
    date = Date().timeIntervalSinceReferenceDate
  }

  init(points: Int) {
    playerID = userDefaults.currentPlayerID.value
    playerName = userDefaults.playerNames.value[playerID]
    self.points = points
    date = Date().timeIntervalSinceReferenceDate
  }

  /// - Todo:
  ///   Check what happens if displayName is nil and the alias in the score has
  ///   characters that aren't in our font.
  init(score: GKScore, displayName: String? = nil) {
    playerID = score.player.primaryPlayerID
    // I'm deliberately using alias instead of displayName because I don't like iOS
    // 12's "Me".
    // Originalyy I was using the displayName and filtering it like this
    //   String(score.player.displayName.filter { $0.isASCII })
    // with the filtering necessary to get rid of iOS 12's quote marks.  Should
    // filtering still be used?
    playerName = displayName ?? score.player.alias
    points = Int(score.value)
    date = score.date.timeIntervalSinceReferenceDate
  }

  init?(fromDict dict: [String: Any]) {
    guard let playerID = dict["playerID"] as? String else { return nil }
    let playerName = dict["playerName"] as? String ?? nil
    guard let points = dict["points"] as? Int else { return nil }
    guard let date = dict["date"] as? Double else { return nil }
    self.playerID = playerID
    self.playerName = playerName
    self.points = points
    self.date = date
  }

  init(score: GameScore, newName: String) {
    playerID = score.playerID
    playerName = newName
    points = score.points
    date = score.date
  }

  func encode() -> [String: Any] {
    var result = [String: Any]()
    result["playerID"] = playerID
    if let playerName = playerName {
      result["playerName"] = playerName
    }
    result["points"] = points
    result["date"] = date
    return result
  }
}

func sameScore(_ score1: GameScore, _ score2: GameScore) -> Bool {
  // The date on different returns from Game Center seems to get munged a little,
  // so allow some slack when comparing.
  return score1.playerID == score2.playerID &&
    score1.points == score2.points &&
    abs(score1.date - score2.date) <= 1
}
