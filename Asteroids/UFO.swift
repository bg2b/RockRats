//
//  UFO.swift
//  Asteroids
//
//  Created by Daniel on 8/22/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

func aim(at p: CGVector, targetVelocity v: CGFloat, shotSpeed s: CGFloat) -> CGFloat? {
  let a = s * s - v * v
  let b = -2 * p.dx * v
  let c = -p.dx * p.dx - p.dy * p.dy
  let discriminant = b * b - 4 * a * c
  guard discriminant >= 0 else { return nil }
  let r = sqrt(discriminant)
  let solutionA = (-b - r) / (2 * a)
  let solutionB = (-b + r) / (2 * a)
  if solutionA >= 0 && solutionB >= 0 { return min(solutionA, solutionB) }
  if solutionA < 0 && solutionB < 0 { return nil }
  return max(solutionA, solutionB)
}

func aim(at p: CGVector, targetVelocity v: CGVector, shotSpeed s: CGFloat) -> CGFloat? {
  let theta = v.angle()
  return aim(at: p.rotate(by: -theta), targetVelocity: v.norm2(), shotSpeed: s)
}

class UFO: SKNode {
  let isBig: Bool
  let ufoTexture: SKTexture
  var currentSpeed: CGFloat = 0
  var engineSounds: SKAudioNode
  
