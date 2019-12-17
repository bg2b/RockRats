//
//  Ship.swift
//  Asteroids
//
//  Created by David Long on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import AVFoundation

// MARK: Ship appearance info

/// An identifier for the current look of the ship
enum ShipAppearance: Int {
  case modern = 0
  case retro
}

/// A holder for things that change based on the ship's appearance
class ShipAppearanceAlternative {
  /// The ship's texture
  let texture: SKTexture
  /// The sprite used for the ship
  let sprite: SKSpriteNode
  /// A closely-conforming physics body
  let body: SKPhysicsBody

  /// Make an alternative appearance
  /// - Parameters:
  ///   - imageName: The name of the texture for the ship
  ///   - warpTime: The amount of time the hyperspace effects should take
  init(imageName: String, warpTime: Double) {
    texture = Globals.textureCache.findTexture(imageNamed: imageName)
    sprite = SKSpriteNode(texture: texture)
    sprite.name = "shipImage"
    body = Globals.conformingPhysicsCache.makeBody(texture: texture)
  }
}

// MARK: - The ship

/// The player!
///
/// Handles the main sprite, thrust animation and engine sounds, keeping track of
/// available laser shots, and flying based on a joystick input.
///
/// The actual control of the ship (turning touches into desired actions) is mostly
/// elsewhere, in `GameTutorialScene`.  This class provides methods to do the various
/// things (shoot, jump to hyperspace, come back from hyperspace, fly using a vector
/// representing the joystick state).
///
/// - Note: `Ship` also doesn't include any notion of the energy reserve.  If the
///   energy bookkeeping were moved here, there would have to be an interface with a
///   separate `EnergyBar` to display it, since the display has to be elsewhere in
///   the node hierarchy.  I've instead decided to have the `EnergyBar` keep track of
///   the energy, and have `canShoot` and `canJump` deduct from it as part of the
///   check for whether an action is possible.
class Ship: SKNode {
  /// A closure that gives the joystick direction, normalized so max activation is a unit vector
  let getJoystickDirection: () -> CGVector
  /// Possible looks for the ship
  var shipAppearances: [ShipAppearanceAlternative]
  /// Identifier for how the ship currently looks
  var currentAppearance = ShipAppearance.modern
  /// The engine sound generator
  var engineSounds: ContinuousPositionalAudio!
  /// The current level of engine sounds, 0 = off; there are a few levels
  var engineSoundLevel = 0
  /// Engine flame animations for forward thrust
  var forwardFlames = [SKSpriteNode]()
  /// Engine flame animations for reverse thrust
  var reverseFlames = [[SKSpriteNode]]()
  /// The number of lasers available to shoot
  var lasersRemaining = Globals.gameConfig.playerMaxShots

  // MARK: - Initialization

  /// Construct flame animations for the engines
  /// - Parameters:
  ///   - exhaustPos: Where the flames should be relative to the ship's origin; the
  ///     base of the flames goes here
  ///   - scale: How big the flames should be
  ///   - direction: The direction the flames should point (forward thrust = 0)
  /// - Returns: An array of animated sprites for different thrust levels
  func buildFlames(at exhaustPos: CGPoint, scale: CGFloat = 1, direction: CGFloat = 0) -> [SKSpriteNode] {
    // The basic animation is a few sprites shown in sequence
    var fire = (1...3).compactMap { Globals.textureCache.findTexture(imageNamed: "fire\($0)") }
    // fire[0], fire[1], fire[2] have no inner flame core, a moderate core, and a
    // large core.  Add one more moderate core step to complete the animation loop.
    fire.append(fire[1])
    let fireSize = fire[0].size()
    let fireAnimation = SKAction.repeatForever(.animate(with: fire, timePerFrame: 0.1, resize: false, restore: true))
    // The returned sprites are based off fire[0] but stretched by different amounts
    // for the different thrust levels
    var flames = [SKSpriteNode]()
    for stretch in [0.5, 1.0, 1.5, 2.0] {
      let sprite = SKSpriteNode(texture: fire[0], size: fireSize)
      sprite.name = "shipExhaust"
      // Put the base of the flames at the exhaustPos
      sprite.anchorPoint = CGPoint(x: 1.0, y: 0.5)
      sprite.run(fireAnimation)
      // Stretch non-uniformly, so the width stays the same but the flames get longer
      // at higher thrust
      sprite.scale(to: CGSize(width: scale * CGFloat(stretch) * fireSize.width, height: scale * fireSize.height))
      sprite.zRotation = direction
      sprite.position = exhaustPos
      flames.append(sprite)
      addChild(sprite)
    }
    return flames
  }

