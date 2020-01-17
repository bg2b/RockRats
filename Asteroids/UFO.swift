//
//  UFO.swift
//  Asteroids
//
//  Created by Daniel on 8/22/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import AVFoundation
import os.log

// MARK: - Playfield geometry calculations

/// Compute the shortest displacement vector to something, taking into account
/// playfield wrapping
/// - Parameters:
///   - direct: The normal displacement to the object, (1, 1) means the object is up
///     and to the right
///   - bounds: The playfield bounds
/// - Returns: The shorted displacement vector when wrapping is considered
func wrappedDisplacement(direct: CGVector, bounds: CGRect) -> CGVector {
  // Two possible x's, normal and wrapped
  let dx1 = direct.dx
  let dx2 = copysign(bounds.width, -dx1) + dx1
  let dx = (abs(dx1) < abs(dx2) ? dx1 : dx2)
  // Two possible y's, normal and wrapped
  let dy1 = direct.dy
  let dy2 = copysign(bounds.height, -dy1) + dy1
  let dy = (abs(dy1) < abs(dy2) ? dy1 : dy2)
  // If I did everything right, then the object can't be farther than half the
  // playfield in either direction.  (The + 5 is because of allowed wrapping
  // hysteresis and/or roundoff errors.)
  assert(abs(dx) <= bounds.width / 2 + 5 && abs(dy) <= bounds.height / 2 + 5)
  return CGVector(dx: dx, dy: dy)
}

/// Helper routine for aiming, handles the special case of aiming at an object moving
/// horizontally
/// - Parameters:
///   - p: The starting position of the object
///   - v: The object's horizontal speed (positive)
///   - s: The speed of the shot
/// - Returns: The time of intercept, or `nil` if the object can't be hit
func aim(at p: CGVector, targetSpeed v: CGFloat, shotSpeed s: CGFloat) -> CGFloat? {
  // Consider a possible intercept time t.
  // At time t, the object will be at at (dx + v*t, dy)
  // The squared distance to the object is dx^2 + 2*dx*v*t + v^2*t^2 + dy^2
  // The squared distance that the shot will have travelled is s^2*t^2
  // For a successful intercept, these two squared distances must be equal.
  // That gives a quadratic equation for t.
  // After some algebra to rearrange to a*t^2 + b*t + c = 0, here's what I get:
  let a = s * s - v * v
  let b = -2 * p.dx * v
  let c = -p.dx * p.dx - p.dy * p.dy
  // The discriminant of the quadratic equation
  let discriminant = b * b - 4 * a * c
  // If there are only imaginary solutions, it's not possible to hit (the object is
  // moving too fast given the starting position)
  guard discriminant >= 0 else { return nil }
  let r = sqrt(discriminant)
  // Compute the two solutions
  let solutionA = (-b - r) / (2 * a)
  let solutionB = (-b + r) / (2 * a)
  // If there are two valid intercept times (e.g, the object is moving closer and can
  // be hit either on the way in or the way out), shoot at the earlier time.
  if solutionA >= 0 && solutionB >= 0 { return min(solutionA, solutionB) }
  // If both solutions are negative, it's only possible to hit the object by
  // rewinding the situation, i.e., the object would have to be travelling at speed
  // -v, which it's not...
  if solutionA < 0 && solutionB < 0 { return nil }
  // One solution is negative and one is positive, so take the positive one.
  return max(solutionA, solutionB)
}

/// Aim at an object
/// - Parameters:
///   - p: The starting position of the object
///   - v: The velocity of the object
///   - s: The speed of the shot
func aim(at p: CGVector, targetVelocity v: CGVector, shotSpeed s: CGFloat) -> CGFloat? {
  // Rotate coordinates so that the object's direction of travel is horizontally to
  // the right, then call the simple(r) case
  let theta = v.angle()
  return aim(at: p.rotate(by: -theta), targetSpeed: v.length(), shotSpeed: s)
}

