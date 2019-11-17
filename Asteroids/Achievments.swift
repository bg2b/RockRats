//
//  Achievments.swift
//  Asteroids
//
//  Created by Daniel on 9/15/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import GameKit

enum Achievement: String {
  // Hidden
  case leeroyJenkins = "leeroyJenkins"
  case redShirt = "redShirt"
  case blastFromThePast = "blastFromThePast"
  case backToTheFuture = "backToTheFuture"
  case hanShotFirst = "hanShotFirst"
  case rightPlaceWrongTime = "rightPlaceWrongTime"
  case itsATrap = "itsATrap"
  case hanYolo = "hanYolo"
  case score404 = "notFound"
  case littlePrince = "littlePrince"
  case spaceOddity = "spaceOddity"
  case dontPanic = "dontPanic"
  case bigBrother = "bigBrother"
  case whatAreTheOdds = "whatAreTheOdds"
  case keepOnTrekking = "keepOnTrekking"
  case promoted = "promoted"
  // Normal
  case spaceCadet = "spaceCadet"
  case spaceScout = "spaceScout"
  case spaceRanger = "spaceRanger"
  case spaceAce = "spaceAce"
  case quickFingers = "quickFingers"
  case spinalTap = "spinalTap"
  case trickShot = "trickShot"
  case doubleTrouble = "doubleTrouble"
  case archer = "archer"
  case sniper = "sniper"
  case sharpshooter = "sharpshooter"
  case hawkeye = "hawkeye"
  case armedAndDangerous = "armedAndDangerous"
  // Multi-level
  case ufoHunter = "ufoHunter"
  case rockRat = "rockRat"

  var gameCenterID: String { "org.davidlong.Asteroids." + rawValue }

  func gameCenterLevelID(_ level: Int) -> String { return gameCenterID + String(level + 1) }
}

let achievementLevels = [
  Achievement.ufoHunter: [30, 100, 300, 1000],
  .rockRat: [1500, 5000, 15000, 50000]
]

func reportAchievement(achievement: Achievement) {
  if let gc = Globals.gcInterface, gc.enabled {
    if let status = gc.statusOfAchievement(achievement.gameCenterID) {
      if status == 100 {
        logging("Achievement \(achievement.rawValue) already completed")
      } else {
        gc.reportCompletion(achievement.gameCenterID)
      }
    } else {
      // We don't know the status for some reason
      logging("Achievement \(achievement.rawValue) with no status (maybe not in Game Center yet)")
    }
  } else {
    logging("Achievement \(achievement.rawValue) but Game Center is disabled")
  }
}

func reportAchievement(achievement: Achievement, soFar: Int) -> Int? {
  // Game Center will have some percent completion of a progress achievement, and
  // from that we can sometimes tell that the level passed in as soFar is too low.
  // For example suppose that Game Center has reported the player to be 37% through
  // an achievement that is attained at level 1000.  If soFar is only 350, then we
  // know that they must have been playing on some other device and made some
  // progress on the achievement.  Normally this wouldn't happen since we synchronize
  // counters through iCloud.  But since iCloud accounts and Game Center accounts
  // aren't the same, it's possible if a player logs into Game Center on someone
  // else's device and plays there.  Anyway, we can use the achievement percentage as
  // an approximate substitute for the synchronized counters.  We'll return nil if
  // soFar already represents our best guess as to the correct level.
  var result: Int? = nil
  if let gc = Globals.gcInterface, gc.enabled {
    if let levels = achievementLevels[achievement] {
      logging("Reporting progress in multi-level achievement \(achievement.gameCenterID)")
      for level in 0 ..< levels.count {
        let progress = gc.reportProgress(achievement.gameCenterLevelID(level), knownProgress: floor(Double(soFar) / Double(levels[level]) * 100))
        let minSoFar = Int(floor(progress / 100.0 * Double(levels[level])))
        if minSoFar > soFar {
          result = max(result ?? 0, minSoFar)
        }
      }
    }
  } else {
    logging("Achievement \(achievement.rawValue) but Game Center is disabled")
  }
  return result
}

func achievementIsCompleted(achievement: Achievement) -> Bool {
  guard let gc = Globals.gcInterface, gc.enabled else { return false }
  guard let status = gc.statusOfAchievement(achievement.gameCenterID) else { return false }
  return status == 100
}

func levelIsReached(achievement: Achievement, level: Int) -> Bool {
  guard let gc = Globals.gcInterface, gc.enabled else { return false }
  guard let status = gc.statusOfAchievement(achievement.gameCenterLevelID(level)) else { return false }
  return status == 100
}
