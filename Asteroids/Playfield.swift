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

  func addWithScaling(_ child: SKNode) {
    addChild(child)
    guard speed != 1, let body = child.physicsBody, body.isA(.fragment) else { return }
    // Fragments are not affected by slow-motion
    body.velocity = body.velocity.scale(by: 1 / speed)
    body.angularVelocity /= speed
    child.speed /= speed
  }

  func changeSpeed(to newSpeed: CGFloat) {
    guard let physics = scene?.physicsWorld else { return }
    for p in children {
      if let body = p.physicsBody, body.isA(.fragment) {
        // Change any existing fragments to compensate for the change in speed
        body.velocity = body.velocity.scale(by: speed / newSpeed)
        body.angularVelocity *= speed / newSpeed
        p.speed /= newSpeed
      }
    }
    // Actions for everything in the playfield get slowed by the same factor as the
    // physics.  This is needed for things like lasers that will remove themselves
    // after a given duration.  If their actions weren't slowed to match the velocity
    // scalings by physicsWorld, they'd disappear before their full travel.
    speed = newSpeed
    physics.speed = newSpeed
  }

  func wrapCoordinates() {
    guard let frame = scene?.frame else { return }
    for child in children {
      guard let body = child.physicsBody else { continue }
      if !body.isOnScreen {
        // This isn't on screen yet, so we're just waiting for it to appear before we
        // start wrapping.
        if frame.contains(child.position) {
          body.isOnScreen = true
        }
      } else {
        // We wrap only after going past the edge a little bit so that an object
        // that's moving just along the edge won't stutter back and forth.
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
}