/// Bound a quantity from below, but without the kink of a hard min
/// - Parameters:
///   - d: The quantity to limit
///   - minValue: The minimum value
func smoothLimit(_ d: CGFloat, minValue: CGFloat) -> CGFloat {
  return sqrt((d - minValue) * (d - minValue) + minValue) + d
}

// MARK: - UFO stuff

/// The types of UFOs
enum UFOType: Int, CaseIterable {
  case big = 0
  case kamikaze
  case small

  /// Select a random UFO type according to the current game configuration
  static func randomType() -> UFOType {
    let typeChoice = Double.random(in: 0 ... 1)
    let chances = Globals.gameConfig.value(for: \.ufoChances)
    if typeChoice <= chances[0] {
      return .big
    } else if typeChoice <= chances[0] + chances[1] {
      return .kamikaze
    } else {
      return .small
    }
  }
}

/// UFOs shoot at the player, but maybe they're just misunderstood
///
/// This handles UFO instance creation, Designed Stupidity for flying and shooting,
/// and warping out to leave the playfield when requested.
///
/// Decisions about when to spawn a UFO, when they're allowed to shoot, when they
/// should warp out, etc., are left up to the scene.
class UFO: SKNode {
  /// Type of UFO
  let type: UFOType
  /// The current (desired) cruising speed
  var currentSpeed = CGFloat(0)
  /// Makes UFO noises if desired
  var engineSounds: ContinuousPositionalAudio?
  /// Action to fade audio (optional user preference)
  var fadeAudioAction: SKAction?
  /// Average time between shots
  var meanShotTime = 0.0
  /// Time before attacking; negative means hostilities have commenced and the UFO is
  /// firing according to `meanShotTime`
  var delayOfFirstShot = 0.0
  /// Becomes `true` when the UFO is allowed to attack
  var attackEnabled = false
  /// Becomes `true` when the UFO can change course and speed
  var courseChangeAllowed = false
  /// How accurately the UFOs shoot
  var shotAccuracy = CGFloat(0)
  /// How fast Kamikaze UFOs can maneuver
  var kamikazeAcceleration = CGFloat(0)
  /// The texture for the UFO
  let ufoTexture: SKTexture
  /// The sprite for the UFO's appearance
  let ufo: SKSpriteNode
  /// The UFO's physical size
  var size: CGSize { ufoTexture.size() }
  /// Volume for UFO engine sounds; scaled down since they're a bit annoying
  static let ufoVolume = Float(0.5)

  // MARK: - Initialization

  /// Put a UFO (either newly-created, or from cache) into an appropriate initial state
  /// - Parameter brothersKilled: How angry should the UFO be?
  func reset(brothersKilled: Int) {
    let typeIndex = type.rawValue
    // Choose an initial speed
    let maxSpeed = Globals.gameConfig.value(for: \.ufoMaxSpeed)[typeIndex]
    currentSpeed = .random(in: 0.5 * maxSpeed ... maxSpeed)
    var revengeBoost = 0
    if type == .big {
      // Maybe randomly show the developers' names
      if brothersKilled > 2 && Int.random(in: 0 ..< 20) == 0 && achievementIsCompleted(.hideAndSeek) {
        ufo.texture = Globals.textureCache.findTexture(imageNamed: "developers")
        // Developers are good at the game ;-)
        revengeBoost = 2
      } else {
        // Be sure to reset the texture in case this was previously a developer UFO
        ufo.texture = ufoTexture
      }
    }
    // The player can destroy a few UFOs per wave without repurcussions, but after that...
    let revengeFactor = max(brothersKilled - 3 + revengeBoost, 0)
    // When delayOfFirstShot is nonnegative, it means that the UFO hasn't gotten on
    // to the screen yet.  When it appears, I schedule an action after that delay to
    // enable attacking.  When revenge factor starts increasing, the UFOs start
    // shooting faster, getting much quicker on the draw initially, and being much
    // more accurate in their shooting.
    let smaller = pow(0.75, Double(revengeFactor))
    meanShotTime = max(Globals.gameConfig.value(for: \.ufoMeanShotTime)[typeIndex] * smaller, 0.5)
    delayOfFirstShot = Double.random(in: 0 ... meanShotTime * smaller)
    shotAccuracy = Globals.gameConfig.value(for: \.ufoAccuracy)[typeIndex] * CGFloat(smaller)
    kamikazeAcceleration = Globals.gameConfig.value(for: \.kamikazeAcceleration) / CGFloat(smaller)
    // Don't do anything when first launched
    attackEnabled = false
    courseChangeAllowed = false
    // Gentle people, start your engines!
    engineSounds?.playerNode.volume = UFO.ufoVolume
    // When the UFO is first created, it'll start off the screen either to the left
    // or right and will not be moving.  The scene is responsible for starting the
    // UFO.  See the discussion of spawnUFO and launchUFO in BasicScene.
    let body = requiredPhysicsBody()
    body.isOnScreen = false
    body.isDynamic = false
    body.angularVelocity = .pi * 2
  }

