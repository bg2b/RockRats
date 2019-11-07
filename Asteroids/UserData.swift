//
//  UserData.swift
//  Asteroids
//
//  Created by Daniel on 9/29/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import Foundation

struct DefaultsValue<T> {
  let name: String
  let defaultValue: T

  var value: T {
    get {
      return UserDefaults.standard.object(forKey: name) as? T ?? defaultValue
    }
    set {
      UserDefaults.standard.set(newValue, forKey: name)
    }
  }
}

// This is a counter that is keyed to the current Game Center player ID and
// synchronized between devices that are signed in to iCloud.
struct GameCounter {
  let name: String

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

// List of top scores synchronized via iCloud
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

  var highest: Int {
    let scores = value
    return scores.first?.points ?? 0
  }

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

class SavedUserData {
  var hasDoneIntro = DefaultsValue<Bool>(name: "hasDoneIntro", defaultValue: false)
  var highScores = HighScores()
  // Whoever logged into Game Center last
  var currentPlayerID = DefaultsValue<String>(name: "currentPlayerID", defaultValue: "")
  // Mapping between current player IDs and new player IDs for whenever Game Center switches over
  var newPlayerIDs = DefaultsValue<[String: String]>(name: "newPlayerIDs", defaultValue: [String: String]())
  // Mapping between player IDs and display names for high score boards
  var playerNames = DefaultsValue<[String: String]>(name: "playerNames", defaultValue: [String: String]())
  // These values are local-only and are updated during a game.
  var ufosDestroyed = DefaultsValue<Int>(name: "ufosDestroyed", defaultValue: 0)
  var asteroidsDestroyed = DefaultsValue<Int>(name: "asteroidsDestroyed", defaultValue: 0)
  // These are the persistent copies that get synced both locally (in case someone
  // logs in as a new player in Game Center) and to iCloud.
  var ufosDestroyedCounter = GameCounter(name: "ufosDestroyedCounter")
  var asteroidsDestroyedCounter = GameCounter(name: "asteroidsDestroyedCounter")
}

var userDefaults = SavedUserData()

func savePlayerName(_ playerID: String, playerName: String) {
  userDefaults.playerNames.value[playerID] = playerName
}

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
  // Synchronize in case either local or iCloud is out-of-date.
  updateGameCounters()
}

func updateGameCounters() {
  // The current counters have been updated by playing a game.  Sync them to
  // persistent storage and iCloud.
  logging("Updating game counters")
  userDefaults.ufosDestroyedCounter.value = userDefaults.ufosDestroyed.value
  userDefaults.asteroidsDestroyedCounter.value = userDefaults.asteroidsDestroyed.value
}
