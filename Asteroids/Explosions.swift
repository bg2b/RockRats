//
//  Explosions.swift
//  Asteroids
//
//  Created by David Long on 7/28/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

// We have a texture that is the full thing that's supposed to explode, like a
// spaceship or whatever.  We'll cut it up into an explosionSplits * explosionSplits
// grid.  Each part will become a separate sprite with its own physics.  We place
// them in a grid arrangement so that together they initially look like the object
// that's exploding.  Add in some random velocity dispersion plus the exploding
// object's velocity so that they fly apart realistically.  The physics bodies are a
// separate class so we can have them just collide among themselves, though we
// currently have them set to bounce off asteroids and ships too.

let explosionSplits = 8

struct Explosion {
  let pieces: [SKNode]
  let deltas: [CGVector]

  init(texture: SKTexture) {
    let d = 1 / CGFloat(explosionSplits)
    let range = -explosionSplits / 2 ..< explosionSplits / 2
    let xys = range.flatMap { x in range.map { y in CGVector(dx: x, dy: y).scale(by: d) } }
    var pieces = [SKNode]()
    var deltas = [CGVector]()
    // We have to use textureRect!  Assuming (0,0) - (1,1) for the texture coordinates
    // will give "interesting" results if you have a texture that's part of an atlas...
    let rect = texture.textureRect()
    let dwh = rect.size.scale(by: d)
    let physicsSize2 = texture.size().scale(by: 0.5 * d)
    for xy in xys {
      let pieceOrigin = rect.origin + (xy + CGVector(dx: 0.5, dy: 0.5)).scale(by: rect.size)
      let pieceTexture = SKTexture(rect: CGRect(origin: pieceOrigin, size: dwh), in: texture)
      let piece = SKSpriteNode(texture: pieceTexture)
      piece.name = "fragment"
      let body = SKPhysicsBody(circleOfRadius: physicsSize2.diagonal())
      body.mass = 0
      body.categoryBitMask = ObjectCategories.fragment.rawValue
      body.contactTestBitMask = 0
      body.collisionBitMask = setOf([.fragment, .asteroid, .player, .ufo])
      body.linearDamping = 0
      body.angularDamping = 0
      body.restitution = 0.9
      piece.physicsBody = body
      let delta = (xy.scale(by: texture.size()) + CGVector(dx: physicsSize2.width, dy: physicsSize2.height))
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

class ExplosionCache {
  var explosions = [SKTexture: [Explosion]]()
  var created = 0
  var recycled = 0

  func findOrMakeExplosion(texture: SKTexture) -> Explosion {
    if explosions[texture] == nil {
      explosions[texture] = []
    }
    if explosions[texture]!.isEmpty {
      created += 1
      return Explosion(texture: texture)
    }
    recycled -= 1
    return explosions[texture]!.popLast()!
  }

  func doneWithExplosion(_ explosion: Explosion, texture: SKTexture) {
    recycled += 1
    explosions[texture]!.append(explosion)
  }

  func stats() {
    logging("ExplosionCache created \(created) explosions; \(recycled) are in the recycle bin")
  }
}

extension Globals {
  static var explosionCache = ExplosionCache()
}

func makeExplosion(texture: SKTexture, angle: CGFloat, velocity: CGVector, at position: CGPoint, duration: Double) -> [SKNode] {
  let explosion = Globals.explosionCache.findOrMakeExplosion(texture: texture)
  let waitAndRemove = SKAction.sequence([
    SKAction.wait(forDuration: 0.75 * duration),
    SKAction.fadeOut(withDuration: 0.25 * duration),
    SKAction.removeFromParent()])
  for (piece, delta) in zip(explosion.pieces, explosion.deltas) {
    let rotDelta = delta.rotate(by: angle)
    // If this explosion is recycled, then the pieces will have alpha == 0 due to the
    // fadeOut in the action above, so we have to reset that.  Also, if it's due to a
    // player ship exploding then the slow-motion effect that we use may have altered
    // the action speed of fragments, so we have to reset that to 1.
    piece.alpha = 1
    piece.speed = 1
    piece.position = position + rotDelta
    piece.zRotation = angle
    let body = piece.requiredPhysicsBody()
    body.velocity = velocity + CGVector(angle: rotDelta.angle() + .random(in: -1...1)).scale(by: .random(in: 10...100))
    body.angularVelocity = .random(in: -2 * .pi ... 2 * .pi)
    piece.run(waitAndRemove)
  }
  guard let recycler = explosion.pieces.last, recycler.name == "recycler" else { fatalError("Recycler node for explosion is missing") }
  // The last node (not part of the zip above and not drawn) is responsible for
  // waiting a bit of extra time and then recycling the explosion.
  recycler.run(SKAction.sequence([
    SKAction.wait(forDuration: duration + 0.5),
    SKAction.run {
      Globals.explosionCache.doneWithExplosion(explosion, texture: texture)
    },
    SKAction.removeFromParent()]))
  return explosion.pieces
}
