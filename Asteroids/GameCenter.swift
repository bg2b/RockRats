//
//  GameCenter.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import GameKit
import os.log

extension GKPlayer {
  /// Data like counts of the number of asteroids destroyed is stored in a dictionary
  /// indexed by primaryPlayerID.  Initially primaryPlayerID was the now-deprecated
  /// `playerID`, and there was a secondaryPlayerID that returned the newly
  /// introduced `gamePlayerID` (`teamPlayerID` would have been fine too).  Mappings
  /// between the primary and secondary IDs were saved so that the counter values
  /// saved under the old playerID can be found now that use of `playerID` has been
  /// removed and the primary ID is `gamePlayerID`.  TLDR: when the user upgrades,
  /// they shouldn't lose their progress.
  var primaryPlayerID: String { gamePlayerID }
}

/// Convenience function for use in Game Center completion closures.  Shows a message
/// and returns `false` if there was an error, else returns `true`.
private func noError(_ error: Error?, in stage: String) -> Bool {
  if let error = error {
    os_log("Game Center interface %{public}s, %{public}s", log: .app, type: .error, stage, error.localizedDescription)
    return false
  } else {
    return true
  }
}

/// Convenience function that shows a message if there was an error
private func logError(_ error: Error?, in stage: String) {
  _ = noError(error, in: stage)
}

/// Compute a signature for a score
/// - Parameter score: The number of points
private func hashScore(_ score: Int) -> Int {
  // Stupid hash function to compute a context that will be associated with a
  // score.  When I load a leaderboard, I toss out any scores that don't have the
  // right hash.  I don't have any control over what scores may show in Game
  // Center, but if someone has managed to somehow hack things and get a bogus
  // score accepted there, this is at least an extra little speedbump that may help
  // prevent such bogus scores from being displayed on in-game leaderboards.
  let prime64bit = UInt64(3_354_817_023_488_194_757)
  // This will overflow and give a randomish 64-bit unsigned value, which is
  // converted by truncating.  Game Center used to use 64-bit contexts, but now the
  // prototype is a regular Int.
  return Int(truncatingIfNeeded: prime64bit &* UInt64(score))
}

// MARK: - Game Center

/// This is a wrapper around the Game Center functionality.  It interfaces with the
/// authentication mechanism, informs the app of who's playing, keeps track of what
/// achievements are available and what progress the player has made in them, loads
/// leaderboards, and passes scores back to Game Center.
class GameCenterInterface {
  /// A closure that will do something appropriate with the Game Center's
  /// authentication view controller if there's no logged-in player.  Typically the
  /// closure would squirrel the controller away so that it can be presented at some
  /// appropriate point.
  let presenter: (UIViewController?) -> Void
  /// The primary ID of whoever successfully logged in last
  var lastPlayerID: String?
  /// A set of all the valid achievement identifiers, retrieved from Game Center.
  var achievementIdentifiers: Set<String>?
  /// The identifiers of all the local player's achievements and their completion
  /// percentages as retrieved from Game Center.  If the player has zero percent on
  /// some achievement, it's not in the dictionary.
  var playerAchievements = [String: Double]()
  /// Used to record the percent progress of the player towards levelled achievements
  /// when playing.  Flushed to Game Center if their progress reaches 100%, and also
  /// flushed at the end of a game.
  var playerAchievementsProgress = [String: Double]()
  /// The leaderboards that the game uses
  let leaderboards: [String: GameCenterLeaderboard]

  /// Is Game Center enabled (i.e., there's an authenticated local player)?
  var enabled: Bool { GKLocalPlayer.local.isAuthenticated }
  /// The primary ID of the authenticated player (valid when `enabled`)
  var playerID: String { GKLocalPlayer.local.primaryPlayerID }
  /// This is the name to address the player by
  var playerName: String { enabled ? GKLocalPlayer.local.alias : "Anonymous" }

