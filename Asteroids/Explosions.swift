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
// separate class so they mostly just collide among themselves, though we do let them
// bounce off asteroids too.

let explosionSplits = 8

func makeExplosion(texture: SKTexture, angle: CGFloat, velocity: CGVector, at position: CGPoint, duration: Double) -> [SKNode] {
  let d = 1 / CGFloat(explosionSplits)
  let range = -explosionSplits / 2 ..< explosionSplits / 2
  let xys = range.flatMap { x in range.map { y in CGVector(dx: x, dy: y).scale(by: d) } }
  var pieces = [SKSpriteNode]()
  // We have to use textureRect!  Assuming (0,0) - (1,1) for the texture coordinates
  // will give "interesting" results if you have a texture that's part of an atlas...
  let rect = texture.textureRect()
  let dwh = rect.size.scale(by: d)
  let physicsSize2 = texture.size().scale(by: 0.5 * d)
  let waitAndRemove = SKAction.sequence([
    SKAction.wait(forDuration: 0.75 * duration),
    SKAction.fadeOut(withDuration: 0.25 * duration),
    SKAction.removeFromParent()])
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
    piece.physicsBody = body
    pieces.append(piece)
    let delta = (xy.scale(by: texture.size()) + CGVector(dx: physicsSize2.width, dy: physicsSize2.height)).rotate(by: angle)
    piece.position = position + delta
    piece.zRotation = angle
    body.velocity = velocity + CGVector(angle: delta.angle() + .random(in: -1...1)).scale(by: .random(in: 10...100))
    body.angularVelocity = .random(in: -2 * .pi ... 2 * .pi)
    piece.run(waitAndRemove)
  }
  return pieces
}