  /// Make a UFO
  /// - Parameters:
  ///   - type: The desired type of the UFO
  ///   - audio: The scene's audio, or `nil` if the UFO should be silent
  required init(type: UFOType, audio: SceneAudio?) {
    self.type = type
    let typeIndex = type.rawValue
    // Texture and warp shader
    let textures = ["green", "blue", "red"]
    ufoTexture = Globals.textureCache.findTexture(imageNamed: "ufo_\(textures[typeIndex])")
    ufo = SKSpriteNode(texture: ufoTexture)
    ufo.name = "ufoImage"
    super.init()
    name = "ufo"
    addChild(ufo)
    // Make noise if requested.  UFOs in non-game scenes are currently silent, since
    // otherwise the constant whirring gets annoying
    if let audio = audio {
      let engineSounds = audio.continuousAudio([SoundEffect.ufoEnginesBig, .ufoEnginesMed, .ufoEnginesSmall][typeIndex], at: self)
      engineSounds.playerNode.volume = 0
      engineSounds.playerNode.play()
      self.engineSounds = engineSounds
      if UserData.fadeUFOAudio.value {
        // This optional action is run after the UFO launches to fade out the engine
        // audio since some people find it grating.
        fadeAudioAction = .customAction(withDuration: 1) { node, time in
          if let engineSounds = (node as? UFO)?.engineSounds {
            // The 0.95 is to make sure that the volume really gets to 0.  Not that
            // it really would matter, but I'm not sure if the action would always be
            // called for the final time at exactly time = 1.  Maybe depending on
            // frame rates and possible stutters or whatnot perhaps the last call
            // would be at time slightly less than 1.  Or maybe it could be with time
            // slightly greater than 1, hence the max.
            engineSounds.playerNode.volume = UFO.ufoVolume * max(Float(1 - time / 0.95), 0)
          }
        }
      }
    }
    // Physics
    let body = SKPhysicsBody(circleOfRadius: 0.5 * ufoTexture.size().width)
    body.mass = 1 - 0.125 * CGFloat(typeIndex)
    body.categoryBitMask = ObjectCategories.ufo.rawValue
    body.collisionBitMask = 0
    body.contactTestBitMask = setOf([.asteroid, .ufo, .player, .playerShot])
    body.linearDamping = 0
    body.angularDamping = 0
    body.restitution = 0.9
    physicsBody = body
  }

  convenience init(audio: SceneAudio?) {
    self.init(type: UFOType.randomType(), audio: audio)
    reset(brothersKilled: 0)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by UFO")
  }

  // MARK: - Flying and shooting

