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

class UserData {
  var highScore = DefaultsValue<Int>(name: "highScore", defaultValue: 0)
}

extension Globals {
  static var userData = UserData()
}
