//
//  GameConfig.swift
//  Asteroids
//
//  Created by David Long on 7/31/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

struct WaveConfig: Decodable {
  let waveNumber: Int
  let meanUFOTime: Double?
  let smallUFOChance: Double?
  let maxUFOs: Int?
  let ufoAccuracy: [CGFloat]?
  let ufoMaxShots: Int?
  let ufoShotSpeed: [CGFloat]?
  let ufoMaxSpeed: [CGFloat]?
  let asteroidSpeedBoost: CGFloat?
}

struct GameConfig: Decodable {
  let initialLives: Int
  let extraLifeScore: Int
  let playerSpeedDamping: [CGFloat]
  let playerMaxSpeed: [CGFloat]
  let playerMaxThrust: [CGFloat]
  let playerMaxRotationRate: [CGFloat]
  let playerShotSpeed: CGFloat
  let playerMaxShots: Int
  let safeTime: CGFloat
  let hyperspaceCooldown: Double
  let asteroidMinSpeed: CGFloat
  let asteroidMaxSpeed: CGFloat
  let numAsteroidCoeffs: [Double]
  let waveConfigs: [WaveConfig]

  var waveNumber = 0

  func value<T>(for path: KeyPath<WaveConfig, T?>) -> T {
    guard let config = waveConfigs.last(where: { $0.waveNumber <= waveNumber && $0[keyPath: path] != nil }) else {
      fatalError("Missing game configuration info")
    }
    return config[keyPath: path]!
  }

  func numAsteroids() -> Int {
    var polynomial = 0.0
    for (i, coeff) in numAsteroidCoeffs.enumerated() {
      polynomial += coeff * pow(Double(waveNumber), Double(i))
    }
    return Int(floor(polynomial))
  }
}

func loadGameConfig(forMode: String) -> GameConfig {
  let configName = "config\(forMode)"
  let decoder = JSONDecoder()
  guard let path = Bundle.main.url(forResource: configName, withExtension: "json") else { fatalError("Can't find \(configName) JSON") }
  guard let data = try? Data(contentsOf: path) else { fatalError("Can't load \(configName) JSON") }
  guard let result = try? decoder.decode(GameConfig.self, from: data) else { fatalError("Can't decode \(configName) JSON") }
  return result
}

extension Globals {
  static var gameConfig = loadGameConfig(forMode: "normal")
}