  /// Make the UFO do stuff
  ///
  /// Call this each time in the scene's `update` loop
  /// - Parameters:
  ///   - player: The player, if the scene has one
  ///   - playfield: The playfield where things are moving around
  ///   - addLaser: A closure that the UFO calls to shoot
  ///   - angle: Angle the shot is being fired at (radians)
  ///   - position: Position the shot should be started from
  ///   - speed: Speed of the shot
  func fly(player: Ship?, playfield: Playfield, addLaser: (_ angle: CGFloat, _ position: CGPoint, _ speed: CGFloat) -> Void) {
    guard parent != nil else { return }
    let bounds = playfield.bounds
    let body = requiredPhysicsBody()
    guard body.isOnScreen else { return }
    let typeIndex = type.rawValue
    if delayOfFirstShot >= 0 {
      // Just moved onto the screen, enable shooting after a delay.
      // Kamikazes never shoot, but I use the same mechanism to turn off
      // their homing behavior initially.
      wait(for: delayOfFirstShot) { [unowned self] in self.attackEnabled = true }
      delayOfFirstShot = -1
      // Change course/speed at some point
      scheduleCourseChange()
      if let fade = fadeAudioAction {
        run(fade)
      }
    }
    let maxSpeed = Globals.gameConfig.value(for: \.ufoMaxSpeed)[typeIndex]
    if courseChangeAllowed {
      if type != .kamikaze {
        currentSpeed = .random(in: 0.3 * maxSpeed ... maxSpeed)
        if .random(in: 0 ..< 5) == 0 {
          body.velocity = body.velocity.rotate(by: .random(in: -.pi / 2 ... .pi / 2))
        }
      }
      body.angularVelocity = copysign(.pi * 2, -body.angularVelocity)
      scheduleCourseChange()
    }
    let ourRadius = 0.5 * size.width
    let forceScale = Globals.gameConfig.value(for: \.ufoDodging)[typeIndex] * 1000
    let shotAnticipation = Globals.gameConfig.value(for: \.ufoShotAnticipation)[typeIndex]
    var totalForce = CGVector.zero
    let interesting = (shotAnticipation > 0 ?
      setOf([.asteroid, .ufo, .player, .playerShot]) :
      setOf([.asteroid, .ufo, .player]))
    // By default, shoot at the player.  If there's an asteroid that's notably closer
    // though, shoot that instead.  In addition to the revenge factor increase in UFO
    // danger, that helps ensure that the player can't sit around and farm UFOs for
    // points forever.
    var potentialTarget: SKNode?
    var targetAsteroidDistance = CGFloat.infinity
    var targetAsteroidSizeIndex = 0
    var playerDistance = CGFloat.infinity
    let interestingDistance = 0.5 * min(bounds.width, bounds.height)
    for node in playfield.children {
      // Be sure not to consider off-screen things.  That happens if the last asteroid is
      // destroyed while the UFO is flying around and a new wave spawns.
      guard let body = node.physicsBody, body.isOnScreen else { continue }
      if body.isOneOf(interesting) {
        var r = wrappedDisplacement(direct: node.position - position, bounds: bounds)
        if body.isA(.playerShot) {
          // Shots travel fast, so emphasize dodging to the side.  Do this by projecting out
          // some of the displacement along the direction of the shot.
          let vhat = body.velocity.scale(by: 1 / body.velocity.length())
          if r.dotProd(vhat) > 0 {
            // Project only if the shot is moving towards the UFO
            r -= r.project(unitVector: vhat).scale(by: shotAnticipation)
          }
        }
        var d = r.length()
        if type == .kamikaze && body.isA(.player) {
          // Kamikazes are alway attracted to the player no matter where they are, but I'll
          // give an initial delay using the same first-shot mechanism before this kicks in.
          if attackEnabled {
            totalForce += r.scale(by: kamikazeAcceleration * 1000 / sqrt(smoothLimit(d, minValue: ourRadius)))
          }
          continue
        }
        // Ignore stuff that's too far away
        guard d <= interestingDistance else { continue }
        var objectRadius = CGFloat(0)
        if body.isA(.asteroid) {
          objectRadius = 0.5 * (node as! SKSpriteNode).size.width
          guard let sizeIndex = AsteroidSize(ofBody: body)?.sizeIndex else { fatalError("Could not get asteroid size") }
          let desirableTarget: Bool
          if Globals.gameConfig.ufoBigTargetPriority {
            // Shoot bigger asteroids in preference to smaller ones, then closer ones
            // in preference to farther
            desirableTarget = sizeIndex > targetAsteroidSizeIndex || (sizeIndex == targetAsteroidSizeIndex && d < targetAsteroidDistance)
          } else {
            // Just shoot closer asteroids
            desirableTarget = d < targetAsteroidDistance
          }
          if desirableTarget {
            potentialTarget = node
            targetAsteroidDistance = d
            targetAsteroidSizeIndex = sizeIndex
          }
        } else if body.isA(.ufo) {
          objectRadius = 0.5 * (node as! UFO).size.width
        } else if body.isA(.player) {
          objectRadius = 0.5 * (node as! Ship).size.diagonal()
          playerDistance = d
        }
        d -= ourRadius + objectRadius
        // Limit the force so as not to poke the UFO by an enormous amount
        let dlim = smoothLimit(d, minValue: 20)
        if body.isA(.asteroid) {
          // Make the UFOs a little more responsive to distant asteroids
          totalForce += r.scale(by: -forceScale / (dlim * sqrt(dlim)))
        } else {
          totalForce += r.scale(by: -forceScale / (dlim * dlim))
        }
      }
    }
    body.applyForce(totalForce)
    // Regular UFOs have a desired cruising speed
    if type != .kamikaze {
      if body.velocity.length() > currentSpeed {
        body.velocity = body.velocity.scale(by: 0.95)
      } else if body.velocity.length() < currentSpeed {
        body.velocity = body.velocity.scale(by: 1.05)
      }
    }
    if body.velocity.length() > maxSpeed {
      body.velocity = body.velocity.scale(by: maxSpeed / body.velocity.length())
    }
    guard type != .kamikaze else { return }
    if playerDistance < 1.5 * targetAsteroidDistance || (player?.parent != nil && Int.random(in: 0 ..< 4) != 0) {
      // Shoot the player if they're at about the same distance as an asteroid
      // target.  Also bias towards randomly shooting at the player even if they're
      // pretty far.
      potentialTarget = player
    }
    guard let target = potentialTarget, attackEnabled else { return }
    let shotSpeed = Globals.gameConfig.value(for: \.ufoShotSpeed)[typeIndex]
    let useBounds = Globals.gameConfig.value(for: \.ufoShotWrapping)
    guard var angle = aimAt(target, shotSpeed: shotSpeed, bounds: useBounds ? bounds : nil) else { return }
    if target != player {
      // If targetting an asteroid, be pretty accurate
      angle += CGFloat.random(in: -0.1 * shotAccuracy * .pi ... 0.1 * shotAccuracy * .pi)
    } else {
      angle += CGFloat.random(in: -shotAccuracy * .pi ... shotAccuracy * .pi)
    }
    shotAccuracy *= 0.97  // Gunner training ;-)
    let shotDirection = CGVector(angle: angle)
    let shotPosition = position + shotDirection.scale(by: 0.5 * size.width)
    addLaser(angle, shotPosition, shotSpeed)
    attackEnabled = false
    wait(for: .random(in: 0.5 * meanShotTime ... 1.5 * meanShotTime)) { [unowned self] in self.attackEnabled = true }
  }

