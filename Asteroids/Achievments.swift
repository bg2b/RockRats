//
//  Achievments.swift
//  Asteroids
//
//  Created by Daniel on 9/15/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import GameKit

/// A Game Center achievement
///
/// I put them all here in an enumeration so that I only have to get the name right
/// once.
enum Achievement: String, CaseIterable {
  // Hidden
  case leeroyJenkins = "leeroyJenkins"
  case redShirt = "redShirt"
  case rockSplat = "rockSplat"
  case blastFromThePast = "blastFromThePast"
  case backToTheFuture = "backToTheFuture"
  case hanShotFirst = "hanShotFirst"
  case rightPlaceWrongTime = "rightPlaceWrongTime"
  case itsATrap = "itsATrap"
  case score404 = "notFound"
  case littlePrince = "littlePrince"
  case spaceOddity = "spaceOddity"
  case dontPanic = "dontPanic"
  case bigBrother = "bigBrother"
  case whatAreTheOdds = "whatAreTheOdds"
  case keepOnTrekking = "keepOnTrekking"
  case bestServedCold = "bestServedCold"
  case tooMuchTime = "tooMuchTime"
  case promoted = "promoted"
  // Normal
  // The first non-hidden achievement should be useTheSource, since finding the set
  // of hidden achievements is done by iterating through the enum until useTheSource
  // is reached.
  case useTheSource = "useTheSource"
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
  case top10 = "top10"
  case top3 = "top3"
  case top1 = "top1"
  // Multi-level
  // These have levels 0, 1, 2, ...
  // Reporting progress for one of these will iterate through the levels and update
  // progress and/or award all of the appropriate individual achievements.
  case ufoHunter = "ufoHunter"
  case rockRat = "rockRat"

  /// The Game Center ID for the achievement
  var gameCenterID: String { "org.davidlong.Asteroids." + rawValue }

  /// The Game Center ID for a multi-level achievement
  /// - Parameter level: The level number (starting from 0)
  func gameCenterLevelID(_ level: Int) -> String { return gameCenterID + String(level + 1) }

  /// The set of all hidden achievements
  ///
  /// This is initialized by calling closure, which I didn't realize was possible
  /// until recently, but which is pretty useful.
  static let hiddenAchievements: Set<Achievement> = {
    var result = Set<Achievement>()
    for achievement in Achievement.allCases {
      if achievement == .useTheSource {
        break
      } else {
        result.insert(achievement)
      }
    }
    return result
  }()

  /// `true` for hidden achievements
  var isHidden: Bool { Achievement.hiddenAchievements.contains(self) }
}

/// A dictionary mapping multi-level achievements to an array holding the different
/// levels, so, e.g., the first `ufoHunter` achievement is completed after destroying
/// 30 UFOs, the next after 100 UFOs, etc.
let achievementLevels = [
  Achievement.ufoHunter: [30, 100, 300, 1000],
  .rockRat: [1500, 5000, 15000, 50000]
]

/// Report a simple achievment as completed
/// - Parameter achievement: The achievement
func reportAchievement(achievement: Achievement) {
  if let gc = Globals.gcInterface, gc.enabled {
    if let status = gc.statusOfAchievement(achievement.gameCenterID) {
      if status == 100 {
        logging("Achievement \(achievement.rawValue) already completed")
      } else {
        gc.reportCompletion(achievement.gameCenterID)
        if achievement.isHidden {
          // When the player gets a new hidden achievement, count their progress
          // towards useTheSource.
          reportHiddenProgress()
        }
      }
    } else {
      // We don't know the status for some reason
      logging("Achievement \(achievement.rawValue) with no status (maybe not in Game Center yet)")
    }
  } else {
    logging("Achievement \(achievement.rawValue) but Game Center is disabled")
  }
}

/// Report completion of a repeatable achievement
///
/// Currently the only one of these we have is `spaceAce`.
///
/// - Parameter achievement: The achievement just completed
func reportRepeatableAchievement(achievement: Achievement) {
  if let gc = Globals.gcInterface, gc.enabled {
    gc.reportCompletion(achievement.gameCenterID)
  }
}

