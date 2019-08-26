//
//  Playfield.swift
//  Asteroids
//
//  Created by David Long on 8/26/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class Playfield: SKNode {
  override required init() {
    super.init()
    name = "playfield"
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Playfield")
  }

  func wrapCoordinates() {
    guard let frame = scene?.frame else { return }
    for child in children {
      if frame.contains(child.position) {
        child["wasOnScreen"] = true
      }
      guard let wasOnScreen: Bool = child["wasOnScreen"], wasOnScreen else { continue }
      // We wrap only after going past the edge a little bit so that an object that's
      // moving just along the edge won't stutter back and forth.
      let hysteresis = CGFloat(3)
      if child.position.x < frame.minX - hysteresis {
        child.position.x += frame.width
      } else if child.position.x > frame.maxX + hysteresis {
        child.position.x -= frame.width
      }
      if child.position.y < frame.minY - hysteresis {
        child.position.y += frame.height
      } else if child.position.y > frame.maxY + hysteresis {
        child.position.y -= frame.height
      }
    }
  }
}