  /// Schedule a future change in coure and/or speed
  func scheduleCourseChange() {
    courseChangeAllowed = false
    wait(for: .random(in: 0.5 ... 1.5)) { [unowned self] in self.courseChangeAllowed = true }
  }

  /// Aim an object, taking into account the UFO's position and shot speed and the
  /// object's position and velocity
  ///
  /// This is for "perfect" accuracy assuming uniform target motion.  (Actually this
  /// doesn't account for the fact that the shot starts at the edge of the UFO and
  /// not at its center.  But aiming will be fuzzed anyway, plus the target may be
  /// accelerating, plus the target isn't actually a point anyway, so whatevs...)
  ///
  /// - Parameters:
  ///   - object: What to aim at
  ///   - shotSpeed: The UFO's shot speed
  ///   - bounds: If non-`nil`, the playfield bounds for possible wrapped shots
  /// - Returns: The angle to fire the shot (radians), or `nil` if the target can't be hit
  func aimAt(_ object: SKNode, shotSpeed: CGFloat, bounds: CGRect?) -> CGFloat? {
    guard let body = object.physicsBody else { return nil }
    var p = object.position - position
    if let bounds = bounds {
      p = wrappedDisplacement(direct: p, bounds: bounds)
    }
    // Compute the amount of time needed for the UFO's shot to reach the target
    guard let time = aim(at: p, targetVelocity: body.velocity, shotSpeed: shotSpeed) else { return nil }
    // Compute the target's position at that time
    let futurePos = p + body.velocity.scale(by: time)
    // Aim at that position
    return futurePos.angle()
  }

