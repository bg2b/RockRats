//
//  Explosions.swift
//  Asteroids
//
//  Created by David Long on 7/28/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import os.log

// I have a texture that is the full thing that's supposed to explode, like a
// spaceship or whatever.  I'll cut it up into smaller rectangles.  Each part will
// become a separate sprite with its own physics.  I place the parts in an
// arrangement so that together they initially look like the object that's exploding.
// Add in some random velocity dispersion plus the exploding object's velocity so
// that they fly apart realistically.  The physics bodies are a separate class so I
// can have them just collide among themselves, though I currently have them set to
// bounce off asteroids and ships too.

/// Create the rectangles for an explosion
///
/// Call with the initial rectangle `CGRect(origin: .zero, size: texture.size())`.
/// The rectangle is split recursively in a somewhat random manner, though the pieces
/// are constrained in aspect ratio and the final sizes won't vary too much.
///
/// The final array contains disjoint rectangles whose union is the initial
/// rectangle.
///
/// - Parameters:
///   - rect: The piece of the texture that's being cut up
///   - wantedSize: Approximately how small to make the pieces
///   - pieces: The array of pieces being constructed (`inout`)
func makeExplosionGrid(rect: CGRect, wantedSize: CGFloat, pieces: inout [CGRect]) {
  let thisPieceLimit = max(CGFloat.random(in: 0.75 ... 1) * wantedSize, 4)
  if rect.width < thisPieceLimit && rect.height < thisPieceLimit {
    pieces.append(rect)
    return
  }
  var cutIsVertical = Bool.random()
  if rect.width > 2 * rect.height || rect.height < thisPieceLimit {
    cutIsVertical = true
  } else if rect.height > 2 * rect.width || rect.width < thisPieceLimit {
    cutIsVertical = false
  }
  let splitPos = CGFloat.random(in: 0.33 ... 0.67)
  var halves: (CGRect, CGRect)
  if cutIsVertical {
    halves = rect.divided(atDistance: rect.width * splitPos, from: .minXEdge)
  } else {
    halves = rect.divided(atDistance: rect.height * splitPos, from: .minYEdge)
  }
  makeExplosionGrid(rect: halves.0, wantedSize: wantedSize, pieces: &pieces)
  makeExplosionGrid(rect: halves.1, wantedSize: wantedSize, pieces: &pieces)
}

/// An explosion
///
/// This is basically an array of tiny sprite nodes along with displacements telling
/// how to arrange them so that they initially look like the original texture.
/// They're given an initial velocity to make them expand outward while still moving
/// approximately in the direction of the original sprite.
///
/// There's one wrinkle, an extra node at the end of the array that's responsible for
/// waiting until all the pieces finish fading out and removing themselves from the
/// playfield.  The extra node delays and then puts the whole explosion back in a
/// cache for later reuse.
///
/// - Bug:
/// I can lose an explosion if the player force-quits a game before the recycler
/// node's action gets a chance to run.  It won't break things since the cache will
/// make a new explosion when required, but it would be nice if the playfield cleanup
/// could recognize the recycler object and trigger its final action immediately in
/// some way, or if there was some other explosion-recycling mechanism.
struct Explosion {
  /// A list of nodes to add to the playfield at the explosion point
  let pieces: [SKNode]
  /// Displacements for the pieces around the explosion point
  let deltas: [CGVector]

  /// Create an explosion for a texture
  /// - Parameter texture: The texture that's going to blow up
  /// - Parameter cuts: Cut the texture into approimxately this many pieces in each direction
  init(texture: SKTexture, cuts: Int) {
    // Create rectangles that represent the cut-up texture
    var subRects = [CGRect]()
    let textureSize = texture.size()
    let textureWidth = textureSize.width
    let textureHeight = textureSize.height
    let cutSize = min(textureWidth, textureHeight) / CGFloat(cuts)
    makeExplosionGrid(rect: CGRect(origin: .zero, size: textureSize), wantedSize: cutSize, pieces: &subRects)
    // Build sprite nodes for all the pieces
    var pieces = [SKNode]()
    var deltas = [CGVector]()
    // Be sure to use textureRect because the texture is probably in an atlas
    let rect = texture.textureRect()
    let sizeScale = rect.size / textureSize
    for subRect in subRects {
      // Create the sub-texture for this piece
      let subRectOffset = subRect.origin - .zero
      let pieceOrigin = rect.origin + subRectOffset.scale(by: sizeScale)
      let pieceSize = subRect.size * sizeScale
      let pieceTexture = SKTexture(rect: CGRect(origin: pieceOrigin, size: pieceSize), in: texture)
      // Make a sprite
      let piece = SKSpriteNode(texture: pieceTexture)
      piece.name = "fragment"
      // Circular physics bodies are both faster and they help push the parts away
      // from each other
      let body = SKPhysicsBody(circleOfRadius: pieceTexture.size().diagonal() / 2)
      body.mass = 0
      body.categoryBitMask = ObjectCategories.fragment.rawValue
      body.contactTestBitMask = 0
      body.collisionBitMask = setOf([.fragment, .asteroid, .player, .ufo])
      body.fieldBitMask = 0
      body.linearDamping = 0
      body.angularDamping = 0
      body.restitution = 0.9
      piece.physicsBody = body
      // delta should be computed to put the subtexture at the same position it was in
      // the original sprite.  The sprite's texture is centered at 0.5 * texture.size().
      // So a subRect at (0,0) should be offset by -0.5 * texture.size(), and then to
      // center that subRect, we have to add back 0.5 * subRect.size.
      let delta = subRectOffset + CGVector(dxy: subRect.size - textureSize).scale(by: 0.5)
      pieces.append(piece)
      deltas.append(delta)
    }
    // The last "piece" in an explosion is special.  It doesn't draw, but is just
    // responsible for running an action that will recycle the explosion.
    let recycler = SKNode()
    recycler.name = "recycler"
    pieces.append(recycler)
    self.pieces = pieces
    self.deltas = deltas
  }
}

