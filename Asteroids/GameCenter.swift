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
// losing player progress.  I assume that they'll upgrade to iOS 13 sometime during
// the transition period so that the alternate ID is available.
extension GKPlayer {
  /// primaryPlayerID is a wrapper around the playerID/gamePlayerID stuff.  Currently
  /// it just returns playerID, but in some future release when playerID is no longer
  /// available, it will become gamePlayerID.
  var primaryPlayerID: String { playerID }
  /// alternatePlayerID is either nil (unavailable / irrelevant) or will return
  /// gamePlayerID when that is available and the app is currently using playerID as
  /// the primaryPlayerID.  The alternatePlayerID should be saved in that case so
  /// that persistent state associated with the player can be transitioned in newer
  /// versions of the app.
  var alternatePlayerID: String? {
    if #available(iOS 13, *) {
      // It would be nice if there was some documentation about the mysterious
      // circumstances mentioned in scopedIDsArePersistent about when gamePlayerID
      // can be trusted.
      return scopedIDsArePersistent() ? gamePlayerID : nil
    } else {
      return nil
    }
  }
}

/// GameCenterInterface is a wrapper around the Game Center functionality.  It
/// interfaces with the authentication mechanism, informs the app of who's playing,
/// keeps track of what achievements are available and what progress the player has
/// made in them, loads leaderboards, and passes scores back to Game Center.
class GameCenterInterface {
  /// The Game Center leaderboard identifier (this interface only handles the
  /// one-leaderboard case)
  let leaderboardID: String
  /// A closure that will do something appropriate with the Game Center's
  /// authentication view controller if there's no logged-in player.  Typically the
  /// closure would squirrel the controller away so that it can be presented at some
  /// appropriate point.
  let presenter: (UIViewController?) -> Void
  /// The primary ID of whoever successfully logged in last
  var lastPlayerID: String? = nil
  /// A set of all the valid achievement identifiers, retrieved from Game Center.
  var achievementIdentifiers: Set<String>? = nil
  /// The identifiers of all the local player's achievements and their completion
  /// percentages as retrieved from Game Center.  If the player has zero percent on
  /// some achievement, it's not in the dictionary.
  var playerAchievements = [String: Double]()
  /// Used to record the percent progress of the player towards levelled achievements
  /// when playing.  Flushed to Game Center if their progress reaches 100%, and also
  /// flushed at the end of a game.
  var playerAchievementsProgress = [String: Double]()
  /// The local player's score and rank from a leaderboard fetch
  var localPlayerScore: GKScore? = nil
  /// Scores retrieved from Game Center from a leaderboard fetch
  var leaderboardScores = [GKScore]()

  /// Is Game Center enabled (i.e., there's an authenticated local player)?
  var enabled: Bool { GKLocalPlayer.local.isAuthenticated }
  /// The primary ID of the authenticated player (valid when `enabled`)
  var primaryPlayerID: String { GKLocalPlayer.local.primaryPlayerID }
  /// The alternate ID (if any) of the authenticated player (if any).
  var alternatePlayerID: String? { GKLocalPlayer.local.alternatePlayerID }
  /// This is the name to address the player by
  var playerName: String { enabled ? GKLocalPlayer.local.alias : "Anonymous" }

