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
  
  override required init() {
    isBig = .random(in: 0...1) >= Globals.gameConfig.value(for: \.smallUFOChance)
    ufoTexture = Globals.textureCache.findTexture(imageNamed: isBig ? "ufo_green" : "ufo_red")
    super.init()
    name = "ufo"
    let ufo = SKSpriteNode(texture: ufoTexture)
    ufo.name = "ufoImage"
    addChild(ufo)
    let body = SKPhysicsBody(texture: ufoTexture, size: ufoTexture.size())
    body.mass = 1
    body.categoryBitMask = ObjectCategories.ufo.rawValue
    body.collisionBitMask = 0
    body.contactTestBitMask = setOf([.asteroid, .player, .playerShot])
    body.linearDamping = 0
    body.angularDamping = 0
    physicsBody = body
  }
  
  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by UFO")
  }
  
  func fly(player: Ship, addLaser: ((CGFloat, CGPoint, CGFloat) -> Void)) {
    guard parent != nil else { return }
    guard let body = physicsBody else { fatalError("UFO has lost its body. It is an UFH - unidentified flying head") }
    body.angularVelocity = .pi * 2
    let toMove = Int.random(in: 0...100) == 0
    if toMove || body.velocity.norm2() == 0 {
      let angle = CGFloat.random(in: -.pi ... .pi)
      let maxSpeed = Globals.gameConfig.value(for: \.ufoMaxSpeed)[isBig ? 0 : 1]
      body.velocity = CGVector(angle: angle).scale(by: maxSpeed)
    }
    let toShoot = Int.random(in: 0...100) == 0
    if toShoot && player.parent != nil {
      //let angle = (player.position - position).angle() + CGFloat.random(in: -0.25 * .pi ... 0.25 * .pi)
      let shotSpeed = Globals.gameConfig.value(for: \.ufoShotSpeed)[isBig ? 0 : 1]
      guard var angle = aimAt(player, shotSpeed: shotSpeed) else { return }
      angle += CGFloat.random(in: -0.25 * .pi ... 0.25 * .pi)
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
    removeFromParent()
    return makeExplosion(texture: ufoTexture, angle: zRotation, velocity: velocity, at: position, duration: 2)
  }
}
