//
//  Playfield.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import SpriteKit

/// The game area, where all the action takes place
///
/// This holds asteroids, the player's ship, UFOs, explosions, etc.  It's also
/// rsponsible for wrapping things from one side of the screen to the other, and for
/// keeping track of the status flags (stored in the category bitmask) indicating
/// whether something has been visible on the screen and whether it has wrapped.
class Playfield: SKNode {
  /// The bounds of the play area; center is (0, 0), positive x to the right,
  /// positive y up
  var bounds: CGRect

  /// Create the playfield
  /// - Parameter bounds: The desired bounds
  required init(bounds: CGRect) {
    self.bounds = bounds
    super.init()
    name = "playfield"
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Playfield")
  }

  /// Add something to the playfield
  /// - Parameter child: The node to add
  func addWithScaling(_ child: SKNode) {
    addChild(child)
    // Things without a physics body are effects and don't need anything special
    guard let body = child.physicsBody else { return }
    // Something just being added to the playfield has not wrapped around
    body.hasWrapped = false
    // If the current simulation speed is 1 (normal) or the body is not a fragment
    // from an explosion, don't do anything special
    guard speed != 1, body.isA(.fragment) else { return }
    // A fragment is being added to the playfield, and the simulation is running in
    // slow-motion.  Fragments are not affected by slow-motion, so the velocity,
    // angular velocity, and action speed of the fragment all have to be adjusted to
    // counteract the slow down.
    body.velocity = body.velocity.scale(by: 1 / speed)
    body.angularVelocity /= speed
    child.speed /= speed
  }

  /// Change the speed of the simulation (either start a slow-motion effect or go
  /// back to normal speed)
  /// - Parameter newSpeed: The desired speed (0.5 would be a 2x slowdown)
  func changeSpeed(to newSpeed: CGFloat) {
    guard let physics = scene?.physicsWorld else { return }
    // Scan to find fragments; they have to be adjusted for the changing speed
    for p in children {
      if let body = p.physicsBody, body.isA(.fragment) {
        // Update the fragment's velocity, angular velocity, and action speed
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

  /// Is anything interesting happening in the playfield?
  /// - Parameter transient: A category bitmask (constructed using `setOf`) that
  ///   specifies things that should have disappeared in order for the playfield to
  ///   be quiescent
  func isQuiescent(transient: UInt32) -> Bool {
    for child in children {
      // Anything without a physicsBody is some sort of effect that's running, so if
      // there are any of those then the field is not quiescent
      guard let body = child.physicsBody else { return false }
      if body.isOneOf(transient) {
        // There's still something transient like a fragment or a warping out UFO, so
        // not quiescent
        return false
      }
    }
    return true
  }

  /// Recycle anything that should go in the global sprite cache
  ///
  /// This gets called when a scene in a perhaps uncertain state should be prepared
  /// for garbage collection.
  func recycle() {
    let recycleable = setOf([ObjectCategories.playerShot, .ufoShot, .asteroid])
    for child in children {
      guard let body = child.physicsBody else { continue }
      if body.isOneOf(recycleable) {
        Globals.spriteCache.recycleSprite(child as! SKSpriteNode)
      }
    }
  }

  /// Wrap the coordinates of all the objects in the playfield
  func wrapCoordinates() {
    for child in children {
      // Don't move anything that doesn't have a physics body
      guard let body = child.physicsBody else { continue }
      if !body.isOnScreen {
        // This isn't on screen yet, so wait for it to appear before possibly
        // wrapping
        if bounds.contains(child.position) {
          body.isOnScreen = true
        }
      } else {
        // Wrap only after something went past the edge a little bit.  That way an
        // object that's moving just along the edge won't stutter back and forth.
        let hysteresis = CGFloat(3)
        if child.position.x < bounds.minX - hysteresis {
          child.position.x += bounds.width
          body.hasWrapped = true
        } else if child.position.x > bounds.maxX + hysteresis {
          child.position.x -= bounds.width
          body.hasWrapped = true
        }
        if child.position.y < bounds.minY - hysteresis {
          child.position.y += bounds.height
          body.hasWrapped = true
        } else if child.position.y > bounds.maxY + hysteresis {
          child.position.y -= bounds.height
          body.hasWrapped = true
        }
      }
    }
  }
}
