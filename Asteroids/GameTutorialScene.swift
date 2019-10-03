//
//  GameTutorialScene.swift
//  Asteroids
//
//  Created by David Long on 9/24/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class GameTutorialScene: BasicScene {
  var player: Ship!
  var score = 0
  var livesDisplay: LivesDisplay!
  var energyBar: EnergyBar!
  var joystickLocation = CGPoint.zero
  var joystickDirection = CGVector.zero
  var joystickTouch: UITouch? = nil
  var fireOrWarpTouches = [UITouch: CGPoint]()

  func initControls() {
    isUserInteractionEnabled = true
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      let location = touch.location(in: self)
      if location.x > fullFrame.midX {
        fireOrWarpTouches[touch] = location
      } else if joystickTouch == nil {
        joystickLocation = location
        joystickTouch = touch
      }
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      guard touch == joystickTouch else { continue }
      let location = touch.location(in: self)
      let delta = (location - joystickLocation).rotate(by: -.pi / 2)
      let offset = delta.norm2()
      joystickDirection = delta.scale(by: min(offset / (Globals.ptsToGameUnits * 0.5 * 100), 1.0) / offset)
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      if touch == joystickTouch {
        joystickDirection = .zero
        joystickTouch = nil
      } else {
        guard let startLocation = fireOrWarpTouches.removeValue(forKey: touch) else { continue }
        let location = touch.location(in: self)
        if (location - startLocation).norm2() > Globals.ptsToGameUnits * 100 {
          hyperspaceJump()
        } else {
          fireLaser()
        }
      }
    }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchesEnded(touches, with: event)
  }

  func setPositionsOfInfoItems() {
    livesDisplay.position = CGPoint(x: gameFrame.minX + 20, y: gameFrame.maxY - 20)
    energyBar.position = CGPoint(x: gameFrame.maxX - 20, y: gameFrame.maxY - 20)
    logging("\(name!) positions display items")
    logging("livesDisplay at \(livesDisplay.position.x),\(livesDisplay.position.y)")
    logging("energyBar at \(energyBar.position.x),\(energyBar.position.y)")
  }

  override func setPositionsForSafeArea() {
    super.setPositionsForSafeArea()
    let midX = 0.5 * (safeAreaLeft - safeAreaRight)
    logging("\(name!) repositions gameArea to \(midX),0 for new safe area")
    gameArea.position = CGPoint(x: midX, y: 0)
    setPositionsOfInfoItems()
  }

  func initInfo() {
    let info = SKNode()
    info.name = "info"
    info.zPosition = LevelZs.info.rawValue
    gameArea.addChild(info)
    livesDisplay = LivesDisplay(extraColor: AppColors.textColor)
    info.addChild(livesDisplay)
    energyBar = EnergyBar(maxLength: 20)
    info.addChild(energyBar)
    setPositionsOfInfoItems()
  }

  func isSafe(point: CGPoint, pathStart: CGPoint, pathEnd: CGPoint, clearance: CGFloat) -> Bool {
    // Generate "image" points in wrapped positions and make sure that all clear
    // the segment.  This seems easier than trying to simulate the wrapping of the
    // segment.
    var dxs = [CGFloat(0)]
    if pathEnd.x < gameFrame.minX { dxs.append(-gameFrame.width) }
    if pathEnd.x > gameFrame.maxX { dxs.append(gameFrame.width) }
    var dys = [CGFloat(0)]
    if pathEnd.y < gameFrame.minY { dys.append(-gameFrame.height) }
    if pathEnd.y > gameFrame.maxY { dys.append(gameFrame.height) }
    for dx in dxs {
      for dy in dys {
        let p = CGPoint(x: point.x + dx, y: point.y + dy)
        if distanceBetween(point: p, segment: (pathStart, pathEnd)) < clearance {
          return false
        }
      }
    }
    return true
  }

  func isSafe(point: CGPoint, forDuration time: CGFloat) -> Bool {
    if time > 0 {
      for asteroid in asteroids {
        // Don't check safety for spawning asteroids!  They're off the screen, so the
        // image ship method we use for safety could wind up thinking that the center
        // of the screen isn't safe.
        guard asteroid.requiredPhysicsBody().isOnScreen else { continue }
        let asteroidRadius = 0.5 * asteroid.texture!.size().diagonal()
        let playerRadius = 0.5 * player.shipTexture.size().diagonal()
        let pathStart = asteroid.position
        let pathEnd = asteroid.position + asteroid.physicsBody!.velocity.scale(by: time)
        if !isSafe(point: point, pathStart: pathStart, pathEnd: pathEnd, clearance: asteroidRadius + playerRadius) {
          return false
        }
      }
    }
    return true
  }

  func fireLaser() {
    guard player.canShoot(), energyBar.useEnergy(3) else { return }
    let laser = Globals.spriteCache.findSprite(imageNamed: "lasersmall_green") { sprite in
      guard let texture = sprite.texture else { fatalError("Where is the laser texture?") }
      // Physics body is just a little circle at the front end of the laser, since
      // that's likely to be the first and only thing that will hit an object anyway.
      let ht = texture.size().height
      let body = SKPhysicsBody(circleOfRadius: 0.5 * ht,
                               center: CGPoint(x: 0.5 * (texture.size().width - ht), y: 0))
      body.allowsRotation = false
      body.linearDamping = 0
      body.categoryBitMask = ObjectCategories.playerShot.rawValue
      body.collisionBitMask = 0
      body.contactTestBitMask = setOf([.asteroid, .ufo])
      sprite.physicsBody = body
      sprite.zPosition = -1
    }
    laser.wait(for: 0.9) { self.laserExpired(laser) }
    playfield.addWithScaling(laser)
    player.shoot(laser: laser)
    Globals.sounds.soundEffect(.playerShot, at: player.position)
  }

  func removeLaser(_ laser: SKSpriteNode) {
    assert(laser.name == "lasersmall_green")
    laser.removeAllActions()
    recycleSprite(laser)
    player.laserDestroyed()
  }
  
  func laserExpired(_ laser: SKSpriteNode) {
    // Override this if special processing needs to happen when a laser gets
    // removed without hitting anything.
    removeLaser(laser)
  }

  func setFutureFilter(enabled: Bool) {
    shouldEnableEffects = enabled && (shader != nil)
  }

  func hyperspaceJump() {
    guard player.canJump(), energyBar.useEnergy(40) else { return }
    let backToTheFuture = (score % 100 == 79)
    let effects = player.warpOut()
    playfield.addWithScaling(effects[0])
    playfield.addWithScaling(effects[1])
    Globals.sounds.soundEffect(.warpOut)
    let jumpRegion = gameFrame.insetBy(dx: 0.05 * gameFrame.width, dy: 0.05 * gameFrame.height)
    let jumpPosition = CGPoint(x: .random(in: jumpRegion.minX...jumpRegion.maxX),
                               y: .random(in: jumpRegion.minY...jumpRegion.maxY))
    wait(for: 1) {
      if backToTheFuture {
        self.setFutureFilter(enabled: true)
        self.player.setAppearance(to: .retro)
        reportAchievement(achievement: .backToTheFuture)
      } else {
        self.player.setAppearance(to: .modern)
        self.setFutureFilter(enabled: false)
      }
      Globals.sounds.soundEffect(.warpIn, at: jumpPosition)
      self.player.warpIn(to: jumpPosition, atAngle: .random(in: 0 ... 2 * .pi), addTo: self.playfield)
    }
  }

  func replenishEnergy() {
    if player.parent != nil {
      energyBar.addToLevel(5)
    }
    wait(for: 0.5) { self.replenishEnergy() }
  }

  required init(size: CGSize) {
    super.init(size: size)
    name = "gameTutorialScene"
    initGameArea(limitAspectRatio: true)
    initInfo()
    initControls()
    physicsWorld.contactDelegate = self
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by GameTutorialScene")
  }
}
