//
//  UserData.swift
//  Asteroids
//
//  Created by Daniel on 9/29/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import Foundation

/// A value that is saved in UserDefaults.standard.  Holds the name for the value (a
/// string) and a default value of the appropriate type.
struct DefaultsValue<T> {
  let name: String
  let defaultValue: T

  /// Retrieves the stored value or (returns the default) on get, stores a new value
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
  let name: String

  /// Retrieving a GameCounter returns the maximum value of local and iCloud versions
  /// for the current player.  Setting it provides a new lower bound value (which will
  /// typically be the new max) and synchronizes local and iCloud storage.
  var value: Int {
    get {
      let playerID = userDefaults.currentPlayerID.value
      let localDict = UserDefaults.standard.object(forKey: name) as? [String: Int] ?? [String: Int]()
      let iCloudDict = NSUbiquitousKeyValueStore.default.object(forKey: name) as? [String: Int] ?? [String: Int]()
      let local = localDict[playerID] ?? 0
      let iCloud = iCloudDict[playerID] ?? 0
      let result = max(local, iCloud)
      logging("Read counter \(name) for \(playerID): local \(local), iCloud \(iCloud), result \(result)")
      return result
    }
    set {
      let playerID = userDefaults.currentPlayerID.value
      logging("Set counter \(name) for \(playerID) to \(newValue)")
      var mergedDict = UserDefaults.standard.object(forKey: name) as? [String: Int] ?? [String: Int]()
      let iCloudDict = NSUbiquitousKeyValueStore.default.object(forKey: name) as? [String: Int] ?? [String: Int]()
      for (iCloudKey, iCloudValue) in iCloudDict {
        mergedDict[iCloudKey] = max(mergedDict[iCloudKey] ?? 0, iCloudValue)
      }
      let mergedValue = max(mergedDict[playerID] ?? 0, newValue)
      mergedDict[playerID] = mergedValue
      for (key, value) in mergedDict {
        logging("Merged: player \(key), count \(value)")
      }
      UserDefaults.standard.set(mergedDict, forKey: name)
      NSUbiquitousKeyValueStore.default.set(mergedDict, forKey: name)
    }
  }
}

/// A list of top scores by players that have played on this device, or on another
/// device that is signed in to the same iCloud account.  This is synchronized via
/// iCloud.
struct HighScores {
  static let maxScores = 10

  func writeBack(_ highScores: [GameScore]) {
    logging("Saving \(highScores.count) high scores")
    let encoded = highScores.map { $0.encode() }
    UserDefaults.standard.set(encoded, forKey: "highScores")
    NSUbiquitousKeyValueStore.default.set(encoded, forKey: "highScores")
  }

  func sortedAndTrimmed(_ highScores: [GameScore]) -> [GameScore] {
    var sorted = highScores.sorted { $0.points > $1.points }
    if sorted.count > HighScores.maxScores {
      sorted.removeLast(sorted.count - HighScores.maxScores)
    }
    return sorted
  }

  func updateNames(_ highScores: [GameScore]) -> [GameScore] {
    return highScores.map { score in
      if let name = userDefaults.playerNames.value[score.playerID], score.playerName != name {
        return GameScore(score: score, newName: name)
      } else {
        return score
      }
    }
  }

  /// Gets the local high scores.  Also handles updating names and synchronizing
  /// iCloud-backed and local storage.
  var value: [GameScore] {
    get {
      let local = UserDefaults.standard.object(forKey: "highScores") as? [[String: Any]] ?? [[String: Any]]()
      let localScores = local.compactMap { GameScore(fromDict: $0) }
      let global = NSUbiquitousKeyValueStore.default.object(forKey: "highScores") as? [[String: Any]] ?? [[String: Any]]()
      let globalScores = global.compactMap { GameScore(fromDict: $0) }
      var highScores = localScores
      for score in globalScores {
        if (highScores.firstIndex { sameScore(score, $0) }) == nil {
          highScores.append(score)
        }
      }
      highScores = sortedAndTrimmed(highScores)
      highScores = updateNames(highScores)
      if highScores != localScores || highScores != globalScores {
        writeBack(highScores)
      }
      return highScores
    }
  }

  /// The highest all-time local score
  var highest: Int {
    let scores = value
    return scores.first?.points ?? 0
  }

  /// See if the score for a just-completed game is sufficien to make the high scores
  /// list.  If so, store it and sync back to iCloud.
  /// - Parameter score: The score that the player achieved
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
}

