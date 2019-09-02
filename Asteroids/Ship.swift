//
//  Ship.swift
//  Asteroids
//
//  Created by David Long on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import AVFoundation

func hyperspaceShader(forTexture texture: SKTexture, inward: Bool, warpTime: Double) -> SKShader {
  // The a_start_time ugliness is because u_time starts from 0 when a shader is first
  // used, but after that it just keeps counting up.  We have to be able to shift it
  // so that it effectively starts from 0 each time we use the shader.
  //
  // Also be careful not to assume that the texture has v_tex_coord ranging in (0, 0)
  // to (1, 1)!  If the texture is part of a texture atlas, this is not true.  We
  // could make another attribute or uniform to pass in the textureRect info, but
  // since we only use this with a particular texture, we just pass in the texture
  // and compile in the required v_tex_coord transformations for that texture.
  //
  // I still have some residual confusion about coordinate spaces in these things.
  // If you look in the tiling shader used for the background star field, v_tex_coord
  // on input corresponded to a position in the frame that was normalized to
  // (0,0)-(1,1).  In that case we shifted and scaled only on output when the
  // coordinate was being used to index into the tiled texture.  In this case, it's a
  // texture for a sprite node that we're warping, and the input coordinate seems to
  // be in terms of the textureRect coordinates too.  So we have to inverse transform
  // to get to (0,0)-(1,1), do our stuff, and then transform back again to
  // textureRect.
  let rect = texture.textureRect()
  let shaderSource = """
  void main() {
    float dt = min((u_time - a_start_time) / \(warpTime), 1.0);
    float size = \(inward ? "1.0 - " : "")dt;
    float max_rot = \(inward ? 6.0 : -6.0) * (1.0 - size);
    v_tex_coord -= vec2(\(rect.origin.x), \(rect.origin.y));
    v_tex_coord *= vec2(\(1 / rect.size.width), \(1 / rect.size.height));
    float p = min(distance(v_tex_coord, vec2(0.5, 0.5)) * 2.0, 1.0);
    if (p > size) {
      gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
      v_tex_coord -= 0.5;
      v_tex_coord *= 2.0;
      v_tex_coord /= size + 0.001;
      float rot = max_rot * (1.0 - p);
      float c = cos(rot);
      float s = sin(rot);
      v_tex_coord = vec2(c * v_tex_coord.x + s * v_tex_coord.y, -s * v_tex_coord.x + c * v_tex_coord.y);
      v_tex_coord /= 2.0;
      v_tex_coord += 0.5;
      v_tex_coord *= vec2(\(rect.size.width), \(rect.size.height));
      v_tex_coord += vec2(\(rect.origin.x), \(rect.origin.y));
      gl_FragColor = texture2D(u_texture, v_tex_coord);
    }
  }
  """
  let shader = SKShader(source: shaderSource)
  shader.attributes = [SKAttribute(name: "a_start_time", type: .float)]
  return shader
}

class Ship: SKNode {
  let joystick: Joystick
  let shipTexture: SKTexture
  let engineSounds: AVAudioPlayer
  var engineSoundLevel = 0
  var forwardFlames = [SKSpriteNode]()
  var reverseFlames = [[SKSpriteNode]]()
  var lasersRemaining = Globals.gameConfig.playerMaxShots
  let warpTime = 0.5
  var warpOutShader: SKShader
  var warpInShader: SKShader
  var firstWarpTime: Double?

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
    warpOutShader = hyperspaceShader(forTexture: shipTexture, inward: true, warpTime: warpTime)
    warpInShader = hyperspaceShader(forTexture: shipTexture, inward: false, warpTime: warpTime)
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
    body.linearDamping = Globals.gameConfig.playerSpeedDamping[Globals.directControls]
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
    let maxOmega = Globals.gameConfig.playerMaxRotationRate[Globals.directControls]
    let maxThrust = Globals.gameConfig.playerMaxThrust[Globals.directControls]
    if Globals.directControls == 1 {
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
      if abs(delta) < maxOmega / 50 {
        // Once we get close, just snap to the desired angle to avoid stuttering
        zRotation = angle
      } else {
        // Set an absolute angular speed
        body.angularVelocity = copysign(maxOmega, delta)
      }
      thrustAmount = stick.norm2()
      if thrustAmount < 0.9 {
        thrustAmount = 0
      }
      let thrustCutoff = CGFloat.pi / 10
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
    }
    thrustForce *= maxThrust
    let maxSpeed = Globals.gameConfig.playerMaxSpeed[Globals.directControls]
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
    if let firstWarpTime = firstWarpTime {
      // u_time in the shader started at 0 when the global time was firstWarpOutTime.
      // The global time is now Globals.lastUpdateTime.
      // Therefore u_time now is Globals.lastUpdateTime - firstWarpOutTime.
      // We want set the offset a_start_time to this to shift the effective u_time to 0.
      effect.setValue(SKAttributeValue(float: Float(Globals.lastUpdateTime - firstWarpTime)), forAttribute: "a_start_time")
    } else {
      effect.setValue(SKAttributeValue(float: 0), forAttribute: "a_start_time")
      firstWarpTime = Globals.lastUpdateTime
    }
    return effect
  }

  func warpOut() -> [SKNode] {
    let effect = warpEffect(shader: warpOutShader)
    effect.run(SKAction.sequence([SKAction.wait(forDuration: warpTime), SKAction.removeFromParent()]))
    let star = starBlink()
    setEngineLevel(0)
    removeFromParent()
    return [effect, star]
  }

  func starBlink() -> SKSpriteNode {
    let star = SKSpriteNode(imageNamed: "star1")
    star.position = position
    star.scale(to: CGSize(width: 0, height: 0))
    star.run(SKAction.sequence([
      SKAction.group([
        SKAction.sequence([
          SKAction.scale(to: 2, duration: self.warpTime),
          SKAction.scale(to: 0, duration: self.warpTime)
          ]),
        SKAction.rotate(byAngle: .pi, duration: self.warpTime * 2),
        ]),
      SKAction.removeFromParent()
    ]))
    return star
  }
  
  func warpIn(to pos: CGPoint, atAngle angle: CGFloat, addTo playfield: Playfield) {
    position = pos
    zRotation = angle
    let body = coastingConfiguration()
    body.velocity = .zero
    let effect = self.warpEffect(shader: self.warpInShader)
    playfield.addWithScaling(effect)
    effect.run(SKAction.sequence([SKAction.wait(forDuration: self.warpTime), SKAction.removeFromParent()])) {
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
