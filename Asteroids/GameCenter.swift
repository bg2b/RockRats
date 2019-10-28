//
//  GameCenter.swift
//  Asteroids
//
//  Created by David Long on 10/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import GameKit

class GameCenterInterface {
  let leaderboardID: String
  let presenter: (UIViewController?) -> Void
  var lastPlayerID: String? = nil
  var achievementIdentifiers: Set<String>? = nil
  var playerAchievements = [String: Double]()
  var playerAchievementsProgress = [String: Double]()
  var conflictingGames = [GKSavedGame]()
  var conflictsToResolve = 0

  var enabled: Bool { GKLocalPlayer.local.isAuthenticated }

  init(leaderboardID: String, presenter: @escaping (UIViewController?) -> Void) {
    self.leaderboardID = leaderboardID
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
        if GKLocalPlayer.local.playerID != self.lastPlayerID {
          setGameCountersForPlayer(GKLocalPlayer.local.playerID)
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
    // Mark it so that statusOfAchievement will indicate that it's done and we won't
    // report it multiple times.  If the report fails for some reason, we'll fall
    // back by sticking it in playerAchievementsProgress so that hopefully it'll get
    // reported to Game Center successfully when the game finishes.
    playerAchievements[identifier] = 100
    GKAchievement.report([achievement]) { [weak self] error in
      if let error = error {
        logging("Error reporting achievement \(identifier) to Game Center: \(error.localizedDescription)")
        // We'll stick this in with the progress achievements and hope that the flush
        // after a game finishes manages to succeed.
        self?.playerAchievementsProgress[identifier] = 100
      }
    }
  }

  func reportProgress(_ identifier: String, knownProgress: Double) -> Double {
    let reportedProgress = playerAchievementsProgress[identifier] ?? (statusOfAchievement(identifier) ?? 0)
    if reportedProgress == 100 {
      // Already done
      return 100
    }
    let progress = max(reportedProgress, knownProgress)
    if progress == 100 {
      playerAchievementsProgress.removeValue(forKey: identifier)
      reportCompletion(identifier)
    } else {
       playerAchievementsProgress[identifier] = progress
    }
    return progress
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
        // Leave playerAchievementsProgress alone.  Maybe the person will play
        // another game and we'll have another go at flushProgress.
      } else {
        for (identifier, percent) in self.playerAchievementsProgress {
          self.playerAchievements[identifier] = percent
        }
        self.playerAchievementsProgress.removeAll()
      }
    }
  }

  func saveScore(_ score: Int) {
    let gcScore = GKScore(leaderboardIdentifier: leaderboardID)
    gcScore.value = Int64(score)
    GKScore.report([gcScore]) { error in
      if let error = error {
        logging("Error reporting score \(score) to Game Center: \(error.localizedDescription)")
      } else {
        logging("Reported score \(score) to Game Center")
      }
    }
  }

  func printScore(_ score: GKScore?) {
    if let score = score {
      let player = score.player
      logging("player \(player.alias) \(player.displayName), score \(score.value), date \(score.date), rank \(score.rank)")
    } else {
      logging("none")
    }
  }

  func loadLeaderboard() {
    let leaderboard = GKLeaderboard()
    leaderboard.identifier = leaderboardID
    leaderboard.playerScope = .global
    leaderboard.timeScope = .week
    leaderboard.loadScores() { scores, error in
      if let error = error {
        logging("Error requesting scores from Game Center: \(error.localizedDescription)")
      } else {
        logging("Local player score:")
        self.printScore(leaderboard.localPlayerScore)
        logging("Top scores")
        scores?.forEach { self.printScore($0) }
      }
    }
  }
}
