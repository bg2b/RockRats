//
//  UserData.swift
//  Asteroids
//
//  Created by Daniel on 9/29/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class UserData: Codable {
  var highScore: Int = 0
}

func loadUserData() -> UserData {
  let configName = "userdata"
  do {
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let file = directory.appendingPathComponent("\(configName).json")
    let decoder = JSONDecoder()
    let data = try Data(contentsOf: file)
    print(data)
    let result = try decoder.decode(UserData.self, from: data)
    return result
  } catch {
    print(error)
    return UserData()
  }
}

func saveUserData() {
  let configName = "userdata"
  let decoder = JSONEncoder()
  guard let result = try? decoder.encode(Globals.userData) else { fatalError("Can't encode for \(configName) JSON") }
  print(result)
  let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
  let file = directory.appendingPathComponent("\(configName).json")
  do {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try result.write(to: file)
  } catch {
    print(error)
  }
}

extension Globals {
  static var userData = loadUserData()
}
