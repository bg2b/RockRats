//
//  GameCenter.swift
//  Asteroids
//
//  Created by David Long on 10/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import GameKit

class GameCenterInterface {
  let presenter: (UIViewController?) -> Void
  var lastPlayerID: String? = nil
  var achievementIdentifiers: Set<String>? = nil
  var leaderboardIdentifiers: Set<String>? = nil
  var playerAchievements = [String: Double]()
  var playerAchievementsProgress = [String: Double]()

  var enabled: Bool { GKLocalPlayer.local.isAuthenticated }

  init(presenter: @escaping (UIViewController?) -> Void) {
    self.presenter = presenter
    logging("GameCenterInterface init starts")
    GKLocalPlayer.local.authenticateHandler = { [unowned self] gcAuthorizationViewController, error in
      logging("GKLocalPlayer authenticate handler called")
      self.presenter(gcAuthorizationViewController)
      if let error = error {
        logging("Error in Game Center authentication: \(error.localizedDescription)")
      }
      logging("Game Center is \(self.enabled ? "enabled" : "not enabled")")
      if self.enabled {
        if self.achievementIdentifiers == nil {
          GKAchievementDescription.loadAchievementDescriptions { [weak self] allAchievements, error in
            self?.setAchievementIdentifiers(allAchievements, error: error)
          }
        }
        if self.leaderboardIdentifiers == nil {
          GKLeaderboard.loadLeaderboards { [weak self] leaderboards, error in
            self?.setLeaderboardIdentifiers(leaderboards, error: error)
          }
        }
        if GKLocalPlayer.local.playerID != self.lastPlayerID {
          self.playerAchievements.removeAll()
          self.playerAchievementsProgress.removeAll()
          self.lastPlayerID = GKLocalPlayer.local.playerID
        }
        GKAchievement.loadAchievements { [weak self] playerAchievements, error in
          self?.setPlayerAchievements(playerAchievements, error: error)
        }
      }
    }
    logging("GameCenterInterface init finishes")
  }

  func setAchievementIdentifiers(_ allAchievements: [GKAchievementDescription]?, error: Error?) {
    // We only need to set these once, since they're independent of the player
    guard achievementIdentifiers == nil else { return }
    if let error = error {
      // Don't save a partial list
      logging("Error loading Game Center achievements: \(error.localizedDescription)")
    } else {
      guard let allAchievements = allAchievements else { return }
      logging("\(allAchievements.count) possible achievements:")
      achievementIdentifiers = Set<String>(allAchievements.map {
        logging($0.identifier)
        return $0.identifier
      })
    }
  }

  func setLeaderboardIdentifiers(_ leaderboards: [GKLeaderboard]?, error: Error?) {
    // We only need to set these once, since they're independent of the player
    guard leaderboardIdentifiers == nil else { return }
    if let error = error {
      // Don't save a partial list
      logging("Error loading Game Center leaderboards: \(error.localizedDescription)")
    } else {
      guard let leaderboards = leaderboards else { return }
      logging("Leaderboards:")
      leaderboardIdentifiers = Set<String>(leaderboards.compactMap {
        if let id = $0.identifier {
          logging(id)
        }
        return $0.identifier
      })
    }
  }

  func setPlayerAchievements(_ playerAchievements: [GKAchievement]?, error: Error?) {
    if let error = error {
      logging("Error loading Game Center player achievements: \(error.localizedDescription)")
    }
    playerAchievements?.forEach {
      self.playerAchievements[$0.identifier] = $0.percentComplete
      logging("Achievement with id \($0.identifier) is \($0.percentComplete)% complete")
    }
  }

  func statusOfAchievement(_ identifier: String) -> Double? {
    if let result = playerAchievements[identifier] {
      // We got the value from the game center
      return result
    }
    guard let achievementIdentifiers = achievementIdentifiers else {
      // We don't know the valid achievements, so can't say anything
      return nil
    }
    if achievementIdentifiers.contains(identifier) {
      // This is a valid achievement, but the player had no progress so assume 0
      return 0
    }
    // No information to base a conclusion
    return nil
  }

  func reportCompletion(_ identifier: String) {
    // Report a simple achievement done
    let achievement = GKAchievement(identifier: identifier)
    achievement.percentComplete = 100
    achievement.showsCompletionBanner = true
    GKAchievement.report([achievement]) { [weak self] error in
      if let error = error {
        logging("Error reporting achievement \(identifier) to Game Center: \(error.localizedDescription)")
        // We'll stick this in with the progress achievements and hope that the flush
        // after a game finishes manages to succeed.
        self?.playerAchievementsProgress[identifier] = 100
      } else {
        // If we successfully reported the achievement, mark it so that
        // statusOfAchievement will indicate that it's done and we won't report it
        // multiple times.
        self?.playerAchievements[identifier] = 100
      }
    }
  }

  func reportProgress(_ identifier: String, amount: Double) {
    let currentProgress = playerAchievementsProgress[identifier] ?? (statusOfAchievement(identifier) ?? 0)
    if currentProgress == 100 {
      // Already done
      return
    }
    let totalProgress = currentProgress + amount
    if totalProgress > 99.999 {
      // This achievement is completed.  The 99.999 is to allow for a little floating
      // point error during the accumulation of the partial results.  After a game
      // finishes we'll flush any partial progress in playerAchievementsProgress, but
      // we'll report this achievement now so we can remove the partial progress for
      // it.  (If there's an error in reportCompletion, the result will go back into
      // playerAchievementsProgress for retry.)
      playerAchievementsProgress.removeValue(forKey: identifier)
      reportCompletion(identifier)
    } else {
       playerAchievementsProgress[identifier] = totalProgress
    }
  }

  func flushProgress() {
    // Report all partial results
    var achievements = [GKAchievement]()
    for (identifier, percent) in playerAchievementsProgress {
      let achievement = GKAchievement(identifier: identifier)
      achievement.percentComplete = percent
      logging("Achievement \(identifier) at \(percent)%")
      achievement.showsCompletionBanner = true
      achievements.append(achievement)
    }
    GKAchievement.report(achievements) { [weak self] error in
      guard let self = self else { return }
      if let error = error {
        logging("Error reporting progress achievements to Game Center: \(error.localizedDescription)")
      } else {
        for (identifier, percent) in self.playerAchievementsProgress {
          self.playerAchievements[identifier] = percent
        }
        self.playerAchievementsProgress.removeAll()
      }
    }
  }

  func saveScore(_ score: Int) {
    let gcScore = GKScore(leaderboardIdentifier: leaderboardIdentifiers!.first!)
    gcScore.value = Int64(score)
    GKScore.report([gcScore]) { error in
      if let error = error {
        logging("Error reporting score \(score) to Game Center: \(error.localizedDescription)")
      } else {
        logging("Reported score \(score) to Game Center")
      }
    }
  }
}
