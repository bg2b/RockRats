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
  var forwardFlames = [SKSpriteNode]()
  var reverseFlames = [[SKSpriteNode]]()
  var lasersRemaining = 3

  func buildFlames(at exhaustPos: CGPoint, scale: CGFloat = 1, direction: CGFloat = 0) -> [SKSpriteNode] {
    var fire = (1...3).compactMap { Globals.textureCache.findTexture(imageNamed: "fire\($0)") }
    fire.append(fire[1])
    let fireSize = fire[0].size()
    var fireAnimation = SKAction.animate(with: fire, timePerFrame: 0.1, resize: false, restore: true)
    fireAnimation = SKAction.repeatForever(fireAnimation)
    var flames = [SKSpriteNode]()
    for stretch in [0.5, 1.0, 1.5, 2.0] {
      let sprite = SKSpriteNode(texture: fire[0], size: fireSize)
      sprite.name = "shipExhaust"
      sprite.anchorPoint = CGPoint(x: 1.0, y: 0.5)
      sprite.run(fireAnimation)
      sprite.scale(to: CGSize(width: scale * CGFloat(stretch) * fireSize.width, height: scale * fireSize.height))
      sprite.zRotation = direction
      sprite.position = exhaustPos
      flames.append(sprite)
      addChild(sprite)
    }
    return flames
  }

  required init(color: String, joystick: Joystick) {
    self.joystick = joystick
    self.shipTexture = Globals.textureCache.findTexture(imageNamed: "ship_\(color)")
    super.init()
    self.name = "ship"
    let ship = SKSpriteNode(texture: shipTexture)
    ship.name = "shipImage"
    addChild(ship)
    forwardFlames = buildFlames(at: CGPoint(x: -shipTexture.size().width / 2, y: 0.0))
    for side in [-1, 1] {
      reverseFlames.append(buildFlames(at: CGPoint(x: 0, y: CGFloat(side) * shipTexture.size().height / 2.1),
                                       scale: 0.5, direction: .pi))
    }
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
    forwardFlames.forEach { $0.isHidden = true }
    reverseFlames[0].forEach { $0.isHidden = true }
    reverseFlames[1].forEach { $0.isHidden = true }
  }

  func flamesOn(_ flames: [SKSpriteNode], amount: CGFloat) {
    let flameIndex = Int(0.99 * amount * CGFloat(flames.count))
    flames[flameIndex].isHidden = false
  }

  func forwardFlamesOn(_ amount: CGFloat) {
    flamesOn(forwardFlames, amount: amount)
  }

  func reverseFlamesOn(_ amount: CGFloat) {
    flamesOn(reverseFlames[0], amount: amount)
    flamesOn(reverseFlames[1], amount: amount)
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
    guard stick != .zero else { return }
    var thrustAmount = CGFloat(0)
    var thrustForce = CGFloat(0)
    let shipMaxRotationRate = CGFloat.pi
    let shipMaxThrust = CGFloat(4)
    if Globals.directControls {
      while zRotation > .pi {
        zRotation -= 2 * .pi
      }
      while zRotation < -.pi {
        zRotation += 2 * .pi
      }
      var angle = stick.angle() + joystick.zRotation
      while abs(angle + 2 * .pi - zRotation) < abs(angle - zRotation) {
        angle += 2 * .pi
      }
      while abs(angle - 2 * .pi - zRotation) < abs(angle - zRotation) {
        angle -= 2 * .pi
      }
      let delta = angle - zRotation
      if abs(delta) < shipMaxRotationRate / 50 {
        // Once we get close, just snap to the desired angle to avoid stuttering
        zRotation = angle
      } else {
        // Set an absolute angular speed
        body.angularVelocity = copysign(shipMaxRotationRate, delta)
      }
      thrustAmount = stick.norm2()
      let thrustCutoff = CGFloat.pi / 2
      if abs(delta) > thrustCutoff {
        // Pointing too far away from the desired direction, so don't thrust.
        thrustAmount = 0
      } else if abs(delta) > thrustCutoff / 2 {
        // We scale down the thrust by a factor which is 0 at thrustCutoff and 1 and
        // thrustCutoff / 2.
        thrustAmount *= 2 - abs(delta) / (thrustCutoff / 2)
      }
      thrustForce = thrustAmount
    } else {
      let angle = stick.angle()
      let halfSectorSize = (120 * CGFloat.pi / 180) / 2
      if abs(angle) >= .pi - halfSectorSize {
        // Joystick is pointing backwards, apply reverse thrusters
        thrustAmount = min(-stick.dx, 0.7) / 0.7
        thrustForce = -0.5 * thrustAmount
      } else if abs(angle) <= halfSectorSize {
        // Pointing forwards, thrusters active
        thrustAmount = min(stick.dx, 0.7) / 0.7
        thrustForce = thrustAmount
      }
      if abs(abs(angle) - .pi / 2) <= halfSectorSize {
        // Left or right rotation, set an absolute angular speed.  When thrusting backwards,
        // it seems a bit more natural to reverse the direction of rotation.
        body.angularVelocity = copysign(.pi * min(abs(stick.dy), shipMaxRotationRate), angle)
        if thrustForce < 0 {
          body.angularVelocity = -body.angularVelocity
        }
      }
    }
    thrustForce *= shipMaxThrust
    let maxSpeed = CGFloat(350)
    let currentSpeed = body.velocity.norm2()
    if currentSpeed > 0.5 * maxSpeed {
      thrustForce *= (maxSpeed - currentSpeed) / (0.5 * maxSpeed)
    }
    body.applyForce(CGVector(angle: zRotation).scale(by: thrustForce))
    if thrustForce > 0 {
      forwardFlamesOn(thrustAmount)
    } else {
      reverseFlamesOn(thrustAmount)
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