  /// Initialize the Game Center interface.  This should be a singleton
  /// - Parameters:
  ///   - leaderboardNamesAndIDs: The names used to refer to leaderboards and the leaderboard IDs
  ///   - presenter: A closure that should receive Game Center's authentication view controller
  ///   - gcvc: Show this view controller to authenticate to Game Center, `nil` means don't show anything
  init(leaderboardNamesAndIDs: [(String, String)], presenter: @escaping (_ gcvc: UIViewController?) -> Void) {
    self.leaderboards = Dictionary(uniqueKeysWithValues: leaderboardNamesAndIDs.map { ($0.0, GameCenterLeaderboard($0.1)) })
    self.presenter = presenter
    os_log("GameCenterInterface init", log: .app, type: .debug)
    GKLocalPlayer.local.authenticateHandler = { [unowned self] gcAuthorizationViewController, error in
      os_log("GKLocalPlayer authenticate handler called", log: .app, type: .debug)
      self.presenter(gcAuthorizationViewController)
      logError(error, in: "authentication")
      os_log("Game Center is %{public}s", log: .app, type: .info, self.enabled ? "enabled" : "not enabled")
      if self.enabled {
        if self.achievementIdentifiers == nil {
          GKAchievementDescription.loadAchievementDescriptions { [weak self] allAchievements, error in
            self?.setAchievementIdentifiers(allAchievements, error: error)
          }
        }
        if self.playerID != self.lastPlayerID {
          self.playerAchievements.removeAll()
          self.playerAchievementsProgress.removeAll()
          self.lastPlayerID = self.playerID
          for (_, leaderboard) in self.leaderboards {
            leaderboard.clear()
          }
        }
        // I use alias instead of displayName deliberately, since I don't like the
        // display name of "Me" from iOS 12.
        setCurrentPlayer(self.playerID, playerName: GKLocalPlayer.local.alias)
        self.loadPlayerAchievements()
        self.loadLeaderboards()
      } else {
        setCurrentPlayer("anon", playerName: "Anonymous")
        self.playerAchievements.removeAll()
        self.playerAchievementsProgress.removeAll()
        for (_, leaderboard) in self.leaderboards {
          leaderboard.clear()
        }
      }
      NotificationCenter.default.post(name: .authenticationChanged, object: self.enabled)
    }
  }

  /// Callback to receive the list of achievement identifiers from Game Center
  /// - Parameters:
  ///   - allAchievements: The list of achievement descriptions
  ///   - error: Whatever error might have occurred
  func setAchievementIdentifiers(_ allAchievements: [GKAchievementDescription]?, error: Error?) {
    // I only need to set these once, since they're independent of the player
    if noError(error, in: "loading achievement IDs") {
      guard let allAchievements = allAchievements else { return }
      achievementIdentifiers = Set<String>(allAchievements.map { $0.identifier })
    }
  }