/// Report progress towards a multi-level achievement
///
/// This loops over all the levels of the achievement and records progress (or
/// completion) of each one.
///
/// Game Center will have some percent completion of a progress achievement, and from
/// that we can sometimes tell that the level passed in as `soFar` is too low.  For
/// example suppose that Game Center has reported the player to be 37% through an
/// achievement that is attained at a count of 1000.  If `soFar` is only 350, then we
/// know that the player must have been playing on some other device and made some
/// progress on the achievement, and the return value will be 370.  Normally this
/// wouldn't happen since we synchronize counters through iCloud.  But since iCloud
/// accounts and Game Center accounts aren't the same, it's possible if a player logs
/// into Game Center on someone else's device and plays there.  Anyway, we can use
/// the achievement percentage as an approximate substitute for the synchronized
/// counters.  The return is `nil` if `soFar` already represents our best guess as to
/// the correct level.
///
/// - Parameters:
///   - achievement: The multi-level achievement
///   - soFar: The amount of progress (a count of how many times something was done)
/// - Returns: An optional possibly larger amount of progress (see discussion)
func reportAchievement(achievement: Achievement, soFar: Int) -> Int? {
  var result: Int?
  if let gc = Globals.gcInterface, gc.enabled {
    if let levels = achievementLevels[achievement] {
      logging("Reporting progress in multi-level achievement \(achievement.gameCenterID)")
      for level in 0 ..< levels.count {
        let progress = gc.reportProgress(achievement.gameCenterLevelID(level),
                                         knownProgress: floor(Double(soFar) / Double(levels[level]) * 100))
        let minSoFar = Int(floor(progress / 100.0 * Double(levels[level])))
        // See if the amount of progress must be larger than what was passed in
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

/// See if an achievement has been completed
/// - Parameter achievement: The achievement to check
/// - Returns: `true` if the achievement was completed, `false` if not or if Game
///   Center isn't available
func achievementIsCompleted(_ achievement: Achievement) -> Bool {
  guard let gc = Globals.gcInterface, gc.enabled else { return false }
  guard let status = gc.statusOfAchievement(achievement.gameCenterID) else { return false }
  return status == 100
}

/// See if a multi-level achievement has been completed
/// - Parameters:
///   - achievement: The multi-level achievement to check
///   - level: The level desired
/// - Returns: `true` if the achievement was completed, `false` if not or if Game
///   Center isn't available
func levelIsReached(achievement: Achievement, level: Int) -> Bool {
  guard let gc = Globals.gcInterface, gc.enabled else { return false }
  guard let status = gc.statusOfAchievement(achievement.gameCenterLevelID(level)) else { return false }
  return status == 100
}

/// Report progress towards `useTheSource`
///
/// This counts all the completed hidden achievements, compares to the total number
/// of hidden achievements, and sends the percentage of the total to Game Center.
///
/// Normally this would be called and `useTheSource` awarded when the last hidden
/// achievement is done, but maybe there could be some sort of communication error or
/// something that would cause the reporting of `useTheSource` to be dropped.  I
/// don't think that would happen, but to be safe `reportHiddenProgress` is also
/// called at the end of every game.  If completion were missed for some reason when
/// the last hidden achievement was done, then it'll get picked up at that time.
func reportHiddenProgress() {
  guard let gc = Globals.gcInterface, gc.enabled else { return }
  var numFound = 0
  for achievement in Achievement.hiddenAchievements {
    if achievementIsCompleted(achievement) {
      numFound += 1
    }
  }
  logging("Found \(numFound) out of \(Achievement.hiddenAchievements.count) hidden achievements")
  _ = gc.reportProgress(Achievement.useTheSource.gameCenterID,
                        knownProgress: floor(Double(numFound) / Double(Achievement.hiddenAchievements.count) * 100))
}
