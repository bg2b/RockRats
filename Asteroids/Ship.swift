//
//  Ship.swift
//  Asteroids
//
//  Created by David Long on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import AVFoundation

enum ShipAppearance: Int {
  case modern = 0
  case retro = 1
}

class ShipAppearanceAlternative {
  let texture: SKTexture
  let sprite: SKSpriteNode
  let warpOutShader: SKShader
  let warpInShader: SKShader
  let body: SKPhysicsBody

  init(imageName: String, warpTime: Double) {
    texture = Globals.textureCache.findTexture(imageNamed: imageName)
    sprite = SKSpriteNode(texture: texture)
    sprite.name = "shipImage"
    warpOutShader = swirlShader(forTexture: texture, inward: true, warpTime: warpTime)
    warpInShader = swirlShader(forTexture: texture, inward: false, warpTime: warpTime)
    body = Globals.conformingPhysicsCache.makeBody(texture: texture)
  }
}

class Ship: SKNode {
  let getJoystickDirection: () -> CGVector
  var shipAppearances: [ShipAppearanceAlternative]
  var currentAppearance = ShipAppearance.modern
  var engineSounds: ContinuousPositionalAudio!
  var engineSoundLevel = 0
  var forwardFlames = [SKSpriteNode]()
  var reverseFlames = [[SKSpriteNode]]()
  var lasersRemaining = Globals.gameConfig.playerMaxShots
  let warpTime = 0.5

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

  required init(color: String, getJoystickDirection: @escaping () -> CGVector, audio: SceneAudio) {
    self.getJoystickDirection = getJoystickDirection
    shipAppearances = []
    shipAppearances.append(ShipAppearanceAlternative(imageName: "ship_\(color)", warpTime: warpTime))
    shipAppearances.append(ShipAppearanceAlternative(imageName: "retroship", warpTime: warpTime))
    super.init()
    engineSounds = audio.continuousAudio(.playerEngines, at: self)
    engineSounds.playerNode.volume = 0
    engineSounds.playerNode.play()
    self.name = "ship"
    addChild(shipAppearance.sprite)
    forwardFlames = buildFlames(at: CGPoint(x: -shipTexture.size().width / 2, y: 0.0))
    for side in [-1, 1] {
      reverseFlames.append(buildFlames(at: CGPoint(x: 0, y: CGFloat(side) * shipTexture.size().height / 2.1),
                                       scale: 0.5, direction: .pi))
    }
    for appearance in shipAppearances {
      appearance.body.mass = 1
      appearance.body.categoryBitMask = ObjectCategories.player.rawValue
      appearance.body.collisionBitMask = 0
      appearance.body.contactTestBitMask = setOf([.asteroid, .ufo, .ufoShot])
      appearance.body.linearDamping = Globals.gameConfig.playerSpeedDamping
      appearance.body.restitution = 0.9
    }
    physicsBody = shipAppearance.body
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
    setEngineLevel(amount)
  }

  func reverseFlamesOn(_ amount: CGFloat) {
    flamesOn(reverseFlames[0], amount: amount)
    flamesOn(reverseFlames[1], amount: amount)
    setEngineLevel(0.5 * amount)
  }

  func setEngineLevel(_ amount: CGFloat) {
    let soundLevel = Int((amount + 0.24) * 4)
    if soundLevel != engineSoundLevel {
      // The first 0.5 * is to reduce the overall volume.  The second is to scale
      // soundLevel to 0...1
      engineSounds.playerNode.volume = 0.5 * 0.25 * Float(soundLevel)
      engineSoundLevel = soundLevel
    }
  }

  // Sets the ship to the standard coasting configuration
  func coastingConfiguration() -> SKPhysicsBody {
    let body = requiredPhysicsBody()
    body.angularVelocity = 0
    flamesOff()
    return body
  }