  /// Request the achievements of the local player from Game Center
  func loadPlayerAchievements() {
    GKAchievement.loadAchievements { [weak self] playerAchievements, error in
      guard let self = self else { return }
      logError(error, in: "loading player achievements")
      playerAchievements?.forEach {
        self.playerAchievements[$0.identifier] = $0.percentComplete
        os_log("Achievement %{public}s is %.2f%% complete", log: .app, type: .info, $0.identifier, $0.percentComplete)
      }
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
  func reportCompletion(_ identifier: String, showBanner: Bool = true) {
    let achievement = GKAchievement(identifier: identifier)
    achievement.percentComplete = 100
    achievement.showsCompletionBanner = showBanner
    // Mark it so that statusOfAchievement will indicate that it's done and I won't
    // report it multiple times.  If the report fails for some reason, I'll fall back
    // by sticking it in playerAchievementsProgress so that hopefully it'll get
    // reported to Game Center successfully when the game finishes.
    playerAchievements[identifier] = 100
    GKAchievement.report([achievement]) { [weak self] error in
      guard let self = self else { return }
      if !noError(error, in: "reporting achivement \(identifier)") {
        // I don't know how this could happen, but stick this in with the progress
        // achievements and hope that the flush after a game finishes manages to
        // succeed.
        self.playerAchievementsProgress[identifier] = 100
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
      os_log("Achievement %{public}s at %.2f%%", log: .app, type: .debug, identifier, percent)
      achievement.showsCompletionBanner = true
      achievements.append(achievement)
    }
    GKAchievement.report(achievements) { [weak self] error in
      guard let self = self else { return }
      // I'm not sure what can go wrong since Game Center is good about caching stuff
      // for retry transparently to us in case of network issues.  But anyway, I'll
      // leave playerAchievementsProgress alone if there is some error.  Maybe the
      // player will try another game and I'll have another go at flushProgress.
      if noError(error, in: "reporting progress achievements") {
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
      guard let self = self else { return }
      if noError(error, in: "resetting achievements") {
        self.playerAchievements.removeAll()
        self.playerAchievementsProgress.removeAll()
        self.loadPlayerAchievements()
      }
    }
  }

  /// Report a score to all the leaderboards at once
  /// - Parameter score: the number of points
  func saveScore(_ score: Int) {
    let leaderboardIDs = leaderboards.map { _, leaderboard in
      leaderboard.ID
    }
    // The hope is that this will turn into a single network call under the hood,
    // whereas I'm not sure about calling `saveScore` on all the individual
    // leaderboards.
    GKLeaderboard.submitScore(score,
                              context: hashScore(score),
                              player: GKLocalPlayer.local,
                              leaderboardIDs: leaderboardIDs) { error in
      logError(error, in: "reporting score to leaderboards")
    }
  }

  /// Find the leaderboard with a given name (must exist)
  /// - Parameter name: The name for the leaderboard
  func leaderboard(_ name: String) -> GameCenterLeaderboard {
    guard let leaderboard = leaderboards[name] else {
      fatalError("no leaderboard named \(name)")
    }
    return leaderboard
  }

  /// Load all leaderboards
  func loadLeaderboards() {
    for (_, leaderboard) in leaderboards {
      leaderboard.load()
    }
  }
}

// MARK: - Game Center leaderboards

/// This is a wrapper around a single `GKLeaderboard`.  It handles reporting scores
/// and loading entries.
class GameCenterLeaderboard {
  /// The leaderboard ID
  let ID: String
  /// The actual `GKLeaderboard` after loading
  var leaderboard: GKLeaderboard?
  /// The local player's score on the leaderboard, after scores have loaded
  var localPlayerEntry: GKLeaderboard.Entry?
  /// Entries on the leaderboard, after scores have loaded
  var entries: [GKLeaderboard.Entry]?

  /// Record the Game Center leaderboard ID and load the leaderboard
  /// - Parameter ID: The leaderboard ID set up in App Store Connect
  init(_ ID: String) {
    self.ID = ID
    self.load()
  }

  /// Report a score to Game Center
  /// - Parameter score: The number of points
  func saveScore(_ score: Int) {
    os_log("Reporting score %d to %{public}s", log: .app, type: .info, score, ID)
    leaderboard?.submitScore(score, context: hashScore(score), player: GKLocalPlayer.local) { [weak self] error in
      guard let self else { return }
      logError(error, in: "reporting score to \(self.ID)")
    }
  }

  /// Indicate whether a score looks OK
  ///
  /// This is a pseudo-anti-cheating mechanism.  If someone managed to hack something
  /// and get Game Center to accept a bogus score, but one that doesn't have a
  /// correct hash value stored in the context, then at least we'll recognize that
  /// here.  The in-app leaderboard display can then ignore such scores.
  ///
  /// - Parameters:
  ///   - score: A score supposedly retrieved from Game Center
  ///   - context: The context from the Game Center entry
  /// - Returns: `true` if the context matches the value from `hashScore`
  func scoreIsValid(_ score: Int, context: Int) -> Bool {
    return context == hashScore(score)
  }

  /// Print a score for debugging purposes
  /// - Parameter score: The score to display
  func printEntry(_ entry: GKLeaderboard.Entry?) {
    if let entry {
      let player = entry.player
      let valid = scoreIsValid(entry.score, context: entry.context) ? "valid" : "invalid"
      os_log("player %{public}s got %{public}s score %d, rank %d",
             log: .app, type: .debug, player.alias, valid, entry.score, entry.rank)
    }
  }

  /// If the leaderboard (the `GKLeaderboard`, not the actual entries) has not been
  /// loaded, then load that.  Else load the top scores for the leaderboard.
  func load() {
    if let gc = Globals.gcInterface, gc.enabled {
      if let leaderboard {
        // The leaderboard has been loaded, so load the actual entries
        let range = NSRange(1 ... 10)
        leaderboard.loadEntries(for: .global, timeScope: .allTime, range: range) { [weak self] localPlayerEntry, entries, _, error in
          guard let self else { return }
          if noError(error, in: "loading \(self.ID) entries") {
            os_log("leaderboard %{public}s entries loaded", log: .app, type: .debug, self.ID)
            // localPlayerEntry for an empty leaderboard seems to come back with
            // player Anonymous and a score of 0?  Force it to be nil in the player
            // doesn't match the local player.
            self.localPlayerEntry = localPlayerEntry?.player == GKLocalPlayer.local ? localPlayerEntry : nil
            self.printEntry(self.localPlayerEntry)
            entries?.forEach { self.printEntry($0) }
            self.entries = entries
          }
        }
      } else {
        // Find the leaderboard for the ID
        GKLeaderboard.loadLeaderboards(IDs: [ID]) { [weak self] leaderboards, error in
          guard let self else { return }
          logError(error, in: "loading \(self.ID)")
          self.leaderboard = leaderboards?.first
          if self.leaderboard != nil {
            // Leaderboard is now valid, so load the top entries
            self.load()
          }
        }
      }
    } else {
      // Game Center is disabled
      clear()
    }
  }

  /// Clear leaderboard info, used when Game Center is disabled
  func clear() {
    leaderboard = nil
    localPlayerEntry = nil
    entries = nil
  }

  /// Get the valid leaderboard entries, assuming they've been loaded.  This filters
  /// out anything where the context doesn't match the number of points.
  func scores() -> [GKLeaderboard.Entry]? {
    return entries?.filter { entry in
      scoreIsValid(entry.score, context: entry.context)
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