  required init(sounds: Sounds) {
    isBig = .random(in: 0...1) >= Globals.gameConfig.value(for: \.smallUFOChance)
    ufoTexture = Globals.textureCache.findTexture(imageNamed: isBig ? "ufo_green" : "ufo_red")
    self.engineSounds = sounds.audioNodeFor(isBig ? .ufoEnginesBig : .ufoEnginesSmall)
    self.engineSounds.isPositional = true
    self.engineSounds.autoplayLooped = true
    self.engineSounds.run(SKAction.sequence([SKAction.changeVolume(to: 0.5, duration: 0), SKAction.changePlaybackRate(to: 0.5, duration: 0)]))
    sounds.addChild(self.engineSounds)
    super.init()
    name = "ufo"
    let ufo = SKSpriteNode(texture: ufoTexture)
    ufo.name = "ufoImage"
    addChild(ufo)
    let body = SKPhysicsBody(texture: ufoTexture, size: ufoTexture.size())
    body.mass = isBig ? 1 : 0.75
    body.categoryBitMask = ObjectCategories.ufo.rawValue
    body.collisionBitMask = 0
    body.contactTestBitMask = setOf([.asteroid, .player, .playerShot])
    body.linearDamping = 0
    body.angularDamping = 0
    body.restitution = 0.9
    physicsBody = body
  }
  
  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by UFO")
  }
  
  func fly(player: Ship, playfield: Playfield, addLaser: ((CGFloat, CGPoint, CGFloat) -> Void)) {
    guard parent != nil else { return }
    guard let body = physicsBody else { fatalError("UFO has lost its body. It is an UFH - unidentified flying head") }
    body.angularVelocity = .pi * 2
    guard physicsBody?.isOnScreen == true else { return }
    let toMove = Int.random(in: 0...100) == 0
    let maxSpeed = Globals.gameConfig.value(for: \.ufoMaxSpeed)[isBig ? 0 : 1]
    if body.velocity.norm2() == 0 {
      let angle = CGFloat.random(in: -.pi ... .pi)
      currentSpeed = maxSpeed
      body.velocity = CGVector(angle: angle).scale(by: maxSpeed)
    }
    if toMove {
      currentSpeed = .random(in: 0.3 * maxSpeed ... maxSpeed)
    }
    guard let bounds = scene?.frame else { return }
    let ourRadius = 0.5 * ufoTexture.size().diagonal()
    let forceScale = Globals.gameConfig.value(for: \.ufoDodging) * 1000
    let shotAnticipation = Globals.gameConfig.value(for: \.ufoShotAnticipation)
    var totalForce = CGVector.zero
    for node in playfield.children {
      // Be sure not to consider off-screen things.  That happens if the last asteroid is
      // destroyed while the UFO is flying around and a new wave spawns.
      guard let body = node.physicsBody, body.isOnScreen else { continue }
      if body.isA(.asteroid) || body.isA(.playerShot) || body.isA(.player) {
        //this needs to be done better. we need to think about how to do the different cases more fluidly rather than in one big loop with a bunch of conditionsals for the different types.
        let dx1 = node.position.x - position.x
        let dx2 = copysign(bounds.width, -dx1) + dx1
        let dx = (abs(dx1) < abs(dx2) ? dx1 : dx2)
        let dy1 = node.position.y - position.y
        let dy2 = copysign(bounds.height, -dy1) + dy1
        let dy = (abs(dy1) < abs(dy2) ? dy1 : dy2)
        // The + 5 is because of possible wrapping hysteresis
        assert(abs(dx) <= bounds.width / 2 + 5 && abs(dy) <= bounds.height / 2 + 5)
        var r = CGVector(dx: dx, dy: dy)
        if body.isA(.playerShot) {
          // Shots travel fast, so emphasize dodging to the side.  We do this by projecting out
          // some of the displacement along the direction of the shot.
          let vhat = body.velocity.scale(by: 1 / body.velocity.norm2())
          r = r - r.project(unitVector: vhat).scale(by: shotAnticipation)
        }
        var objectRadius = CGFloat(0)
        if body.isA(.asteroid) {
          objectRadius = 0.5 * (node as! SKSpriteNode).texture!.size().diagonal()
        }
        if body.isA(.player) {
          objectRadius = 0.5 * (node as! Ship).shipTexture.size().diagonal()
        }
        let d = r.norm2() - (ourRadius + objectRadius)
        // Limit the force so that we don't poke the UFO by an enormous amount
        let dmin = CGFloat(20)
        let dlim = 0.5 * (sqrt((d - dmin) * (d - dmin) + dmin) + d)
        totalForce = totalForce + r.scale(by: -forceScale / (dlim * dlim))
      }
    }
    body.applyForce(totalForce)
    if body.velocity.norm2() > currentSpeed {
      body.velocity = body.velocity.scale(by: 0.95)
    }
    else if body.velocity.norm2() < currentSpeed {
      body.velocity = body.velocity.scale(by: 1.05)
    }
    if body.velocity.norm2() > maxSpeed {
      body.velocity = body.velocity.scale(by: maxSpeed / body.velocity.norm2())
    }
    let toShoot = Int.random(in: 0...100) == 0
    if toShoot && player.parent != nil {
      let shotSpeed = Globals.gameConfig.value(for: \.ufoShotSpeed)[isBig ? 0 : 1]
      guard var angle = aimAt(player, shotSpeed: shotSpeed) else { return }
      let accuracy = Globals.gameConfig.value(for: \.ufoAccuracy)[isBig ? 0 : 1]
      angle += CGFloat.random(in: -accuracy * .pi ... accuracy * .pi)
      let shotDirection = CGVector(angle: angle)
      let shotPosition = position + shotDirection.scale(by: 0.5 * ufoTexture.size().width)
      addLaser(angle, shotPosition, shotSpeed)
    }
  }
  
  func aimAt(_ object: SKNode, shotSpeed s: CGFloat) -> CGFloat? {
    guard let body = object.physicsBody else { return nil }
    let p = object.position - position
    guard let time = aim(at: p, targetVelocity: body.velocity, shotSpeed: s) else { return nil }
    let futurePos = p + body.velocity.scale(by: time)
    return futurePos.angle()
  }
  
  func explode() -> [SKNode] {
    let velocity = physicsBody!.velocity
    engineSounds.removeFromParent()
    removeFromParent()
    return makeExplosion(texture: ufoTexture, angle: zRotation, velocity: velocity, at: position, duration: 2)
  }
}
