//
//  GameConfig.swift
//  Asteroids
//
//  Created by David Long on 7/31/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class WaveConfig: Decodable {
  let waveNumber: Int
  var meanUFOTime: Double? = nil
  var ufoChances: [Double]? = nil
  var maxUFOs: Int? = nil
  var ufoDodging: CGFloat? = nil
  var ufoShotAnticipation: CGFloat? = nil
  var ufoAccuracy: [CGFloat]? = nil
  var ufoShotWrapping: Bool? = nil
  var ufoMeanShotTime: [Double]? = nil
  var ufoShotSpeed: [CGFloat]? = nil
  var ufoMaxSpeed: [CGFloat]? = nil
  var asteroidSpeedBoost: CGFloat? = nil
  var kamikazeAcceleration: CGFloat? = nil

  required init(waveNumber: Int) {
    self.waveNumber = waveNumber
  }
}

struct GameConfig: Decodable {
  let initialLives: Int
  let extraLifeScore: Int
  let playerSpeedDamping: CGFloat
  let playerMaxSpeed: CGFloat
  let playerMaxThrust: CGFloat
  let playerMaxRotationRate: CGFloat
  let playerShotSpeed: CGFloat
  let playerMaxShots: Int
  let safeTime: CGFloat
  let hyperspaceCooldown: Double
  let asteroidMinSpeed: CGFloat
  let asteroidMaxSpeed: CGFloat
  let numAsteroidCoeffs: [Double]
  let waveConfigs: [WaveConfig]

  var currentWaveNumber: Int?
  var configCache: WaveConfig?

  func waveNumber() -> Int {
    guard let result = currentWaveNumber else { fatalError("You didn't set the current wave number") }
    return result
  }

  mutating func nextWave() {
    let current = waveNumber()
    currentWaveNumber = current + 1
  }

  mutating func value<T>(for path: WritableKeyPath<WaveConfig, T?>) -> T {
    let waveNumber = self.waveNumber()
    guard var cache = configCache, cache.waveNumber == waveNumber else {
      configCache = WaveConfig(waveNumber: waveNumber)
      return value(for: path)
    }
    if let cached = cache[keyPath: path] {
      return cached
    }
    guard let config = waveConfigs.last(where: { $0.waveNumber <= waveNumber && $0[keyPath: path] != nil }) else {
      fatalError("Missing game configuration info")
    }
    let result = config[keyPath: path]!
    cache[keyPath: path] = result
    return result
  }

  func numAsteroids() -> Int {
    let waveNumber = self.waveNumber()
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