/// Things that are saved to UserDefaults.standard for persistence.  Some of these
/// things are also synchronized via iCloud across devices.  Should be a singleton.
class SavedUserData {
  /// True when the intro scene has been played on this device
  var hasDoneIntro = DefaultsValue<Bool>(name: "hasDoneIntro", defaultValue: false)
  /// Audio off/on preference
  var audioIsMuted = DefaultsValue<Bool>(name: "audioIsMuted", defaultValue: false)
  /// Local player high scores (not global scores from Game Center)
  var highScores = HighScores()
  /// Whoever logged into Game Center last.  If Game Center isn't available for some
  /// reason, then we assume that the person playing is this player.
  var currentPlayerID = DefaultsValue<String>(name: "currentPlayerID", defaultValue: "")
  /// Mapping between current player IDs and new player IDs for whenever Game Center
  /// switches over
  var newPlayerIDs = DefaultsValue<[String: String]>(name: "newPlayerIDs", defaultValue: [String: String]())
  /// Mapping between player IDs and display names for high score boards.  We use
  /// this to just save names for the local players rather than relying on being able
  /// to load stuff from Game Center.
  var playerNames = DefaultsValue<[String: String]>(name: "playerNames", defaultValue: [String: String]())
  /// A local-only copy of ufosDestroyedCounter that is updated during a game
  var ufosDestroyed = DefaultsValue<Int>(name: "ufosDestroyed", defaultValue: 0)
  /// A local-only copy of asteroidsDestroyedCounter that is updated during a game
  var asteroidsDestroyed = DefaultsValue<Int>(name: "asteroidsDestroyed", defaultValue: 0)
  /// Mapping between player IDs and the total number of UFOs they've destroyed.
  /// Used for different levels of UFO destruction achievements.
  var ufosDestroyedCounter = GameCounter(name: "ufosDestroyedCounter")
  /// Mapping between player IDs and the total number of asteroids they've destroyed.
  /// Used for different levels of asteroid destruction achievements.
  var asteroidsDestroyedCounter = GameCounter(name: "asteroidsDestroyedCounter")
}

/// Singleton for saving persistent and synchronized information and settings
var userDefaults = SavedUserData()

/// Save a name to be displayed for the given player ID.  These are used by
/// HighScores when it returns a list of the high scores for local players.
/// - Parameters:
///   - playerID: The player ID from Game Center
///   - playerName: The name to be shown (i.e. displayName in the GKPlayer structure)
func savePlayerName(_ playerID: String, playerName: String) {
  userDefaults.playerNames.value[playerID] = playerName
}

/// Called by the Game Center interface when a new player authenticates.
/// - Parameters:
///   - playerID: ID for the player that just logged in
///   - playerName: The name that should be used for the player (their displayName)
///   - alternatePlayerID: An optional alternate ID that should be saved for
///     transitioning persistent state when the deprecated GKPlayer playerID is no
///     longer available
func setCurrentPlayer(_ playerID: String, playerName: String, alternatePlayerID: String?) {
  // Someone logged in on Game Center; make sure we have the right counters for them.
  userDefaults.currentPlayerID.value = playerID
  savePlayerName(playerID, playerName: playerName)
  if let alternatePlayerID = alternatePlayerID {
    userDefaults.newPlayerIDs.value[playerID] = alternatePlayerID
  }
  logging("Player is now \(playerID) (alternate \(alternatePlayerID ?? "<none>")), name \(playerName)")
  userDefaults.ufosDestroyed.value = userDefaults.ufosDestroyedCounter.value
  userDefaults.asteroidsDestroyed.value = userDefaults.asteroidsDestroyedCounter.value
  logging("UFO counter \(userDefaults.ufosDestroyed.value), asteroid counter \(userDefaults.asteroidsDestroyed.value)")
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
  logging("Updating game counters")
  userDefaults.ufosDestroyedCounter.value = userDefaults.ufosDestroyed.value
  userDefaults.asteroidsDestroyedCounter.value = userDefaults.asteroidsDestroyed.value
  // If by some chance the same person has been playing on another device, store the
  // new values back in the local counters.
  userDefaults.ufosDestroyed.value = userDefaults.ufosDestroyedCounter.value
  userDefaults.asteroidsDestroyed.value = userDefaults.asteroidsDestroyedCounter.value
}
