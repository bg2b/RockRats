//
//  EnergyBar.swift
//  Asteroids
//
//  Created by David Long on 9/20/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class EnergyBar: SKNode {
  let maxLength: Int
  let maxLevel = 100.0
  var level = 0.0
  var bar = [SKSpriteNode]()

  required init(maxLength: Int) {
    self.maxLength = maxLength
    super.init()
    addToLevel(maxLevel)
  }

  deinit {
    clearBar()
  }
  
  var levelIndex: Int { return Int(2.999 * level / maxLevel) }

  func segment(_ type: String, at x: CGFloat) -> CGFloat {
    let sprite = Globals.spriteCache.findSprite(imageNamed: "energy\(type)\(levelIndex)")
    sprite.position = CGPoint(x: x - 0.5 * sprite.size.width, y: 0)
    bar.append(sprite)
    addChild(sprite)
    return x - sprite.size.width
  }

  func buildSprites() {
    let numSegments = Int(level / maxLevel * (Double(maxLength) + 0.99))
    var x = segment("right", at: 0)
    for _ in 0 ..< numSegments { x = segment("mid", at: x) }
    x = segment("left", at: x)
  }

  func clearBar() {
    bar.forEach { Globals.spriteCache.recycleSprite($0) }
    bar.removeAll()
  }

  func addToLevel(_ amount: Double) {
    let newLevel = max(min(level + amount, maxLevel), 0)
    guard level != newLevel else { return }
    level = newLevel
    clearBar()
    buildSprites()
  }

  func useEnergy(_ amount: Double) -> Bool {
    guard level >= amount else { return false }
    addToLevel(-amount)
    return true
  }

  func fill() { addToLevel(maxLevel) }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by EnergyBar")
  }
}
