//
//  UserData.swift
//  Asteroids
//
//  Created by Daniel on 9/29/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import Foundation
import os.log

/// A value that is saved in UserDefaults.standard.  Holds the name for the value (a
/// string) and a default value of the appropriate type.
struct DefaultsValue<T> {
  let name: String
  let defaultValue: T

  /// Retrieves the stored value (or returns the default) on get, stores a new value
  /// on set.
  var value: T {
    get {
      return UserDefaults.standard.object(forKey: name) as? T ?? defaultValue
    }
    set {
      UserDefaults.standard.set(newValue, forKey: name)
    }
  }
}

/// This is a counter that is keyed to the current Game Center player ID and
/// synchronized between devices that are signed in to iCloud.
struct GameCounter {
  /// The counter name
  let name: String

  /// The key for the counter's generation, used to tell which data to use in the
  /// case of a reset
  var dateKey: String { return name + "Date" }

  /// Return a merged dictionary mapping player IDs to counter values
  func mergedDict() -> [String: Int] {
    let localDict = UserDefaults.standard.object(forKey: name) as? [String: Int] ?? [String: Int]()
    let localDate = UserDefaults.standard.double(forKey: dateKey)
    let globalDict = NSUbiquitousKeyValueStore.default.object(forKey: name) as? [String: Int] ?? [String: Int]()
    let globalDate = NSUbiquitousKeyValueStore.default.double(forKey: dateKey)
    if localDate != globalDate {
      os_log("Merging %{public}s, local date %f, global date %f", log: .app, type: .debug, name, localDate, globalDate)
    }
    var result = localDict
    for (globalKey, globalValue) in globalDict {
      if localDate < globalDate {
        // iCloud has the data, typically because a counter was reset on another device
        result[globalKey] = globalValue
      } else {
        // Same generation, merge by taking the max
        result[globalKey] = max(result[globalKey] ?? 0, globalValue)
      }
    }
    if localDate < globalDate {
      // Update generation
      UserDefaults.standard.set(globalDate, forKey: dateKey)
    }
    if localDict != result {
      UserDefaults.standard.set(result, forKey: name)
    }
    if globalDict != result {
      NSUbiquitousKeyValueStore.default.set(result, forKey: name)
    }
    for (key, value) in result {
      let local = localDict[key] ?? -1
      let global = globalDict[key] ?? -1
      if value != local || value != global {
        os_log("Merged %{public}s: %s (%d, %d) => %d",
               log: .app, type: .debug, name, key, local, global, value)
      }
    }
    return result
  }

  /// Retrieving a GameCounter returns the maximum value of local and iCloud versions
  /// for the current player.  Setting it provides a new lower bound value (which will
  /// typically be the new max) and synchronizes local and iCloud storage.
  ///
  /// As a special case, setting the counter to a negative value resets it to zero.
  var value: Int {
    get {
      let merged = mergedDict()
      let playerID = UserData.currentPlayerID.value
      let result = merged[playerID] ?? 0
      os_log("%{public}s for %s is %d", log: .app, type: .debug, name, playerID, result)
      return result
    }
    set {
      var merged = mergedDict()
      let playerID = UserData.currentPlayerID.value
      os_log("Set %{public}s for %s to %d", log: .app, type: .debug, name, playerID, newValue)
      merged[playerID] = newValue < 0 ? 0 : max(merged[playerID] ?? 0, newValue)
      UserDefaults.standard.set(merged, forKey: name)
      NSUbiquitousKeyValueStore.default.set(merged, forKey: name)
    }
  }

  /// Zero the counter and start a new generation
  ///
  /// This should be called when the player resets their Game Center progress,
  /// otherwise the multi-level achievements that depend on counter values would
  /// immediately jump forward again.
   mutating func reset() {
    value = -1
    // Set a new generation in iCloud to ensure that the reset value will take
    // precedence if the user plays on another device
    let now = Date().timeIntervalSinceReferenceDate
    UserDefaults.standard.set(now, forKey: dateKey)
    NSUbiquitousKeyValueStore.default.set(now, forKey: dateKey)
  }

  /// Reset the generation of the counter (for testing only)
  mutating func resetGeneration() {
    UserDefaults.standard.set(0.0, forKey: dateKey)
    NSUbiquitousKeyValueStore.default.set(0.0, forKey: dateKey)
  }
}

/// A list of top scores by players that have played on this device, or on another
/// device that is signed in to the same iCloud account.  This is synchronized via
/// iCloud.
struct HighScores {
  static let maxScores = 10

  /// Write scores in UserDefaults and iCloud
  /// - Parameter highScores: The scores to encode and save
  func writeBack(_ highScores: [GameScore]) {
    os_log("Saving %d high scores", log: .app, type: .debug, highScores.count)
    let encoded = highScores.map { $0.encode() }
    UserDefaults.standard.set(encoded, forKey: "highScores")
    NSUbiquitousKeyValueStore.default.set(encoded, forKey: "highScores")
  }