  /// Initialize the Game Center interface.  This should be a singleton
  /// - Parameters:
  ///   - leaderboardID: The app's one-and-only leaderboard identifier
  ///   - presenter: A closure that should receive Game Center's authentication view controller
  ///   - gcvc: Show this view controller to authenticate to Game Center, `nil` means don't show anything
  init(leaderboardID: String, presenter: @escaping (_ gcvc: UIViewController?) -> Void) {
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
          self.playerAchievements.removeAll()
          self.playerAchievementsProgress.removeAll()
          self.lastPlayerID = self.primaryPlayerID
          self.localPlayerScore = nil
          self.leaderboardScores.removeAll()
        }
        // I use alias instead of displayName deliberately, since I don't like the
        // display name of "Me" from iOS 12.
        setCurrentPlayer(self.primaryPlayerID, playerName: GKLocalPlayer.local.alias, alternatePlayerID: self.alternatePlayerID)
        self.loadPlayerAchievements()
        self.loadLeaderboards()
      } else {
        setCurrentPlayer("anon", playerName: "Anonymous", alternatePlayerID: nil)
        self.playerAchievements.removeAll()
        self.playerAchievementsProgress.removeAll()
        self.localPlayerScore = nil
        self.leaderboardScores.removeAll()
      }
      NotificationCenter.default.post(name: .authenticationChanged, object: self.enabled)
    }
    logging("GameCenterInterface init finishes")
  }

  /// Callback to receive the list of achievement identifiers from Game Center
  /// - Parameters:
  ///   - allAchievements: The list of achievement descriptions
  ///   - error: Whatever error might have occurred
  func setAchievementIdentifiers(_ allAchievements: [GKAchievementDescription]?, error: Error?) {
    // I only need to set these once, since they're independent of the player
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

  /// Request the achievements of the local player from Game Center
  func loadPlayerAchievements() {
    GKAchievement.loadAchievements { [weak self] playerAchievements, error in
      self?.setPlayerAchievements(playerAchievements, error: error)
    }
  }

  /// Callback to receive the list of achievements of the local player
  /// - Parameters:
  ///   - playerAchievements: The achievements the player has earned
  ///   - error: Whatever error might have occurred
  func setPlayerAchievements(_ playerAchievements: [GKAchievement]?, error: Error?) {
    if let error = error {
      logging("Error loading Game Center player achievements: \(error.localizedDescription)")
    }
    playerAchievements?.forEach {
      self.playerAchievements[$0.identifier] = $0.percentComplete
      logging("Achievement with id \($0.identifier) is \($0.percentComplete)% complete")
    }
  }

  /// Get the status of an achievement (a percentage from 0 to 100)
  /// - Parameter identifier: The Game Center ID of the achievement
  /// - Returns: The percentage, or `nil` if uncertain
  func statusOfAchievement(_ identifier: String) -> Double? {
    if let result = playerAchievements[identifier] {
      // I got the value from the game center
      return result
    }
    guard let achievementIdentifiers = achievementIdentifiers else {
      // I don't know the valid achievements, so can't say anything
      return nil
    }
    if achievementIdentifiers.contains(identifier) {
      // This is a valid achievement, but the player had no progress so assume 0
      return 0
    }
    // No information to base a conclusion
    return nil
  }

  /// Report a simple achievement as 100% completed
  /// - Parameter identifier: The Game Center ID of the achievement
  func reportCompletion(_ identifier: String) {
    let achievement = GKAchievement(identifier: identifier)
    achievement.percentComplete = 100
    achievement.showsCompletionBanner = true
    // Mark it so that statusOfAchievement will indicate that it's done and I won't
    // report it multiple times.  If the report fails for some reason, I'll fall back
    // by sticking it in playerAchievementsProgress so that hopefully it'll get
    // reported to Game Center successfully when the game finishes.
    playerAchievements[identifier] = 100
    GKAchievement.report([achievement]) { [weak self] error in
      if let error = error {
        logging("Error reporting achievement \(identifier) to Game Center: \(error.localizedDescription)")
        // I don't know how this could happen, but stick this in with the progress
        // achievements and hope that the flush after a game finishes manages to
        // succeed.
        self?.playerAchievementsProgress[identifier] = 100
      }
    }
  }

  /// Report an achievement as partially done and return the amount of progress
  ///
  /// The amount of progress returned may be more than `knownProgress` if the player
  /// has been playing on some other device.  Whatever is calling reportProgress
  /// should update its state in such a case.  It can act as a mechanism to (at least
  /// roughly) sync progress across devices if iCloud is not available or if the
  /// iCloud and Game Center accounts don't match.
  ///
  /// This routine caches partial progress (if less than 100%), so it can be called
  /// often without worrying about actually going back-and-forth with Game Center.
  /// Call `flushProgress` to force the progress to Game Center.
  ///
  /// - Parameters:
  ///   - identifier: The Game Center ID of the achievement
  ///   - knownProgress: The percentage completion; if 100%, hands off to `reportCompletion`
  /// - Returns: The amount of progress
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

  /// Flush partial progress from `reportProgress` to Game Center
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
        // I'm not sure what can go wrong since Game Center is good about caching
        // stuff for retry transparently to us in case of network issues.  But
        // anyway, I'll leave playerAchievementsProgress alone.  Maybe the player
        // will try another game and I'll have another go at flushProgress.
      } else {
        // Move the completion amounts to playerAchievements to record that they've
        // been successfully sent to Game Center.
        for (identifier, percent) in self.playerAchievementsProgress {
          self.playerAchievements[identifier] = percent
        }
        self.playerAchievementsProgress.removeAll()
      }
    }
  }

  /// Reset all Game Center achievements
  ///
  /// Hopefully the user has confirmed they really want to do this, because there's
  /// no way back.
  func resetAchievements() {
    GKAchievement.resetAchievements { [weak self] error in
      if let error = error {
        logging("Error reseting achievements: \(error.localizedDescription)")
      } else {
        self?.playerAchievements.removeAll()
        self?.playerAchievementsProgress.removeAll()
        self?.loadPlayerAchievements()
      }
    }
  }

  /// Compute a signature for a score
  /// - Parameter score: The number of points
  func hashScore(_ score: Int) -> UInt64 {
    // Stupid hash function to compute a context that will be associated with a
    // score.  When I load a leaderboard, I toss out any scores that don't have the
    // right hash.  I don't have any control over what scores may show in Game
    // Center, but if someone has managed to somehow hack things and get a bogus
    // score accepted there, this is at least an extra little speedbump that may help
    // prevent such bogus scores from being displayed on in-game leaderboards.
    let prime64bit = UInt64(3_354_817_023_488_194_757)
    // This will overflow and give a randomish 64-bit unsigned value
    return prime64bit &* UInt64(score)
  }

  /// Report a score to Game Center and return the corresponding `GameScore`
  ///
  /// The returned score will have the player's current display name and the date
  /// that Game Center used for the score.
  ///
  /// - Parameter score: The number of points
  /// - Returns: A `GameScore` built from the `GKScore` that Game Center created
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
    // If the app was running and the player logged in, but then they put it in the
    // background, go off and change their Game Center name, and then come back and
    // play a game, the name in the high score list (which is coming from the
    // UserDefaults stuff) might not be updated with the changed name.  Reporting the
    // score gives us the updated name for the local player though, so I may as well
    // ensure that it's recorded here.  The high score list is built after saveScore,
    // so it'll get the new name.
    savePlayerName(primaryPlayerID, playerName: GKLocalPlayer.local.alias)
    return GameScore(score: gcScore)
  }

  /// Indicate whether a `GKScore` looks OK
  ///
  /// This is a pseudo-anti-cheating mechanism.  If someone managed to hack something
  /// and get Game Center to accept a bogus score, but one that doesn't have a
  /// correct hash value stored in the context, then at least we'll recognize that
  /// here.  The in-app leaderboard display can then ignore such scores.
  ///
  /// - Parameter score: A score retrieved from Game Center
  /// - Returns: `true` if the scores context matches the value from `hashScore`
  func scoreIsValid(_ score: GKScore) -> Bool {
    return score.context == hashScore(Int(score.value))
  }

  /// Print a score for debugging purposes
  /// - Parameter score: The score to display
  func printScore(_ score: GKScore?) {
    if let score = score {
      let player = score.player
      let valid = scoreIsValid(score) ? "valid" : "invalid"
      logging("player \(player.alias), score \(score.value), date \(score.date), rank \(score.rank), \(valid)")
    } else {
      logging("none")
    }
  }

  /// Request the weekly leaderboard from Game Center
  ///
  /// The results will be stored in `localPlayerScore` and `leaderboardScores`.  If
  /// an error occurs, those variables aren't changed (so hopefully the app will just
  /// display slightly out-of-date high scores).
  ///
  /// The scores get filtered through `scoreIsValid`, so the request is for 15 scores
  /// in order to try to have 10 in case a few get dropped.
  func loadLeaderboards() {
    let leaderboard = GKLeaderboard()
    leaderboard.identifier = leaderboardID
    leaderboard.playerScope = .global
    leaderboard.range = NSRange(1 ... 15)
    leaderboard.timeScope = .week
    leaderboard.loadScores() { [weak self] scores, error in
      guard let self = self else { return }
      if let error = error {
        logging("Error requesting scores from Game Center: \(error.localizedDescription)")
      } else if let scores = scores {
        self.printScore(leaderboard.localPlayerScore)
        scores.forEach { self.printScore($0) }
        self.localPlayerScore = leaderboard.localPlayerScore
        self.leaderboardScores = scores.filter { self.scoreIsValid($0) }
      }
    }
  }
}

extension Notification.Name {
  /// A notification that gets posted whenever the Game Center authentication state
  /// changes.  If a scene includes stuff like buttons that should be enabled only
  /// when Game Center is enabled, then the scene should register for this
  /// notification.
  static let authenticationChanged = Notification.Name("gcInterfaceAuthenticationChanged")
}