  func fly() {
    guard parent != nil else {
      setEngineLevel(0)
      return
    }
    let body = coastingConfiguration()
    let stick = getJoystickDirection()
    guard stick != .zero else {
      setEngineLevel(0)
      return
    }
    var thrustAmount = CGFloat(0)
    var thrustForce = CGFloat(0)
    let maxOmega = Globals.gameConfig.playerMaxRotationRate
    let maxThrust = Globals.gameConfig.playerMaxThrust
    let angle = stick.angle()
    let halfSectorSize = (120 * CGFloat.pi / 180) / 2
    if abs(angle) >= .pi - 0.5 * halfSectorSize {
      // Joystick is pointing backwards, apply reverse thrusters.  Because reverse
      // thrust tends to be confusing while turning, we reduce the region where
      // reverse thrust is active.
      thrustAmount = min(-stick.dx, 0.7) / 0.7
      thrustForce = -0.5 * thrustAmount
    } else if abs(angle) <= halfSectorSize {
      // Pointing forwards, thrusters active
      thrustAmount = min(stick.dx, 0.7) / 0.7
      thrustForce = thrustAmount
    }
    if abs(abs(angle) - .pi / 2) <= halfSectorSize {
      // Left or right rotation, set an absolute angular speed.  I thought
      // initially that when thrusting backwards it seemed a bit more natural to
      // reverse the direction of rotation, but now I think that's just more
      // confusing.
      body.angularVelocity = copysign(maxOmega * min(abs(stick.dy), 0.7) / 0.7, angle)
    }
    thrustForce *= maxThrust
    let maxSpeed = Globals.gameConfig.playerMaxSpeed
    var currentSpeed = body.velocity.norm2()
    if currentSpeed > maxSpeed {
      body.velocity = body.velocity.scale(by: maxSpeed / currentSpeed)
      currentSpeed = maxSpeed
    }
    var appliedForce = CGVector(angle: zRotation).scale(by: thrustForce)
    if currentSpeed > 0.5 * maxSpeed {
      let vhat = body.velocity.scale(by: 1 / currentSpeed)
      var direct = appliedForce.dotProd(vhat)
      let tangentialForce = appliedForce - vhat.scale(by: direct)
      if direct > 0 {
        direct *= (maxSpeed - currentSpeed) / (0.5 * maxSpeed)
      }
      appliedForce = tangentialForce + vhat.scale(by: direct)
    }
    body.applyForce(appliedForce)
    if thrustForce > 0 {
      forwardFlamesOn(thrustAmount)
    } else if thrustForce < 0 {
      reverseFlamesOn(thrustAmount)
    }
  }
  
  func canShoot() -> Bool {
    return parent != nil && lasersRemaining > 0
  }

  func canJump() -> Bool {
    return parent != nil
  }

  var shipAppearance: ShipAppearanceAlternative { return shipAppearances[currentAppearance.rawValue] }

  var shipTexture: SKTexture { return shipAppearance.texture }

  func warpEffect(direction: KeyPath<ShipAppearanceAlternative, SKShader>) -> SKNode {
    let effect = SKSpriteNode(texture: shipTexture)
    effect.name = "shipWarpEffect"
    effect.position = position
    effect.zRotation = zRotation
    effect.shader = shipAppearance[keyPath: direction]
    setStartTimeAttrib(effect, view: scene?.view)
    return effect
  }

  func warpOut() -> [SKNode] {
    let effect = warpEffect(direction: \.warpOutShader)
    effect.run(SKAction.sequence([SKAction.wait(forDuration: warpTime), SKAction.removeFromParent()]))
    let star = starBlink(at: position, throughAngle: .pi, duration: 2 * warpTime)
    setEngineLevel(0)
    removeFromParent()
    return [effect, star]
  }

  func warpIn(to pos: CGPoint, atAngle angle: CGFloat, addTo playfield: Playfield) {
    position = pos
    zRotation = angle
    let body = coastingConfiguration()
    body.velocity = .zero
    let effect = warpEffect(direction: \.warpInShader)
    playfield.addWithScaling(effect)
    effect.run(SKAction.sequence([SKAction.wait(forDuration: warpTime), SKAction.removeFromParent()])) {
      playfield.addWithScaling(self)
    }
  }

  func setAppearance(to newAppearance: ShipAppearance) {
    if currentAppearance != newAppearance {
      shipAppearance.sprite.removeFromParent()
      currentAppearance = newAppearance
      addChild(shipAppearance.sprite)
      physicsBody = shipAppearance.body
      for revFlameIndex in [0, 1] {
        let side = 2 * revFlameIndex - 1
        let revFlamePos = CGPoint(x: 0, y: CGFloat(side) * shipTexture.size().height / 2.1)
        reverseFlames[revFlameIndex].forEach {
          $0.position = revFlamePos
          if currentAppearance == .modern {
            $0.zRotation = .pi
          } else {
            $0.zRotation = .pi * (1 + 0.25 * CGFloat(side))
          }
        }
      }
    }
  }

  func shoot(laser shot: SKNode) {
    shot.zRotation = zRotation
    let shotDirection = CGVector(angle: zRotation)
    shot.position = position + shotDirection.scale(by: 0.5 * shipTexture.size().width)
    shot.physicsBody?.velocity = shotDirection.scale(by: Globals.gameConfig.playerShotSpeed)
    lasersRemaining -= 1
  }
  
  func laserDestroyed() {
    assert(lasersRemaining < Globals.gameConfig.playerMaxShots, "Player has too many lasers")
    lasersRemaining += 1
  }

  // Reset the ship (typically because the player died)
  func reset() {
    let body = coastingConfiguration()
    body.velocity = .zero
    position = .zero
    zRotation = .pi / 2
    lasersRemaining = Globals.gameConfig.playerMaxShots
  }

  func explode() -> Array<SKNode> {
    let velocity = physicsBody!.velocity
    setEngineLevel(0)
    removeFromParent()
    return makeExplosion(texture: shipTexture, angle: zRotation, velocity: velocity, at: position, duration: 2)
  }

  var size: CGSize { return shipTexture.size() }
}
