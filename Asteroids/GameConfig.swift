//
//  GameConfig.swift
//  Asteroids
//
//  Created by David Long on 7/31/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// Information about game values that might change from wave to wave
class WaveConfig: Decodable {
  /// The wave this applies to
  let waveNumber: Int
  /// Base (maximum) average seconds between UFOs
  var meanUFOTime: Double? = nil
  /// Probabilities of getting UFOs of different types
  var ufoChances: [Double]? = nil
  /// Maximum number of simultaneous UFOs
  var maxUFOs: Int? = nil
  /// Multiplier for forces on UFOs (something like agility)
  var ufoDodging: CGFloat? = nil
  /// Multiplier indicating how well UFOs can dodge shots
  var ufoShotAnticipation: CGFloat? = nil
  /// How accurately UFOs shoot
  var ufoAccuracy: [CGFloat]? = nil
  /// `true` if UFOs consider playfield wrapping when shooting
  var ufoShotWrapping: Bool? = nil
  /// Average time between UFO shots
  var ufoMeanShotTime: [Double]? = nil
  /// The shot speed of the different UFOs
  var ufoShotSpeed: [CGFloat]? = nil
  /// Maximum speed of UFOs
  var ufoMaxSpeed: [CGFloat]? = nil
  /// A factor that multiplies asteroid speed upon splitting
  var asteroidSpeedBoost: CGFloat? = nil
  /// Controls blue UFO acceleration
  var kamikazeAcceleration: CGFloat? = nil

  /// Make a configuration for a given wave
  /// - Parameter waveNumber: The wave
  required init(waveNumber: Int) {
    self.waveNumber = waveNumber
  }
}

/// Values that control all the different aspect of game play
///
/// Some are fixed, others vary from wave to wave
struct GameConfig: Decodable {
  /// Number of ships the player has at the start of the game
  let initialLives: Int
  /// The number of points needed for an extra ship
  let extraLifeScore: Int
  /// How fast the player slows down if they stop thrusting
  let playerSpeedDamping: CGFloat
  /// The player's maximum speed
  let playerMaxSpeed: CGFloat
  /// The player's maximum thrust
  let playerMaxThrust: CGFloat
  /// How fast the player's ship can rotate
  let playerMaxRotationRate: CGFloat
  /// How fast the player's shots travel
  let playerShotSpeed: CGFloat
  /// The maximum number of shots that the player can have in-flight at once
  let playerMaxShots: Int
  /// The number of seconds that the player should be safe from asteroids when they
  /// spawn
  let safeTime: CGFloat
  /// Miminum speed of asteroids
  let asteroidMinSpeed: CGFloat
  /// Maximum speed of asteroids
  let asteroidMaxSpeed: CGFloat
  /// Terms of a polynomial indicating how many asteroids there are
  ///
  /// Let `w` be the wave number.  Number of asteroids is
  /// `floor(p[0] + p[1]*w + p[2]*w*w + ...)`
  let numAsteroidCoeffs: [Double]
  /// An array of wave-dependent configuration values
  ///
  /// Not all configuration values have to be set all waves.  If a value isn't set
  /// for some wave, then I search over the waves to find the highest wave number
  /// which did set a value.  The first wave has to set a value for everything.  (Or
  /// at least everything that's used; some non-game scenes that use configuration
  /// info may not require all values.)
  let waveConfigs: [WaveConfig]

  /// The current wave
  var currentWaveNumber: Int?
  /// A cache of configuration values for the current wave, so that I don't have to
  /// search so much
  var configCache: WaveConfig?

  /// The current wave number, which better have been set when this is called
  func waveNumber() -> Int {
    guard let result = currentWaveNumber else { fatalError("You didn't set the current wave number") }
    return result
  }

  /// Increment the wave number
  mutating func nextWave() {
    let current = waveNumber()
    currentWaveNumber = current + 1
  }

  /// Find a wave-dependent configuration value
  ///
  /// This caches results for faster lookup
  ///
  /// - Parameter path: The key path for the configuration value
  mutating func value<T>(for path: WritableKeyPath<WaveConfig, T?>) -> T {
    let waveNumber = self.waveNumber()
    guard var cache = configCache, cache.waveNumber == waveNumber else {
      // If the cache isn't initialized or if the wave number doesn't match the
      // current wave, then make a new cache and try again
      configCache = WaveConfig(waveNumber: waveNumber)
      return value(for: path)
    }
    if let cached = cache[keyPath: path] {
      // The value is already in the cache, just return it
      return cached
    }
    // Find the config with the highest wave number that's less than the current wave
    // number where the config sets the value, complain if none
    guard let config = waveConfigs.last(where: { $0.waveNumber <= waveNumber && $0[keyPath: path] != nil }) else {
      fatalError("Missing game configuration info")
    }
    // Get value from that config and cache the result
    let result = config[keyPath: path]!
    cache[keyPath: path] = result
    return result
  }

  /// Return the number of asteroids to be used for the current wave
  func numAsteroids() -> Int {
    let waveNumber = self.waveNumber()
    var polynomial = 0.0
    for (i, coeff) in numAsteroidCoeffs.enumerated() {
      polynomial += coeff * pow(Double(waveNumber), Double(i))
    }
    return Int(floor(polynomial))
  }
}

/// Load game configuration values from a JSON file in the bundle
/// - Parameter forMode: A string, loads `"config" + forMode + ".json"`
/// - Returns: The loaded game configuration
func loadGameConfig(forMode: String) -> GameConfig {
  let configName = "config\(forMode)"
  let decoder = JSONDecoder()
  guard let path = Bundle.main.url(forResource: configName, withExtension: "json") else { fatalError("Can't find \(configName) JSON") }
  guard let data = try? Data(contentsOf: path) else { fatalError("Can't load \(configName) JSON") }
  guard let result = try? decoder.decode(GameConfig.self, from: data) else { fatalError("Can't decode \(configName) JSON") }
  return result
}

extension Globals {
  /// The game configuration values for the current scene
  static var gameConfig = loadGameConfig(forMode: "normal")
}