  /// Keep only a limited number of high scores
  /// - Parameter highScores: An array of scores
  /// - Returns: The highest scores (sorted) and limited to `maxScores` in number
  func sortedAndTrimmed(_ highScores: [GameScore]) -> [GameScore] {
    var sorted = highScores.sorted { $0.points > $1.points }
    if sorted.count > HighScores.maxScores {
      sorted.removeLast(sorted.count - HighScores.maxScores)
    }
    return sorted
  }

  /// Update player names in a list of scores
  /// - Parameter highScores: The high scores
  /// - Returns: The scores, but with player names replaced by whatever is currently known
  func updateNames(_ highScores: [GameScore]) -> [GameScore] {
    return highScores.map { score in
      if let name = UserData.playerNames.value[score.playerID], score.playerName != name {
        return GameScore(score: score, newName: name)
      } else {
        return score
      }
    }
  }

  /// Gets the local high scores.  Also handles updating names and synchronizing
  /// iCloud-backed and local storage.
  var value: [GameScore] {
    let local = UserDefaults.standard.object(forKey: "highScores") as? [[String: Any]] ?? [[String: Any]]()
    let localScores = local.compactMap { GameScore(fromDict: $0) }
    let localDate = UserDefaults.standard.double(forKey: "highScoresDate")
    let global = NSUbiquitousKeyValueStore.default.object(forKey: "highScores") as? [[String: Any]] ?? [[String: Any]]()
    let globalScores = global.compactMap { GameScore(fromDict: $0) }
    let globalDate = NSUbiquitousKeyValueStore.default.double(forKey: "highScoresDate")
    if localDate != globalDate {
      os_log("Merging high scores, local date %f, global date %f", log: .app, type: .debug, localDate, globalDate)
    }
    var highScores: [GameScore]
    if localDate < globalDate {
      // iCloud has the relevant data.  This happens if the scores get reset on a
      // different device.
      highScores = globalScores
      UserDefaults.standard.set(globalDate, forKey: "highScoresDate")
    } else {
      // iCloud and the local scores come from the same generation, so merge
      highScores = localScores
      for score in globalScores {
        if (highScores.firstIndex { sameScore(score, $0) }) == nil {
          highScores.append(score)
        }
      }
    }
    highScores = sortedAndTrimmed(highScores)
    highScores = updateNames(highScores)
    if highScores != localScores || highScores != globalScores {
      for score in highScores {
        os_log("Merged high score %{public}s %d", log: .app, type: .debug, score.playerName ?? "unknown", score.points)
      }
      writeBack(highScores)
    }
    return highScores
  }

  /// The highest all-time local score
  var highest: Int {
    let scores = value
    return scores.first?.points ?? 0
  }

  /// See if the score for a just-completed game is sufficien to make the high scores
  /// list.  If so, store it and sync back to iCloud.
  /// - Parameter score: The new score that the player achieved
  /// - Returns: The array of high scores, possibly including the new score
  func addScore(_ score: GameScore) -> [GameScore] {
    var highScores = value
    if (highScores.last?.points ?? 0) > score.points && highScores.count >= HighScores.maxScores {
      // This score is not sufficient to make the high scores.
      return highScores
    }
    highScores.append(score)
    highScores = sortedAndTrimmed(highScores)
    writeBack(highScores)
    return highScores
  }

  /// Clear out all high scores
  func reset() {
    // Start a new generation so when scores get synced to other devices, these will
    // take precedence.
    let now = Date().timeIntervalSinceReferenceDate
    UserDefaults.standard.set(now, forKey: "highScoresDate")
    NSUbiquitousKeyValueStore.default.set(now, forKey: "highScoresDate")
    writeBack([])
  }

  /// Reset the generation for high scores (used for testing only)
  func resetGeneration() {
    UserDefaults.standard.set(0.0, forKey: "highScoresDate")
    NSUbiquitousKeyValueStore.default.set(0.0, forKey: "highScoresDate")
  }
}

