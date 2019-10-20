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
  // Normal
  case spaceCadet = "spaceCadet"
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

  var gameCenterID: String { "org.davidlong.Asteroids." + rawValue }

  func gameCenterLevelID(_ level: Int) -> String { return gameCenterID + String(level + 1) }
}

let achievementLevels = [
  Achievement.ufoHunter: [25, 100, 300]
]

func reportAchievement(achievement: Achievement) {
  if let gc = Globals.gcInterface, gc.enabled {
    if let levels = achievementLevels[achievement] {
      logging("Reporting progress in multi-level achievement \(achievement.gameCenterID)")
      for level in 0 ..< levels.count {
        gc.reportProgress(achievement.gameCenterLevelID(level), amount: 100.0 / Double(levels[level]))
      }
    } else {
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
    }
  } else {
    logging("Achievement \(achievement.rawValue) but Game Center is disabled")
  }
}
