//
//  UFO.swift
//  Asteroids
//
//  Created by Daniel on 8/22/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import AVFoundation

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

// MARK: - UFO stuff

/// UFOs shoot at the player, but maybe they're just misunderstood
///
/// This handles UFO instance creation, Designed Stupidity for flying and shooting,
/// and warping out to leave the playfield when requested.
///
/// Decisions about when to spawn a UFO, when they're allowed to shoot, when they
/// should warp out, etc., are left up to the scene.
class UFO: SKNode {
  enum UFOType: Int {
    case big = 0
    case kamikaze
    case small
  }
  /// Type of UFO
  let type: UFOType
  /// The current (desired) cruising speed
  var currentSpeed: CGFloat
  /// Makes UFO noises if desired
  var engineSounds: ContinuousPositionalAudio? = nil
  /// Average time between shots
  let meanShotTime: Double
  /// Time before attacking; negative means hostilities have commenced and the UFO is
  /// firing according to `meanShotTime`
  var delayOfFirstShot: Double
  /// Becomes `true` when the UFO is allowed to attack
  var attackEnabled = false
  /// How accurately the UFOs shoot
  var shotAccuracy: CGFloat
  /// How fast Kamikaze UFOs can maneuver
  var kamikazeAcceleration: CGFloat
  /// The texture for the UFO
  let ufoTexture: SKTexture
  /// The UFO's physical size
  var size: CGSize { ufoTexture.size() }

  // MARK: - Initialization