  // MARK: - Leaving and dying

  /// Clean up any potential mess when a UFO is about to be removed
  func cleanup() {
    engineSounds?.playerNode.volume = 0
    removeAllActions()
    removeFromParent()
  }

  /// Make the UFO leave the playfield by jumping to hyperspace
  /// - Returns: An array of effect nodes that should be added to the playfield to
  ///   animate the warping
  func warpOut() -> [SKNode] {
    cleanup()
    // Don't use ufoTexture because ufo.texture may not equal ufoTexture.  Developers
    // are always mucking things up...
    return warpOutEffect(texture: ufo.requiredTexture(), position: position, rotation: zRotation)
  }

  /// Make the UFO explode
  /// - Returns: An array of nodes to add to the playfield to animate the explosion
  func explode(collision: Bool) -> [SKNode] {
    let velocity = requiredPhysicsBody().velocity
    cleanup()
    // Not ufoTexture, since that may not be what's being shown in the sprite
    let texture = ufo.requiredTexture()
    if collision {
      // Two ships/UFOs collided.  Some older devices lag when using full resolution
      // explosions in this case, but since the UFO debris is mixed up with the
      // fragments of the other ship, lower resolution explosions look OK.
      return makeExplosion(texture: texture, angle: zRotation, velocity: velocity, at: position, duration: 2, cuts: 5)
    } else {
      return makeExplosion(texture: texture, angle: zRotation, velocity: velocity, at: position, duration: 2)
    }
  }
}

// MARK: - Reusing UFOs

/// A cache of UFOs for a scene
class UFOCache {
  /// The scene's audio, used when creating new UFOs
  let audio: SceneAudio?
  /// The number of UFOs created
  var created = 0
  /// The number of UFOs that have been reused
  var reused = 0
  /// An array of arrays holding ready-to-reuse UFOs, one array per UFO type
  var availableUFOs = [[UFO]]()

  /// Initialize the cache and pre-populate it with spare UFOs
  init(audio: SceneAudio?) {
    self.audio = audio
    // Make the cache arrays
    for _ in UFOType.allCases {
      availableUFOs.append([])
    }
    // Add one UFO for each type, since that's mostly all that will be used.  On the
    // occasions when a second UFO starts flying around, it'll be made on-demand if it
    // happens to be the same type as the first one.
    for type in UFOType.allCases {
      recycle(get(type: type))
    }
  }

  /// Print some meaningless statistics on UFO reuse
  deinit {
    os_log("Made %d UFOs, reused %d", log: .app, type: .debug, created, reused)
  }

  /// Get a UFO of a particular type
  ///
  /// Since this is used for pre-populating the cache, it does not reset the UFO.
  ///
  /// - Parameter type: The type of UFO wanted
  func get(type: UFOType) -> UFO {
    let typeIndex = type.rawValue
    if let ufo = availableUFOs[typeIndex].popLast() {
      reused += 1
      return ufo
    } else {
      created += 1
      return UFO(type: type, audio: audio)
    }
  }

  /// Make a new UFO and get it ready to go
  /// - Parameter brothersKilled: How greedy should the UFO be for revenge?
  func getRandom(brothersKilled: Int) -> UFO {
    let ufo = get(type: UFOType.randomType())
    ufo.reset(brothersKilled: brothersKilled)
    return ufo
  }

  /// Put a UFO in the cache for reuse
  /// - Parameter ufo: The UFO whose job for now is done
  func recycle(_ ufo: UFO) {
    availableUFOs[ufo.type.rawValue].append(ufo)
  }
}
