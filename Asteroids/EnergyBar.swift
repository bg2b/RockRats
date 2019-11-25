//
//  EnergyBar.swift
//  Asteroids
//
//  Created by David Long on 9/20/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// The ship's energy reserve bar
///
/// This is a linear array of sprites that indicates the percentage of energy
/// available.  The right side of the bar is zero-energy level, and the bar extends
/// left according to the amount of energy available.
class EnergyBar: SKNode {
  /// The maximum length of the bar (number of sprites)
  let maxLength: Int
  /// The maximum energy level (abstract units, 0 to 100).  100 units is `maxLength`
  let maxLevel = 100.0
  /// The current energy level
  var level = 0.0
  /// The sprites making up the bar
  var bar = [SKSpriteNode]()

  /// Create an energy reserves bar
  /// - Parameter maxLength: The maximum length of the bar (number of sprites)
  required init(maxLength: Int) {
    self.maxLength = maxLength
    super.init()
    addToLevel(maxLevel)
  }

  deinit {
    // Recycle the sprites on destruction
    clearBar()
  }

  /// An qualitative energy level, 0 = low, 1 = moderate, 2 = high, used for colors
  var levelIndex: Int { Int(2.999 * level / maxLevel) }

  /// Add a segment to the bar
  ///
  /// Build the bar by calling `segment("right")`, `segment("mid")` some number of
  /// times, and then `segment("left")`.
  ///
  /// - Parameters:
  ///   - type: The type of segment to add, `"right"`, `"mid"`, or `"left"`
  ///   - x: The x position to add the segment
  /// - Returns: The x position where the next segment should be placed
  func segment(_ type: String, at x: CGFloat) -> CGFloat {
    let sprite = Globals.spriteCache.findSprite(imageNamed: "energy\(type)\(levelIndex)")
    sprite.position = CGPoint(x: x - 0.5 * sprite.size.width, y: 0)
    bar.append(sprite)
    addChild(sprite)
    return x - sprite.size.width
  }

  /// Create and place the sprites for the bar
  func buildSprites() {
    let numSegments = Int(level / maxLevel * (Double(maxLength) + 0.99))
    var x = segment("right", at: 0)
    for _ in 0 ..< numSegments { x = segment("mid", at: x) }
    x = segment("left", at: x)
  }

  /// Clear the bar and recycle all the sprites
  func clearBar() {
    bar.forEach { Globals.spriteCache.recycleSprite($0) }
    bar.removeAll()
  }

  /// Add some amount of energy to the reserves
  ///
  /// Clamps between `0` and `maxLevel`, and rebuilds the bar after the update.
  ///
  /// - Parameter amount: The amount of energy to add
  func addToLevel(_ amount: Double) {
    let newLevel = max(min(level + amount, maxLevel), 0)
    guard level != newLevel else { return }
    level = newLevel
    clearBar()
    buildSprites()
  }

  /// Try to use some energy
  ///
  /// If there's insufficient energy then this immediately returns `false`, otherwise
  /// it uses the energy, updates the bar, and returns `true`.
  ///
  /// - Parameter amount: The amount of energy required
  /// - Returns: `true` if the energy is available, `false` if not
  func useEnergy(_ amount: Double) -> Bool {
    guard level >= amount else { return false }
    addToLevel(-amount)
    return true
  }

  /// Fill up the energy reserve completely
  func fill() { addToLevel(maxLevel) }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by EnergyBar")
  }
}
