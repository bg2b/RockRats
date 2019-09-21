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
  case score404 = "score404"
  case leeroyJenkins = "leeroyJenkins"
  case spinalTap = "spinalTap"
  case redShirt = "redShirt"
  case backToTheFuture = "backToTheFuture"
  case doubleTrouble = "doubleTrouble"
  case armedAndDangerous = "armedAndDangerous"
  case hanShotFirst = "hanShotFirst"
  case quickFingers = "quickFingers"
  case rightPlaceWrongTime = "rightPlaceWrongTime"
}

func reportAchievement(achievement: Achievement) {
  logging("would send achievement \(achievement.rawValue) to gamecenter")
    /*
  GKAchievement.report([GKAchievement(identifier: achievement.rawValue)]) { error in
    guard let e = error else { print("worked"); return }
    print(e)
  }
 */
}