//
//  Ship.swift
//  Asteroids
//
//  Created by David Long on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class Ship: SKNode {
  let joystick: Joystick
  let shipTexture: SKTexture
  var flames = [SKSpriteNode]()
  var lasersRemaining = 3

  func buildFlames(at exhaustPos: CGPoint) {
    var fire = (1...3).compactMap { Globals.textureCache.findTexture(imageNamed: "fire\($0)") }
    fire.append(fire[1])
    let fireSize = fire[0].size()
    var fireAnimation = SKAction.animate(with: fire, timePerFrame: 0.1, resize: false, restore: true)
    fireAnimation = SKAction.repeatForever(fireAnimation)
    for scale in [0.5, 1.0, 1.5, 2.0] {
      let sprite = SKSpriteNode(texture: fire[0], size: fireSize)
      sprite.name = "shipExhaust"
      sprite.anchorPoint = CGPoint(x: 1.0, y: 0.5)
      sprite.run(fireAnimation)
      sprite.scale(to: CGSize(width: CGFloat(scale) * fireSize.width, height: fireSize.height))
      sprite.position = exhaustPos
      flames.append(sprite)
      addChild(sprite)
    }
  }

  required init(color: String, joystick: Joystick) {
    self.joystick = joystick
    self.shipTexture = Globals.textureCache.findTexture(imageNamed: "ship_\(color)")
    super.init()
    self.name = "ship"
    let ship = SKSpriteNode(texture: shipTexture)
    ship.name = "shipImage"
    addChild(ship)
    buildFlames(at: CGPoint(x: -shipTexture.size().width / 2, y: 0.0))
    physicsBody = SKPhysicsBody(texture: shipTexture, size: shipTexture.size())
    let body = coastingConfiguration()
    body.categoryBitMask = ObjectCategories.player.rawValue
    body.collisionBitMask = 0
    body.contactTestBitMask = setOf([.asteroid, .ufo, .ufoShot])
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Ship")
  }

  func flamesOff() {
    flames.forEach { $0.isHidden = true }
  }

  func flamesOn(_ amount: CGFloat) {
    let flameIndex = Int(0.99 * amount * CGFloat(flames.count))
    flames[flameIndex].isHidden = false
  }

  // Sets the ship to the standard coasting configuration
  func coastingConfiguration() -> SKPhysicsBody {
    guard let body = physicsBody else { fatalError("Where did Ship's physicsBody go?") }
    body.linearDamping = 0.05
    body.angularVelocity = 0
    flamesOff()
    return body
  }

  func fly() {
    guard parent != nil else { return }
    let body = coastingConfiguration()
    let stick = joystick.getDirection()
    if stick != .zero {
      while zRotation > .pi {
        zRotation -= 2 * .pi
      }
      while zRotation < -.pi {
        zRotation += 2 * .pi
      }
      var angle = stick.angle() + joystick.zRotation
      let shipRotationRate = 1.4 * CGFloat.pi
      while abs(angle + 2 * .pi - zRotation) < abs(angle - zRotation) {
        angle += 2 * .pi
      }
      while abs(angle - 2 * .pi - zRotation) < abs(angle - zRotation) {
        angle -= 2 * .pi
      }
      let delta = angle - zRotation
      if abs(delta) < shipRotationRate / 50 {
        // Once we get close, just snap to the desired angle to avoid stuttering
        zRotation = angle
      } else {
        // Set an absolute angular speed
        body.angularVelocity = copysign(shipRotationRate, delta)
      }
      let thrustAmount = stick.norm2()
      var thrustForce = 2 * thrustAmount
      let maxSpeed = CGFloat(350)
      let currentSpeed = body.velocity.norm2()
      if currentSpeed > 0.5 * maxSpeed {
        thrustForce *= (maxSpeed - currentSpeed) / (0.5 * maxSpeed)
      }
      let thrust = CGVector(angle: zRotation).scale(by: thrustForce)
      body.applyForce(thrust)
      flamesOn(thrustAmount)
    }
  }
  
  func canShoot() -> Bool {
    return parent != nil && lasersRemaining > 0
  }

  func shoot(laser shot: SKNode) {
    shot.zRotation = zRotation
    let shotDirection = CGVector(angle: zRotation)
    shot.position = position + shotDirection.scale(by: 0.5 * shipTexture.size().width)
    shot.physicsBody?.velocity = shotDirection.scale(by: 700)
    lasersRemaining -= 1
  }
  
  func laserDestroyed() {
    lasersRemaining += 1
  }

  // Reset the ship (typically because the player died)
  func reset() {
    let body = coastingConfiguration()
    body.velocity = .zero
    position = .zero
    zRotation = .pi / 2
    lasersRemaining = 3
  }

  func explode() -> SKEmitterNode {
    removeFromParent()
    return makeExplosion(texture: shipTexture, at: position)
  }
}