  /// Create a ship
  /// - Parameters:
  ///   - getJoystickDirection: A closure to return the (normalized) joystick
  ///     direction.  (1, 0) means max forward thrust, (0, 1) is a maximum clockwise
  ///     turn
  ///   - audio: The scene's audio handler
  required init(getJoystickDirection: @escaping () -> CGVector, audio: SceneAudio) {
    self.getJoystickDirection = getJoystickDirection
    // Orginally color was a parameter in anticipation of some sort of multi-player,
    // but for now the player can have any ship so long as it's blue.
    let color = "blue"
    shipAppearances = []
    shipAppearances.append(ShipAppearanceAlternative(imageName: "ship_\(color)", warpTime: warpTime))
    shipAppearances.append(ShipAppearanceAlternative(imageName: "retroship", warpTime: warpTime))
    super.init()
    // The engine sounds play continually and the stereo balance is adjusted
    // according to the ship's position.  The ship just adjusts the volume according
    // to the thrust level.
    engineSounds = audio.continuousAudio(.playerEngines, at: self)
    engineSounds.playerNode.volume = 0
    engineSounds.playerNode.play()
    self.name = "ship"
    addChild(shipAppearance.sprite)
    // Forward flames happen at the back end of the texture
    forwardFlames = buildFlames(at: CGPoint(x: -shipTexture.size().width / 2, y: 0.0))
    for side in [-1, 1] {
      // There are two small reverse flames, one per side
      reverseFlames.append(buildFlames(at: CGPoint(x: 0, y: CGFloat(side) * shipTexture.size().height / 2.1),
                                       scale: 0.5, direction: .pi))
    }
    for appearance in shipAppearances {
      // The appearance initializers only handle the physics body shapes, not the properties
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

  // MARK: - Flying

  /// Turn all flames off
  func flamesOff() {
    forwardFlames.forEach { $0.isHidden = true }
    reverseFlames[0].forEach { $0.isHidden = true }
    reverseFlames[1].forEach { $0.isHidden = true }
  }

  /// Turn some flames on according to the thrust level
  /// - Parameters:
  ///   - flames: An array of flames
  ///   - amount: The amount of thrust, 0 ... 1
  func flamesOn(_ flames: [SKSpriteNode], amount: CGFloat) {
    let flameIndex = Int(0.99 * amount * CGFloat(flames.count))
    flames[flameIndex].isHidden = false
  }

  /// Turn on the forward thrust flames
  /// - Parameter amount: The thrust amount, 0 ... 1
  func forwardFlamesOn(_ amount: CGFloat) {
    flamesOn(forwardFlames, amount: amount)
    setEngineLevel(amount)
  }

  /// Turn on the reverse thrust flames
  /// - Parameter amount: The thrust amount, 0 ... 1
  func reverseFlamesOn(_ amount: CGFloat) {
    flamesOn(reverseFlames[0], amount: amount)
    flamesOn(reverseFlames[1], amount: amount)
    setEngineLevel(0.5 * amount)
  }

  /// Set the engine sound level
  /// - Parameter amount: The thrust amount, 0 ... 1
  func setEngineLevel(_ amount: CGFloat) {
    // I change the level in discrete steps because continuous seemed to cause a bit
    // of lag, but that was in the days of a separate AVAudioPlayer, and maybe it
    // wouldn't be a problem anymore.  But whatevs...
    let soundLevel = Int((amount + 0.24) * 4)
    if soundLevel != engineSoundLevel {
      // The first 0.5 * is to reduce the overall volume.  The second is to scale
      // soundLevel to 0 ... 1
      engineSounds.playerNode.volume = 0.5 * 0.25 * Float(soundLevel)
      engineSoundLevel = soundLevel
    }
  }

  /// Sets the ship to the standard coasting configuration
  /// - Returns: The ship's physics body, just for convenience
  func coastingConfiguration() -> SKPhysicsBody {
    let body = requiredPhysicsBody()
    // The ship's rotational velocity is set in each update loop; it doesn't just
    // keep spinning
    body.angularVelocity = 0
    flamesOff()
    return body
  }

  /// Make the ship respond appropriately to joystick inputs
  ///
  /// Call this from the main `update` loop
  func fly() {
    // If dead or in hyperspace, just make sure the engine sounds are off
    guard parent != nil else {
      setEngineLevel(0)
      return
    }
    let body = coastingConfiguration()
    let stick = getJoystickDirection()
    guard stick != .zero else {
      // If the joystick is centered, turn off the engine sounds and coast
      setEngineLevel(0)
      return
    }
    // The player is actually trying to do something...
    var thrustAmount = CGFloat(0)
    var thrustForce = CGFloat(0)
    let maxOmega = Globals.gameConfig.playerMaxRotationRate
    let maxThrust = Globals.gameConfig.playerMaxThrust
    let angle = stick.angle()
    // Joystick activation is in terms of 120 degree sectors, so there's some
    // overlap.  I.e., with the stick pointing 45 degrees left, the ship will both
    // rotate counterclockwise and thrust forward
    let halfSectorSize = (120 * CGFloat.pi / 180) / 2
    if abs(angle) >= .pi - 0.5 * halfSectorSize {
      // Joystick is pointing backwards, apply reverse thrusters.  (Despite the
      // overlapping sectors mumbo jumbo above, I find that reverse thrust tends to
      // be confusing while turning, so I've reduced the region where reverse thrust
      // is active.)
      thrustAmount = min(-stick.dx, 0.7) / 0.7
      thrustForce = -0.5 * thrustAmount
    } else if abs(angle) <= halfSectorSize {
      // Pointing forwards, thrusters active
      thrustAmount = min(stick.dx, 0.7) / 0.7
      thrustForce = thrustAmount
    }
    if abs(abs(angle) - .pi / 2) <= halfSectorSize {
      // Left or right rotation, set an absolute angular speed
      body.angularVelocity = copysign(maxOmega * min(abs(stick.dy), 0.7) / 0.7, angle)
    }
    thrustForce *= maxThrust
    // thrustAmount is always positive and in 0 ... 1
    // thrustForce is positive for forward thrust and negative for reverse, and the
    // magnitude is scaled to make the ship respond appropriately
    let maxSpeed = Globals.gameConfig.playerMaxSpeed
    var currentSpeed = body.velocity.length()
    // Clamp the ship's speed at some reasonable maximum
    if currentSpeed > maxSpeed {
      body.velocity = body.velocity.scale(by: maxSpeed / currentSpeed)
      currentSpeed = maxSpeed
    }
    // Compute the force vector to apply based on the ship's angle
    var appliedForce = CGVector(angle: zRotation).scale(by: thrustForce)
    if currentSpeed > 0.5 * maxSpeed {
      // If the ship is moving quickly, taper down any additional thrust the would
      // accelerate it even more in the movement direction
      let vhat = body.velocity.scale(by: 1 / currentSpeed)
      var direct = appliedForce.dotProd(vhat)
      let tangentialForce = appliedForce - vhat.scale(by: direct)
      if direct > 0 {
        // There's a component of thrust in the direction of movement, taper that
        direct *= (maxSpeed - currentSpeed) / (0.5 * maxSpeed)
      }
      appliedForce = tangentialForce + vhat.scale(by: direct)
    }
    body.applyForce(appliedForce)
    // Show the rocket exhaust
    if thrustForce > 0 {
      forwardFlamesOn(thrustAmount)
    } else if thrustForce < 0 {
      reverseFlamesOn(thrustAmount)
    }
  }

  // MARK: - Appearance

  /// The current appearance of the ship
  var shipAppearance: ShipAppearanceAlternative { return shipAppearances[currentAppearance.rawValue] }

  /// The texture for the current appearance
  var shipTexture: SKTexture { return shipAppearance.texture }

  /// The size of the ship's texture
  var size: CGSize { return shipTexture.size() }

  /// Set the ship's appearance
  /// - Parameter newAppearance: The desired appearance
  func setAppearance(to newAppearance: ShipAppearance) {
    if currentAppearance != newAppearance {
      // Remove the sprite for the old appearance, set the new one
      shipAppearance.sprite.removeFromParent()
      currentAppearance = newAppearance
      addChild(shipAppearance.sprite)
      // Switch to the physics body shape for the new appearance.  I don't have to
      // worry about copying velocity or whatnot because the appearance switch
      // happens only during a hyperspace jump.  When the player warps back in after
      // the jump, their velocity will be set to zero.
      physicsBody = shipAppearance.body
      for revFlameIndex in [0, 1] {
        // The forward flames are OK for both appearances, but the reverse flames
        // have to be adjusted to match the texture.  Ugly but not complicated, so
        // whatevs...
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

  // MARK: - Hyperspace

  /// See if the player can jump (and use the required energy if so)
  /// - Parameter energyBar: The energy reserve
  /// - Returns: `true` if go for jump
  func canJump(_ energyBar: EnergyBar) -> Bool {
    return parent != nil && energyBar.useEnergy(40)
  }

  /// Make the jump to hyperspace
  /// - Returns: An array of effects that should be added to the playfield
  func warpOut() -> [SKNode] {
    setEngineLevel(0)
    removeFromParent()
    return warpOutEffect(texture: shipTexture, position: position, rotation: zRotation)
  }

  /// Jump back from hyperspace
  /// - Parameters:
  ///   - pos: The position to jump to
  ///   - angle: The angle to be pointing in (radians)
  ///   - playfield: The `Playfield` object to be added to
  func warpIn(to pos: CGPoint, atAngle angle: CGFloat, addTo playfield: Playfield) {
    position = pos
    zRotation = angle
    // Kill the velocity
    let body = coastingConfiguration()
    body.velocity = .zero
    playfield.addWithScaling(warpInEffect(texture: shipTexture, position: position, rotation: zRotation) {
      playfield.addWithScaling(self)
    })
  }

  // MARK: - Shooting

  /// See if the player can fire (and use the required energy if so)
  /// - Parameter energyBar: The energy reserve
  /// - Returns: `true` when shooting is approved
  func canShoot(_ energyBar: EnergyBar) -> Bool {
    return parent != nil && lasersRemaining > 0 && energyBar.useEnergy(3)
  }

  /// Fire a laser
  /// - Parameter shot: The node for the laser
  func shoot(laser shot: SKNode) {
    shot.zRotation = zRotation
    let shotDirection = CGVector(angle: zRotation)
    shot.position = position + shotDirection.scale(by: 0.5 * shipTexture.size().width)
    shot.requiredPhysicsBody().velocity = shotDirection.scale(by: Globals.gameConfig.playerShotSpeed)
    lasersRemaining -= 1
  }

  func laserDestroyed() {
    assert(lasersRemaining < Globals.gameConfig.playerMaxShots, "Player has too many lasers")
    lasersRemaining += 1
  }

  // MARK: - Death and rebirth

  /// Make the ship explode
  /// - Returns: An array of nodes to be added to the playfield for the explosion
  func explode() -> [SKNode] {
    let velocity = physicsBody!.velocity
    setEngineLevel(0)
    removeFromParent()
    return makeExplosion(texture: shipTexture, angle: zRotation, velocity: velocity, at: position, duration: 2)
  }

  /// Reset the ship (typically because the player died)
  func reset() {
    let body = coastingConfiguration()
    body.velocity = .zero
    position = .zero
    zRotation = .pi / 2
    lasersRemaining = Globals.gameConfig.playerMaxShots
  }
}
