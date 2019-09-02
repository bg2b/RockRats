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
    guard let physics = scene?.physicsWorld, physics.speed != 1 else { return addChild(child) }
    guard let body = child.physicsBody else { return addChild(child) }
    addChild(child)
    guard !body.isA(.fragment) else { return }
    body.velocity = body.velocity.scale(by: 1 / physics.speed)
    body.angularVelocity /= physics.speed
    child.speed /= physics.speed
  }

  func changeSpeed(to newSpeed: CGFloat) {
    guard let physics = scene?.physicsWorld else { return }
    for p in children {
      if let body = p.physicsBody, body.isA(.fragment) {
        body.velocity = body.velocity.scale(by: physics.speed / newSpeed)
        body.angularVelocity *= physics.speed / newSpeed
        p.speed /= newSpeed
      }
    }
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
