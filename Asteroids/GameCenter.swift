//
//  GameCenter.swift
//  Asteroids
//
//  Created by David Long on 10/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import GameKit

// At some point, playerID will become gamePlayerID on iOS ?? devices since playerID
// is deprecated.  The alternatePlayerID is to allow a smooth transition without
// losing player progress.  We assume that they'll upgrade to iOS 13 sometime during
// the transition period so that the alternate ID is available.
extension GKPlayer {
  var primaryPlayerID: String { playerID }
  var alternatePlayerID: String? {
    if #available(iOS 13, *) {
      return scopedIDsArePersistent() ? gamePlayerID : nil
    } else {
      return nil
    }
  }
}

class GameCenterInterface {
  let leaderboardID: String
  let presenter: (UIViewController?) -> Void
  var lastPlayerID: String? = nil
  var achievementIdentifiers: Set<String>? = nil
  var playerAchievements = [String: Double]()
  var playerAchievementsProgress = [String: Double]()
  var localPlayerScore: GKScore? = nil
  var leaderboardScores = [GKScore]()
  var friendScores = [GKScore]()

  var enabled: Bool { GKLocalPlayer.local.isAuthenticated }
  var primaryPlayerID: String { GKLocalPlayer.local.primaryPlayerID }
  var alternatePlayerID: String? { GKLocalPlayer.local.alternatePlayerID }

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
        if self.primaryPlayerID != self.lastPlayerID {
          setGameCountersForPlayer(self.primaryPlayerID, self.alternatePlayerID)
          self.playerAchievements.removeAll()
          self.playerAchievementsProgress.removeAll()
          self.lastPlayerID = self.primaryPlayerID
          self.localPlayerScore = nil
          self.leaderboardScores.removeAll()
          self.friendScores.removeAll()
        }
        setCurrentPlayerName(GKLocalPlayer.local.displayName)
        GKAchievement.loadAchievements { [weak self] playerAchievements, error in
          self?.setPlayerAchievements(playerAchievements, error: error)
        }
        self.loadLeaderboards()
      } else {
        self.localPlayerScore = nil
        self.leaderboardScores.removeAll()
        self.friendScores.removeAll()
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

  func hashScore(_ score: Int) -> UInt64 {
    // Stupid hash function to compute a context that will be associated with a
    // score.  When we load a leaderboard, we toss out any scores that don't have the
    // right hash.  We don't have any control over what scores may show in Game
    // Center, but if someone has managed to somehow hack things and get a bogus
    // score accepted there, this is at least an extra little speedbump that may help
    // prevent such bogus scores from being displayed on the in-game leaderboards.
    let prime64bit = UInt64(3_354_817_023_488_194_757)
    // This will overflow and give a randomish 64-bit unsigned value
    return prime64bit &* UInt64(score)
  }

  func saveScore(_ score: Int) -> GameScore {
    let gcScore = GKScore(leaderboardIdentifier: leaderboardID)
    gcScore.value = Int64(score)
    gcScore.context = hashScore(score)
    GKScore.report([gcScore]) { error in
      if let error = error {
        logging("Error reporting score \(score) to Game Center: \(error.localizedDescription)")
      } else {
        logging("Reported score \(score) to Game Center")
      }
    }
    return GameScore(score: gcScore)
  }

  func scoreIsValid(_ score: GKScore) -> Bool {
    return score.context == hashScore(Int(score.value))
  }

  func printScore(_ score: GKScore?) {
    if let score = score {
      let player = score.player
      let valid = scoreIsValid(score) ? "valid" : "invalid"
      logging("player \(player.displayName), score \(score.value), date \(score.date), rank \(score.rank), \(valid)")
    } else {
      logging("none")
    }
  }

  func loadLeaderboards() {
    for global in [false, true] {
      let leaderboard = GKLeaderboard()
      leaderboard.identifier = leaderboardID
      leaderboard.playerScope = global ? .global : .friendsOnly
      leaderboard.range = NSRange(1...10)
      leaderboard.timeScope = .week
      leaderboard.loadScores() { [weak self] scores, error in
        guard let self = self else { return }
        if let error = error {
          logging("Error requesting scores from Game Center: \(error.localizedDescription)")
        } else if let scores = scores {
          self.printScore(leaderboard.localPlayerScore)
          scores.forEach { self.printScore($0) }
          if global {
            self.localPlayerScore = leaderboard.localPlayerScore
            self.leaderboardScores = scores.filter { self.scoreIsValid($0) }
          } else {
            self.friendScores = scores.filter { self.scoreIsValid($0) }
          }
        }
      }
    }
  }
}
