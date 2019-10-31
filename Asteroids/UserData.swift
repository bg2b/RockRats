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
      let alternatePlayerID = userDefaults.currentAlternatePlayerID.value
      logging("Set counter \(name) for \(playerID) (alternate \(alternatePlayerID) to \(newValue)")
      var mergedDict = UserDefaults.standard.object(forKey: name) as? [String: Int] ?? [String: Int]()
      let iCloudDict = NSUbiquitousKeyValueStore.default.object(forKey: name) as? [String: Int] ?? [String: Int]()
      for (iCloudKey, iCloudValue) in iCloudDict {
        mergedDict[iCloudKey] = max(mergedDict[iCloudKey] ?? 0, iCloudValue)
      }
      let mergedValue = max(mergedDict[playerID] ?? 0, newValue)
      mergedDict[playerID] = mergedValue
      if alternatePlayerID != "<none>" {
        // In the future, the Game Center ID we see may change to the alternate ID.
        // Save the counter under both IDs so that when the day comes to switch, the
        // player's progress won't reset.
        mergedDict[alternatePlayerID] = mergedValue
      }
      for (key, value) in mergedDict {
        logging("Merged: player \(key), count \(value)")
      }
      UserDefaults.standard.set(mergedDict, forKey: name)
      NSUbiquitousKeyValueStore.default.set(mergedDict, forKey: name)
    }
  }
}

class SavedUserData {
  var highScore = DefaultsValue<Int>(name: "highScore", defaultValue: 0)
  var hasDoneIntro = DefaultsValue<Bool>(name: "hasDoneIntro", defaultValue: false)
  var currentPlayerID = DefaultsValue<String>(name: "currentPlayerID", defaultValue: "")
  var currentAlternatePlayerID = DefaultsValue<String>(name: "currentAlternatePlayerID", defaultValue: "<none>")
  // These values are local-only and are updated during a game.
  var ufosDestroyed = DefaultsValue<Int>(name: "ufosDestroyed", defaultValue: 0)
  var asteroidsDestroyed = DefaultsValue<Int>(name: "asteroidsDestroyed", defaultValue: 0)
  // These are the persistent copies that get synced both locally (in case someone
  // logs in as a new player in Game Center) and to iCloud.
  var ufosDestroyedCounter = GameCounter(name: "ufosDestroyedCounter")
  var asteroidsDestroyedCounter = GameCounter(name: "asteroidsDestroyedCounter")
}

var userDefaults = SavedUserData()

func setGameCountersForPlayer(_ playerID: String, _ alternatePlayerID: String?) {
  // Someone logged in on Game Center; make sure we have the right counters for them.
  userDefaults.currentPlayerID.value = playerID
  let alternateID = alternatePlayerID ?? "<none>"
  userDefaults.currentAlternatePlayerID.value = alternateID
  logging("Player is now \(playerID) (alternate \(alternateID))")
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