/// A cache of explosions
///
/// When something blows up, (an instance of) this class is responsible for either
/// making a new `Explosion` or recycling one that was created earlier.
class ExplosionCache {
  /// A key for the cache
  struct ExplosionCacheKey: Hashable {
    let texture: SKTexture
    let cuts: Int
  }
  /// A dictionary mapping textures and number of cuts to explosions
  var explosions = [ExplosionCacheKey: [Explosion]]()
  /// The number of explosions created
  var created = 0
  /// The number of explosions that are waiting for reuse
  var recycled = 0

  /// Get an explosion for a texture
  /// - Parameter texture: The texture that's going to blow up
  /// - Parameter cuts: An approximate number of pieces to cut the texture into in each direction
  /// - Returns: An explosion for the texture
  func findOrMakeExplosion(texture: SKTexture, cuts: Int) -> Explosion {
    let key = ExplosionCacheKey(texture: texture, cuts: cuts)
    if explosions[key] == nil {
      explosions[key] = []
    }
    if explosions[key]!.isEmpty {
      // There's no available explosion (either none have been made, or they're all
      // in use), so make a new one
      created += 1
      return Explosion(texture: texture, cuts: cuts)
    }
    // Grab an existing explosion from the cache
    recycled -= 1
    return explosions[key]!.popLast()!
  }

  /// Put an explosion back in the cache
  /// - Parameters:
  ///   - explosion: The explosion that has finished
  ///   - texture: The texture that it corresponds to
  ///   - cuts: The number of pieces that were used when cutting
  func doneWithExplosion(_ explosion: Explosion, texture: SKTexture, cuts: Int) {
    recycled += 1
    explosions[ExplosionCacheKey(texture: texture, cuts: cuts)]!.append(explosion)
  }

  /// Create explosions for the common stuff that will blow up
  ///
  /// This makes more copies of some things than are typically needed, and it's
  /// possible for more to be needed in some circumstances, but explosions get
  /// created dynamically if required so whatevs.
  func preload() {
    for cuts in 5 ... 6 {
      for imageName in ["ufo_green", "ufo_blue", "ufo_red", "retroship", "ship_blue"] {
        let texture = Globals.textureCache.findTexture(imageNamed: imageName)
        let explosions = (0 ..< 2).map { _ in self.findOrMakeExplosion(texture: texture, cuts: cuts) }
        explosions.forEach { doneWithExplosion($0, texture: texture, cuts: cuts) }
      }
    }
  }

  /// Print some stats for debugging
  func stats() {
    os_log("Created %d explosions, %d have been recycled", log: .app, type: .debug, created, recycled)
  }
}

extension Globals {
  /// The cache of all explosions
  static var explosionCache = ExplosionCache()
}

/// Make a sprite explode
/// - Parameters:
///   - texture: The sprite's texture
///   - angle: The zRotation of the sprite
///   - velocity: The sprite's velocity
///   - position: The sprite's position
///   - duration: How long the explosion should last
///   - cuts: Cut the sprite in each direction into about this many pieces
/// - Returns: A list of nodes to add to the playfield
func makeExplosion(texture: SKTexture, angle: CGFloat, velocity: CGVector, at position: CGPoint, duration: Double, cuts: Int = 6) -> [SKNode] {
  let explosion = Globals.explosionCache.findOrMakeExplosion(texture: texture, cuts: cuts)
  let waitAndRemove = SKAction.sequence([.wait(forDuration: 0.75 * duration),
                                         .fadeOut(withDuration: 0.25 * duration),
                                         .removeFromParent()])
  for (piece, delta) in zip(explosion.pieces, explosion.deltas) {
    // If this explosion is recycled, then the pieces will have alpha == 0 due to the
    // fadeOut in the action above, so I have to reset that.  Also, if it's due to a
    // player ship exploding then the slow-motion effect that I use may have altered
    // the action speed of fragments, so be sure to reset that too.
    piece.alpha = 1
    piece.speed = .random(in: 1 ... 2)
    // Arrange the pieces so that they look like the sprite's texture, with the right
    // position and orientation
    let rotDelta = delta.rotate(by: angle)
    piece.position = position + rotDelta
    piece.zRotation = angle
    // Give the pieces velocities that match the original sprite's velocity, and also
    // add in a radial component to make them fly apart.  The random variations in
    // the velocity vector are to make the pieces bump into each other a lot as they
    // scatter.
    let body = piece.requiredPhysicsBody()
    body.velocity = velocity + CGVector(angle: rotDelta.angle() + .random(in: -1 ... 1)).scale(by: .random(in: 10 ... 100))
    body.angularVelocity = .random(in: -2 * .pi ... 2 * .pi)
    piece.run(waitAndRemove)
  }
  guard let recycler = explosion.pieces.last, recycler.name == "recycler" else { fatalError("Recycler node for explosion is missing") }
  // The last node (not part of the zip above and not drawn) is responsible for
  // waiting a bit of extra time and then recycling the explosion.
  recycler.run(.sequence([.wait(forDuration: duration + 0.5),
                          .run { Globals.explosionCache.doneWithExplosion(explosion, texture: texture, cuts: cuts)  },
                          .removeFromParent()]))
  return explosion.pieces
}
