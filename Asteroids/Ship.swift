//
//  Ship.swift
//  Asteroids
//
//  Created by David Long on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import AVFoundation

class Ship: SKNode {
  let joystick: Joystick
  let shipTexture: SKTexture
  let engineSounds: AVAudioPlayer
  var engineSoundLevel = 0
  var forwardFlames = [SKSpriteNode]()
  var reverseFlames = [[SKSpriteNode]]()
  var lasersRemaining = Globals.gameConfig.playerMaxShots
  let warpTime = 0.5
  let warpOutShader: SKShader
  let warpInShader: SKShader

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

  required init(color: String, sounds: Sounds, joystick: Joystick) {
    self.joystick = joystick
    self.shipTexture = Globals.textureCache.findTexture(imageNamed: "ship_\(color)")
    engineSounds = sounds.audioPlayerFor(.playerEngines)
    engineSounds.numberOfLoops = -1
    engineSounds.volume = 0
    sounds.startPlaying(engineSounds)
    warpOutShader = swirlShader(forTexture: shipTexture, inward: true, warpTime: warpTime)
    warpInShader = swirlShader(forTexture: shipTexture, inward: false, warpTime: warpTime)
    super.init()
    self.name = "ship"
    let ship = SKSpriteNode(texture: shipTexture)
    ship.name = "shipImage"
    addChild(ship)
    sounds.addPositional(player: engineSounds, at: self)
    forwardFlames = buildFlames(at: CGPoint(x: -shipTexture.size().width / 2, y: 0.0))
    for side in [-1, 1] {
      reverseFlames.append(buildFlames(at: CGPoint(x: 0, y: CGFloat(side) * shipTexture.size().height / 2.1),
                                       scale: 0.5, direction: .pi))
    }
    physicsBody = SKPhysicsBody(texture: shipTexture, size: shipTexture.size())
    let body = coastingConfiguration()
    body.mass = 1
    body.categoryBitMask = ObjectCategories.player.rawValue
    body.collisionBitMask = 0
    body.contactTestBitMask = setOf([.asteroid, .ufo, .ufoShot])
    body.linearDamping = Globals.gameConfig.playerSpeedDamping
    body.restitution = 0.9
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
      // The first 0.25 * is to reduce the overall volume.  The second is to scale
      // soundLevel to 0...1
      engineSounds.volume = 0.25 * 0.25 * Float(soundLevel)
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
    let stick = joystick.getDirection()
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
    let currentSpeed = body.velocity.norm2()
    if currentSpeed > 0.5 * maxSpeed {
      thrustForce *= (maxSpeed - currentSpeed) / (0.5 * maxSpeed)
    }
    body.applyForce(CGVector(angle: zRotation).scale(by: thrustForce))
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

  func warpEffect(shader: SKShader) -> SKNode {
    let effect = SKSpriteNode(texture: shipTexture)
    effect.position = position
    effect.zRotation = zRotation
    effect.shader = shader
    setStartTimeAttrib(effect)
    return effect
  }

  func warpOut() -> [SKNode] {
    let effect = warpEffect(shader: warpOutShader)
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
    let effect = warpEffect(shader: warpInShader)
    playfield.addWithScaling(effect)
    effect.run(SKAction.sequence([SKAction.wait(forDuration: warpTime), SKAction.removeFromParent()])) {
      playfield.addWithScaling(self)
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
