//
//  UFO.swift
//  Asteroids
//
//  Created by Daniel on 8/22/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class UFO: SKNode {
  let isBig: Bool
  let ufoTexture: SKTexture
  
  required init(isBig: Bool) {
    self.isBig = isBig
    self.ufoTexture = Globals.textureCache.findTexture(imageNamed: isBig ? "ufo_green" : "ufo_red")
    super.init()
    self.name = "ufo"
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
  
  func fly() {
    guard parent != nil else { return }
    guard let body = physicsBody else { fatalError("UFO has lost its body. It is an UFH - unidentified flying head") }
    let toMove = Int.random(in: 0...100) == 0
    if toMove || body.velocity.norm2() == 0 {
      let angle = CGFloat.random(in: -.pi ... .pi)
      let maxSpeed = Globals.gameConfig.value(for: \WaveConfig.ufoMaxSpeed, atWave: 1)[isBig ? 0 : 1]
      body.velocity = CGVector(angle: angle).scale(by: maxSpeed)
    }
  }
  
  func shoot(laser shot: SKNode) {
    shot.zRotation = zRotation
    let shotDirection = CGVector(angle: zRotation)
    shot.position = position + shotDirection.scale(by: 0.5 * ufoTexture.size().width)
    let shotSpeed = Globals.gameConfig.value(for: \WaveConfig.ufoShotSpeed, atWave: 1)[isBig ? 0 : 1]
    shot.physicsBody?.velocity = shotDirection.scale(by: shotSpeed)
  }
  
  func explode() -> [SKNode] {
    let velocity = physicsBody!.velocity
    removeFromParent()
    return makeExplosion(texture: ufoTexture, angle: zRotation, velocity: velocity, at: position, duration: 2)
  }
}
