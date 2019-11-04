//
//  GameScore.swift
//  Asteroids
//
//  Created by David Long on 11/1/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import Foundation
import GameKit

struct GameScore: Hashable {
  let playerName: String
  let points: Int
  let date: TimeInterval  // Since reference date

  init(points: Int) {
    playerName = userDefaults.currentPlayerName.value
    self.points = points
    date = Date().timeIntervalSinceReferenceDate
  }

  init(score: GKScore) {
    playerName = score.player.displayName
    points = Int(score.value)
    date = score.date.timeIntervalSinceReferenceDate
  }

  init?(fromDict dict: [String: Any]) {
    guard let playerName = dict["playerName"] as? String else { return nil }
    guard let points = dict["points"] as? Int else { return nil }
    guard let date = dict["date"] as? Double else { return nil }
    self.playerName = playerName
    self.points = points
    self.date = date
  }

  func encode() -> [String: Any] {
    var result = [String: Any]()
    result["playerName"] = playerName
    result["points"] = points
    result["date"] = date
    return result
  }
}