/// Things that are saved to UserDefaults.standard for persistence
///
/// Some of these are also synchronized via iCloud across devices
class UserData {
  /// `true` when the intro scene has been played on this device
  static var hasDoneIntro = DefaultsValue<Bool>(name: "hasDoneIntro", defaultValue: false)
  /// Audio volume preference
  static var audioLevel = DefaultsValue<Int>(name: "audioLevel", defaultValue: 2)
  /// UFO engine sound fade after launch preference
  static var fadeUFOAudio = DefaultsValue<Bool>(name: "fadeUFOAudio", defaultValue: false)
  /// Heartbeat on/off preference
  static var heartbeatMuted = DefaultsValue<Bool>(name: "heartbeatMuted", defaultValue: false)
  /// `true` if the joystick is on the left
  static var joystickOnLeft = DefaultsValue<Bool>(name: "controlsOnLeft", defaultValue: true)
  /// Retro mode preference (ignored if Game Center is disabled or the player does
  /// not have the blastFromThePast achievement)
  static var retroMode = DefaultsValue<Bool>(name: "retroMode", defaultValue: false)
  /// Color of the player's ship (ignored if the desired color isn't unlocked by
  /// spaceAce, galacticGuardian, or cosmicChampion)
  static var shipColor = DefaultsValue<String>(name: "shipColor", defaultValue: "blue")
  /// Number of games played on this device
  static var gamesPlayed = DefaultsValue<Int>(name: "gamesPlayed", defaultValue: 0)
  /// Number of games played when a review was last requested
  static var gamesPlayedWhenReviewRequested = DefaultsValue<Int>(name: "gamesPlayedWhenReviewRequested", defaultValue: 0)
  /// Number of times a review has been requested
  static var reviewsRequested = DefaultsValue<Int>(name: "reviewsRequested", defaultValue: 0)
  /// Local player high scores (not global scores from Game Center)
  static var highScores = HighScores()
  /// Whoever is logged into Game Center, or "anon" if no one
  static var currentPlayerID = DefaultsValue<String>(name: "currentPlayerID", defaultValue: "anon")
  /// Mapping between current player IDs and new player IDs for whenever Game Center
  /// switches over
  static var newPlayerIDs = DefaultsValue<[String: String]>(name: "newPlayerIDs", defaultValue: [String: String]())
  /// Mapping between player IDs and display names for high score boards.  I use this
  /// to just save names for the local players rather than relying on being able to
  /// load stuff from Game Center.
  static var playerNames = DefaultsValue<[String: String]>(name: "playerNames", defaultValue: [String: String]())
  /// A local-only copy of ufosDestroyedCounter that is updated during a game
  static var ufosDestroyed = DefaultsValue<Int>(name: "ufosDestroyed", defaultValue: 0)
  /// A local-only copy of asteroidsDestroyedCounter that is updated during a game
  static var asteroidsDestroyed = DefaultsValue<Int>(name: "asteroidsDestroyed", defaultValue: 0)
  /// Mapping between player IDs and the total number of UFOs they've destroyed.
  /// Used for different levels of UFO destruction achievements (synced via iCloud)
  static var ufosDestroyedCounter = GameCounter(name: "ufosDestroyedCounter")
  /// Mapping between player IDs and the total number of asteroids they've destroyed.
  /// Used for different levels of asteroid destruction achievements (synced via
  /// iCloud)
  static var asteroidsDestroyedCounter = GameCounter(name: "asteroidsDestroyedCounter")
}

/// Save a name to be displayed for the given player ID.  These are used by
/// HighScores when it returns a list of the high scores for local players.
///
/// I originally was using `displayName` instead of `alias`, and an argument could be
/// made for that, but under iOS 12, the "Me" for display name is kind of ugly.
///
/// - Parameters:
///   - playerID: The player ID from Game Center
///   - playerName: The name to be shown (the `alias` in the `GKPlayer` structure)
func savePlayerName(_ playerID: String, playerName: String) {
  UserData.playerNames.value[playerID] = playerName
}

/// Called by the Game Center interface when a new player authenticates.
/// - Parameters:
///   - playerID: ID for the player that just logged in
///   - playerName: The name that should be used for the player (their alias)
///   - alternatePlayerID: An optional alternate ID that should be saved for
///     transitioning persistent state when the deprecated `GKPlayer` `playerID` is
///     no longer available
func setCurrentPlayer(_ playerID: String, playerName: String, alternatePlayerID: String?) {
  // Someone logged in on Game Center; make sure we have the right counters for them.
  UserData.currentPlayerID.value = playerID
  savePlayerName(playerID, playerName: playerName)
  if let alternatePlayerID = alternatePlayerID {
    UserData.newPlayerIDs.value[playerID] = alternatePlayerID
  }
  os_log("Player is now %s (alternate %s), name %s", log: .app, type: .debug, playerID, alternatePlayerID ?? "<none>", playerName)
  UserData.ufosDestroyed.value = UserData.ufosDestroyedCounter.value
  UserData.asteroidsDestroyed.value = UserData.asteroidsDestroyedCounter.value
  os_log("UFO counter %d, asteroid counter %d", log: .app, type: .debug, UserData.ufosDestroyed.value, UserData.asteroidsDestroyed.value)
  // Synchronize in case either local or iCloud was out-of-date.
  updateGameCounters()
}

/// Synchronize local counters (for asteroids and UFOs destroyed) with the main
/// counters.  Typically this would just copy the local counters at the end of a game
/// to the iCloud-backed main ones, but if the same player has been playing on
/// another device, it could actually go the other way.
func updateGameCounters() {
  // The current counters have been updated by playing a game.  Sync them to
  // persistent storage and iCloud.
  os_log("Updating game counters", log: .app, type: .debug)
  UserData.ufosDestroyedCounter.value = UserData.ufosDestroyed.value
  UserData.asteroidsDestroyedCounter.value = UserData.asteroidsDestroyed.value
  // If by some chance the same person has been playing on another device, store the
  // new values back in the local counters.
  UserData.ufosDestroyed.value = UserData.ufosDestroyedCounter.value
  UserData.asteroidsDestroyed.value = UserData.asteroidsDestroyedCounter.value
}

/// Reset the generation number for iCloud-synced stuff
///
/// This is only used for testing purposes.
func resetGenerations() {
  UserData.highScores.resetGeneration()
  UserData.ufosDestroyedCounter.resetGeneration()
  UserData.asteroidsDestroyedCounter.resetGeneration()
}
