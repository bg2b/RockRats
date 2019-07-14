//
//  Ship.swift
//  Asteroids
//
//  Created by David Long on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class Ship: SKNode {
  var flames = [SKSpriteNode]()

  func buildFlames(at exhaustPos: CGPoint) {
    var fire = (1...3).compactMap { Globals.textureCache.findTexture(imageNamed: "fire\($0)") }
    fire.append(fire[1])
    let fireSize = fire[0].size()
    var fireAnimation = SKAction.animate(with: fire, timePerFrame: 0.1, resize: false, restore: true)
    fireAnimation = SKAction.repeatForever(fireAnimation)
    for scale in [0.5, 1.0, 1.5, 2.0] {
      let sprite = SKSpriteNode(texture: fire[0], size: fireSize)
      sprite.anchorPoint = CGPoint(x: 1.0, y: 0.5)
      sprite.run(fireAnimation)
      sprite.scale(to: CGSize(width: CGFloat(scale) * fireSize.width, height: fireSize.height))
      sprite.position = exhaustPos
      sprite.alpha = 0.0
      flames.append(sprite)
      addChild(sprite)
    }
  }

  required init(color: String) {
    super.init()
    self.name = "ship"
    let shipTexture = Globals.textureCache.findTexture(imageNamed: "ship_\(color)")
    let ship = SKSpriteNode(texture: shipTexture)
    ship.name = "shipImage"
    addChild(ship)
    buildFlames(at: CGPoint(x: -shipTexture.size().width / 2, y: 0.0))
    let body = SKPhysicsBody(texture: shipTexture, size: shipTexture.size())
    body.linearDamping = 0.05
    physicsBody = body
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Ship")
  }

  func flamesOff() {
    flames.forEach { $0.alpha = 0 }
  }

  func flamesOn(_ amount: CGFloat) {
    let flameIndex = Int(0.99 * amount * CGFloat(flames.count))
    flames[flameIndex].alpha = 1
  }

  // Sets the ship to the standard coasting configuration
  func coastingConfiguration() -> SKPhysicsBody {
    guard let body = physicsBody else { fatalError("Where did Ship's physicsBody go?") }
    body.linearDamping = 0.05
    body.angularVelocity = 0
    flamesOff()
    return body
  }

  func fly(stickPosition stick: CGVector) {
    let body = coastingConfiguration()
    guard stick != CGVector.zero else { return }
    let angle = stick.angle()
    let halfSectorSize = (120 * CGFloat.pi / 180) / 2
    if abs(angle) >= .pi - halfSectorSize {
      // Joystick is pointing backwards, put on the brakes
      body.linearDamping = max(min(-stick.dx, 0.7), 0.05)
    }
    if abs(angle) <= halfSectorSize {
      // Pointing forwards, thrusters active
      let thrustAmount = min(stick.dx, 0.7) / 0.7
      let thrust = CGVector(angle: zRotation).scale(by: 2 * thrustAmount)
      body.applyForce(thrust)
      flamesOn(thrustAmount)
    }
    if abs(abs(angle) - .pi / 2) <= halfSectorSize {
      // Left or right rotation, set an absolute angular speed
      body.angularVelocity = copysign(.pi * min(abs(stick.dy), 0.7), angle)
    }
  }
}