  /// Make a UFO
  /// - Parameters:
  ///   - brothersKilled: When the player seems to be just hunting UFOs, they start
  ///     getting very dangerous
  ///   - audio: The scene's audio, or `nil` if the UFO should be silent
  required init(brothersKilled: Int, audio: SceneAudio?) {
    // Select the UFO type according to the current game configuration
    let typeChoice = Double.random(in: 0 ... 1)
    let chances = Globals.gameConfig.value(for: \.ufoChances)
    if typeChoice <= chances[0] {
      type = .big
    } else if typeChoice <= chances[0] + chances[1] {
      type = .kamikaze
    } else {
      type = .small
    }
    let typeIndex = type.rawValue
    // Choose an initial speed
    let maxSpeed = Globals.gameConfig.value(for: \.ufoMaxSpeed)[typeIndex]
    currentSpeed = .random(in: 0.5 * maxSpeed ... maxSpeed)
    // The player can destroy a few UFOs per wave without repurcussions, but after that...
    let revengeFactor = max(brothersKilled - 3, 0)
    // When delayOfFirstShot is nonnegative, it means that the UFO hasn't gotten on
    // to the screen yet.  When it appears, I schedule an action after that delay to
    // enable attacking.  When revenge factor starts increasing, the UFOs start
    // shooting faster, getting much quicker on the draw initially, and being much
    // more accurate in their shooting.
    meanShotTime = Globals.gameConfig.value(for: \.ufoMeanShotTime)[typeIndex] * pow(0.75, Double(revengeFactor))
    delayOfFirstShot = Double.random(in: 0 ... meanShotTime * pow(0.75, Double(revengeFactor)))
    shotAccuracy = Globals.gameConfig.value(for: \.ufoAccuracy)[typeIndex] * pow(0.75, CGFloat(revengeFactor))
    kamikazeAcceleration = Globals.gameConfig.value(for: \.kamikazeAcceleration) * pow(1.25, CGFloat(revengeFactor))
    // Texture and warp shader
    let textures = ["green", "blue", "red"]
    ufoTexture = Globals.textureCache.findTexture(imageNamed: "ufo_\(textures[typeIndex])")
//    warpOutShader = fanFoldShader(forTexture: ufoTexture, warpTime: warpTime)
    super.init()
    name = "ufo"
    let ufo = SKSpriteNode(texture: ufoTexture)
    ufo.name = "ufoImage"
    addChild(ufo)
    // Make noise only if the desires it.  UFOs in non-game scenes are currently
    // silent, since otherwise the constant whirring gets annoying
    if let audio = audio {
      let engineSounds = audio.continuousAudio([SoundEffect.ufoEnginesBig, .ufoEnginesMed, .ufoEnginesSmall][typeIndex], at: self)
      engineSounds.playerNode.volume = 0.5
      engineSounds.playerNode.play()
      self.engineSounds = engineSounds
    }
    let body = SKPhysicsBody(circleOfRadius: 0.5 * ufoTexture.size().width)
    body.mass = 1 - 0.125 * CGFloat(typeIndex)
    body.categoryBitMask = ObjectCategories.ufo.rawValue
    body.collisionBitMask = 0
    body.contactTestBitMask = setOf([.asteroid, .ufo, .player, .playerShot])
    body.linearDamping = 0
    body.angularDamping = 0
    body.restitution = 0.9
    // When the UFO is first created, it'll start off the screen either to the left
    // or right and will not be moving.  The scene is responsible for starting the
    // UFO.  See the discussion of spawnUFO and launchUFO in BasicScene.
    body.isOnScreen = false
    body.isDynamic = false
    body.angularVelocity = .pi * 2
    physicsBody = body
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
    }
    let maxSpeed = Globals.gameConfig.value(for: \.ufoMaxSpeed)[typeIndex]
    if Int.random(in: 0...100) == 0 {
      if type != .kamikaze {
        currentSpeed = .random(in: 0.3 * maxSpeed ... maxSpeed)
      }
      body.angularVelocity = copysign(.pi * 2, -body.angularVelocity)
    }
    let ourRadius = 0.5 * size.diagonal()
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
    var potentialTarget: SKNode? = (player?.parent != nil ? player : nil)
    var targetDistance = CGFloat.infinity
    var playerDistance = CGFloat.infinity
    let interestingDistance = 0.33 * min(bounds.width, bounds.height)
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
            r = r - r.project(unitVector: vhat).scale(by: shotAnticipation)
          }
        }
        var d = r.length()
        if type == .kamikaze && body.isA(.player) {
          // Kamikazes are alway attracted to the player no matter where they are, but I'll
          // give an initial delay using the same first-shot mechanism before this kicks in.
          if attackEnabled {
            totalForce = totalForce + r.scale(by: kamikazeAcceleration * 1000 / d)
          }
          continue
        }
        // Ignore stuff that's too far away
        guard d <= interestingDistance else { continue }
        var objectRadius = CGFloat(0)
        if body.isA(.asteroid) {
          objectRadius = 0.5 * (node as! SKSpriteNode).size.diagonal()
        } else if body.isA(.ufo) {
          objectRadius = 0.5 * (node as! UFO).size.diagonal()
        } else if body.isA(.player) {
          objectRadius = 0.5 * (node as! Ship).size.diagonal()
          playerDistance = d
        }
        if d < targetDistance && !body.isA(.ufo) {
          potentialTarget = node
          targetDistance = d
        }
        d -= ourRadius + objectRadius
        // Limit the force so as not to poke the UFO by an enormous amount
        let dmin = CGFloat(20)
        let dlim = 0.5 * (sqrt((d - dmin) * (d - dmin) + dmin) + d)
        totalForce = totalForce + r.scale(by: -forceScale / (dlim * dlim))
      }
    }
    body.applyForce(totalForce)
    // Regular UFOs have a desired cruising speed
    if type != .kamikaze {
      if body.velocity.length() > currentSpeed {
        body.velocity = body.velocity.scale(by: 0.95)
      }
      else if body.velocity.length() < currentSpeed {
        body.velocity = body.velocity.scale(by: 1.05)
      }
    }
    if body.velocity.length() > maxSpeed {
      body.velocity = body.velocity.scale(by: maxSpeed / body.velocity.length())
    }
    guard type != .kamikaze else { return }
    if playerDistance < 1.5 * targetDistance || (player?.parent != nil && Int.random(in: 0 ..< 100) >= 25) {
      // Override closest-object targetting if the player is about at the same
      // distance.  Also bias towards randomly shooting at the player even if they're
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
    engineSounds?.playerNode.stop()
    removeAllActions()
    removeFromParent()
  }

  /// Make the UFO leave the playfield by jumping to hyperspace
  /// - Returns: An array of effect nodes that should be added to the playfield to
  ///   animate the warping
  func warpOut() -> [SKNode] {
    cleanup()
    return warpOutEffect(texture: ufoTexture, position: position, rotation: zRotation)
  }

  /// Make the UFO explode
  /// - Returns: An array of nodes to add to the playfield to animate the explosion
  func explode() -> [SKNode] {
    let velocity = requiredPhysicsBody().velocity
    cleanup()
    return makeExplosion(texture: ufoTexture, angle: zRotation, velocity: velocity, at: position, duration: 2)
  }
}
