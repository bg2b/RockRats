//
//  GameScene.swift
//  Asteroids
//
//  Created by David Long on 9/13/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class GameScene: BasicScene {
  var player: Ship!
  var score = 0
  var scoreDisplay: SKLabelNode!
  var lastJumpTime = 0.0
  var lastWarpInTime = 0.0
  var ufosToAvenge = 0
  var ufosKilledWithoutDying = 0
  var timesUFOsShot = 0
  var centralDisplay: SKLabelNode!
  var livesRemaining = 0
  var extraLivesAwarded = 0
  var livesDisplay: LivesDisplay!
  var gameOver = false
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
      joystickDirection = delta.scale(by: min(offset / (0.5 * 100), 1.0) / offset)
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
        if (location - startLocation).norm2() > 100 {
          if Globals.lastUpdateTime >= lastJumpTime + Globals.gameConfig.hyperspaceCooldown {
            hyperspaceJump()
          }
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
    scoreDisplay.position = CGPoint(x: gameFrame.midX, y: gameFrame.maxY - 50)
    centralDisplay.position = CGPoint(x: gameFrame.midX, y: gameFrame.midY)
    livesDisplay.position = CGPoint(x: gameFrame.minX + 20, y: gameFrame.maxY - 20)
    logging("\(name!) positions display items")
    logging("scoreDisplay at \(scoreDisplay.position.x),\(scoreDisplay.position.y)")
    logging("centralDisplay at \(centralDisplay.position.x),\(centralDisplay.position.y)")
    logging("livesDisplay at \(livesDisplay.position.x),\(livesDisplay.position.y)")
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
    scoreDisplay = SKLabelNode(fontNamed: "Kenney Future")
    scoreDisplay.fontSize = 50
    scoreDisplay.fontColor = textColor
    scoreDisplay.text = "0"
    scoreDisplay.name = "score"
    info.addChild(scoreDisplay)
    centralDisplay = SKLabelNode(fontNamed: "Kenney Future")
    centralDisplay.fontSize = 100
    centralDisplay.fontColor = highlightTextColor
    centralDisplay.text = ""
    centralDisplay.name = "centralDisplay"
    centralDisplay.isHidden = true
    centralDisplay.verticalAlignmentMode = .center
    info.addChild(centralDisplay)
    livesDisplay = LivesDisplay(extraColor: textColor)
    info.addChild(livesDisplay)
    setPositionsOfInfoItems()
  }

  func initFutureShader() {
    let shaderSource = """
    float grayscale(vec2 coord, texture2d<float> texture) {
      vec4 color = texture2D(texture, coord);
      return 0.2 * color.r + 0.7 * color.g + 0.1 * color.b;
    }
    float edge_detect(vec2 coord, vec2 delta, texture2d<float> texture) {
      return abs(grayscale(coord + delta, texture) - grayscale(coord - delta, texture));
    }
    void main() {
      vec2 radius = 0.35 / a_size;
      float dx = radius.x;
      float dy = radius.y;
      float const invr2 = 0.707;
      float vedge = edge_detect(v_tex_coord, vec2(dx, 0.0), u_texture);
      float hedge = edge_detect(v_tex_coord, vec2(0.0, dy), u_texture);
      float d1edge = edge_detect(v_tex_coord, invr2 * vec2(dx, dy), u_texture);
      float d2edge = edge_detect(v_tex_coord, invr2 * vec2(dx, -dy), u_texture);
      float gray = hedge + vedge + d1edge + d2edge;
      gray = max(gray - 0.05, 0.0);
      gray *= 5.0;
      gray = min(gray, 1.0);
      gl_FragColor = vec4(gray, gray, gray, 0.0);
    }
    """
    let shader = SKShader(source: shaderSource)
    shader.attributes = [SKAttribute(name: "a_size", type: .vectorFloat2)]
    let pixelSize = vector_float2(Float(fullFrame.width), Float(fullFrame.height))
    setValue(SKAttributeValue(vectorFloat2: pixelSize), forAttribute: "a_size")
    self.shader = shader
  }

  func spawnWave() {
    if Globals.gameConfig.waveNumber() == 11 {
      reportAchievement(achievement: .spinalTap)
    }
    let numAsteroids = Globals.gameConfig.numAsteroids()
    for _ in 1...numAsteroids {
      spawnAsteroid(size: "huge")
    }
    spawnUFOs()
  }

  func nextWave() {
    Globals.gameConfig.nextWave()
    ufosToAvenge = 0
    ufosKilledWithoutDying = 0
    displayMessage("WAVE \(Globals.gameConfig.waveNumber())", forTime: 1.5) {
      self.spawnWave()
    }
  }

  override func asteroidRemoved() {
    if asteroids.isEmpty && !gameOver {
      Globals.sounds.normalHeartbeatRate()
      stopSpawningUFOs()
      // If the player dies from colliding with the last asteroid, then we have to
      // wait long enough for any of the player's remaining lasers to possibly hit a
      // UFO and score enough points for an extra life.  That wait is currently 4
      // seconds (see destroyPlayer).  If no points have been scored within 4 seconds
      // and the player is out of lives, then this action can be cancelled by
      // respawnOrGameOver.
      run(SKAction.sequence([SKAction.wait(forDuration: 4.1), SKAction.run { self.nextWave() }]), withKey: "spawnWave")
    }
  }

  func addToScore(_ amount: Int) {
    score += amount
    let extraLivesEarned = score / Globals.gameConfig.extraLifeScore
    if extraLivesEarned > extraLivesAwarded {
      updateLives(+1)
      Globals.sounds.soundEffect(.extraLife)
      extraLivesAwarded += 1
    }
    scoreDisplay.text = "\(score)"
    if score == 404 {
      wait(for: 1.5) {
        if self.score == 404 {
          self.scoreDisplay.text = "\(self.score): Not Found"
          reportAchievement(achievement: .score404)
        }
      }
    }
  }

  func updateLives(_ amount: Int) {
    livesRemaining += amount
    livesDisplay.showLives(livesRemaining)
  }

  func displayMessage(_ message: String, forTime duration: Double, then action: (() -> Void)? = nil) {
    centralDisplay.text = message
    centralDisplay.setScale(0.0)
    centralDisplay.alpha = 1.0
    centralDisplay.isHidden = false
    let growAndFade = SKAction.sequence([
      SKAction.scale(to: 1.0, duration: 0.25),
      SKAction.wait(forDuration: duration),
      SKAction.fadeOut(withDuration: 0.5),
      SKAction.hide(),
      // This slight extra delay makes sure that the WAVE # is gone from the screen
      // before spawnWave is called.  Without this delay, in extreme cases (like 100
      // asteroids spawned) there would be a slight stutter with the ghost of the
      // message still displayed.
      SKAction.wait(forDuration: 0.25)
      ])
    if let action = action {
      centralDisplay.run(growAndFade, completion: action)
    } else {
      centralDisplay.run(growAndFade)
    }
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

  func enableHyperspaceJump() {
    lastJumpTime = -Globals.gameConfig.hyperspaceCooldown
  }

  func spawnPlayer(safeTime: CGFloat = Globals.gameConfig.safeTime) {
    var spawnPosition = CGPoint(x: gameFrame.midX, y: gameFrame.midY)
    var attemptsRemaining = 5
    while attemptsRemaining > 0 && !isSafe(point: spawnPosition, forDuration: safeTime) {
      let spawnRegion = gameFrame.insetBy(dx: 0.33 * gameFrame.width, dy: 0.33 * gameFrame.height)
      spawnPosition = CGPoint(x: .random(in: spawnRegion.minX...spawnRegion.maxX),
                              y: .random(in: spawnRegion.minY...spawnRegion.maxY))
      attemptsRemaining -= 1
    }
    if attemptsRemaining == 0 {
      // We didn't find a safe position so wait a bit and try again.  Be a little more
      // aggressive about what is considered safe.
      wait(for: 0.5) { self.spawnPlayer(safeTime: max(safeTime - 0.25, 0)) }
    } else {
      ufosToAvenge /= 2
      enableHyperspaceJump()
      Globals.sounds.soundEffect(.warpIn)
      player.reset()
      player.warpIn(to: spawnPosition, atAngle: player.zRotation, addTo: playfield)
      spawnUFOs()
      updateLives(-1)
    }
  }

  func fireLaser() {
    guard player.canShoot() else { return }
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
    laser.wait(for: 0.9) { self.removeLaser(laser) }
    playfield.addWithScaling(laser)
    player.shoot(laser: laser)
    Globals.sounds.soundEffect(.playerShot)
  }

  func removeLaser(_ laser: SKSpriteNode) {
    assert(laser.name == "lasersmall_green")
    laser.removeAllActions()
    recycleSprite(laser)
    player.laserDestroyed()
  }

  func setFutureFilter(enabled: Bool) {
    shouldEnableEffects = enabled && (shader != nil)
  }
  
  func hyperspaceJump() {
    guard player.canJump() else { return }
    let backToTheFuture = (score % 100 == 79)
    lastJumpTime = Globals.lastUpdateTime
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
      Globals.sounds.soundEffect(.warpIn)
      self.player.warpIn(to: jumpPosition, atAngle: .random(in: 0 ... 2 * .pi), addTo: self.playfield)
    }
  }

  func asteroidPoints(_ asteroid: SKNode) -> Int {
    guard let name = asteroid.name else { fatalError("Asteroid should have a name") }
    if name.contains("small") { return 20 }
    if name.contains("med") { return 10 }
    if name.contains("big") { return 5 }
    assert(name.contains("huge"), "Asteroids should be small, med, big, or huge")
    return 2
  }

  func ufoPoints(_ ufo: SKNode) -> Int {
    guard let ufo = ufo as? UFO else { fatalError("The ufo doesn't have the UFO nature") }
    return ufo.isBig ? 20 : 100
  }

  func laserHit(laser: SKNode, asteroid: SKNode) {
    if !asteroid.requiredPhysicsBody().isOnScreen {
      reportAchievement(achievement: .quickFingers)
    }
    addToScore(asteroidPoints(asteroid))
    removeLaser(laser as! SKSpriteNode)
    splitAsteroid(asteroid as! SKSpriteNode)
  }

  func laserHit(laser: SKNode, ufo: SKNode) {
    ufosToAvenge += 1
    ufosKilledWithoutDying += 1
    if ufosKilledWithoutDying == 12 {
      reportAchievement(achievement: .armedAndDangerous)
    }
    if !ufo.requiredPhysicsBody().isOnScreen {
      reportAchievement(achievement: .hanShotFirst)
    }
    addToScore(ufoPoints(ufo))
    removeLaser(laser as! SKSpriteNode)
    destroyUFO(ufo as! UFO)
    // This resets the time to the next UFO so that it doesn't show up immediately,
    // but it's also not so long as the usual full duration like when the player is
    // destroyed or a new wave starts.
    spawnUFOs(relativeDuration: 0.5)
  }

  func maybeSpawnUFO() {
    guard player.parent != nil else { return }
    guard ufos.count < Globals.gameConfig.value(for: \.maxUFOs) else { return }
    spawnUFO(ufo: UFO(brothersKilled: ufosToAvenge))
    if ufos.count == 2 {
      reportAchievement(achievement: .doubleTrouble)
    }
  }

  func spawnUFOs(relativeDuration: Double = 1) {
    stopSpawningUFOs()  // Remove any existing scheduled spawn
    let meanTimeToNextUFO = relativeDuration * Globals.gameConfig.value(for: \.meanUFOTime)
    let delay = Double.random(in: 0.75 * meanTimeToNextUFO ... 1.25 * meanTimeToNextUFO)
    run(SKAction.sequence([SKAction.wait(forDuration: delay),
                           SKAction.run { self.maybeSpawnUFO(); self.spawnUFOs() }]),
        withKey: "spawnUFOs")
  }

  func stopSpawningUFOs() {
    removeAction(forKey: "spawnUFOs")
  }

  func respawnOrGameOver() {
    let delay = warpOutUFOs() + 1
    if livesRemaining > 0 {
      wait(for: delay) { self.spawnPlayer() }
    } else {
      gameOver = true
      Globals.sounds.stopHeartbeat()
      self.removeAction(forKey: "spawnWave")
      wait(for: delay) {
        Globals.sounds.soundEffect(.gameOver)
        self.displayMessage("GAME OVER", forTime: 4)
        self.wait(for: 6) { self.switchScene(to: Globals.menuScene) }
      }
    }
  }

  func destroyPlayer() {
    if Globals.lastUpdateTime - lastWarpInTime <= 0.1 {
      reportAchievement(achievement: .rightPlaceWrongTime)
    }
    enableHyperspaceJump()
    ufosKilledWithoutDying = 0
    let pieces = player.explode()
    addExplosion(pieces)
    playfield.changeSpeed(to: 0.25)
    // Lasers live for a bit less than a second.  If the player fires and immediately
    // dies, then due to the slow-motion effect that can get stretched to a bit less
    // than 4 seconds.  If the player was going to hit anything to score some points
    // and gain a life, then it should have happened by the time respawnOrGameOver is
    // called.
    wait(for: 4) {
      self.playfield.changeSpeed(to: 1)
      self.respawnOrGameOver()
    }
    Globals.sounds.soundEffect(.playerExplosion)
    stopSpawningUFOs()
  }

  func ufoLaserHit(laser: SKNode, player: SKNode) {
    if timesUFOsShot == 1 {
      reportAchievement(achievement: .redShirt)
    }
    removeUFOLaser(laser as! SKSpriteNode)
    destroyPlayer()
  }

  func playerCollided(asteroid: SKNode) {
    addToScore(asteroidPoints(asteroid))
    splitAsteroid(asteroid as! SKSpriteNode)
    destroyPlayer()
  }

  func playerHitUFO(ufo: SKNode) {
    reportAchievement(achievement: .leeroyJenkins)
    addToScore(ufoPoints(ufo))
    destroyUFO(ufo as! UFO)
    destroyPlayer()
  }

  func didBegin(_ contact: SKPhysicsContact) {
    when(contact, isBetween: .playerShot, and: .asteroid) { laserHit(laser: $0, asteroid: $1) }
    when(contact, isBetween: .player, and: .asteroid) { playerCollided(asteroid: $1) }
    when(contact, isBetween: .playerShot, and: .ufo) { laserHit(laser: $0, ufo: $1) }
    when(contact, isBetween: .player, and: .ufo) { playerHitUFO(ufo: $1) }
    when(contact, isBetween: .ufoShot, and: .asteroid) { ufoLaserHit(laser: $0, asteroid: $1)}
    when(contact, isBetween: .ufo, and: .asteroid) { ufoCollided(ufo: $0, asteroid: $1) }
    when(contact, isBetween: .ufoShot, and: .player) { ufoLaserHit(laser: $0, player: $1)}
  }

  override func didMove(to view: SKView) {
    super.didMove(to: view)
    joystickTouch = nil
    fireOrWarpTouches.removeAll()
    removeAllAsteroids()
    initSounds()
    Globals.gameConfig = loadGameConfig(forMode: "normal")
    Globals.gameConfig.currentWaveNumber = 0
    score = 0
    addToScore(0)
    lastJumpTime = 0
    lastWarpInTime = 0
    timesUFOsShot = 0
    livesRemaining = Globals.gameConfig.initialLives
    extraLivesAwarded = 0
    updateLives(0)
    gameOver = false
    wait(for: 1) {
      Globals.sounds.startHearbeat()
      self.nextWave()
      self.wait(for: 3) { self.spawnPlayer() }
    }
    logging("\(name!) finished didMove to view")
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    if player.parent == nil {
      lastWarpInTime = currentTime
    }
    ufos.forEach {
      $0.fly(player: player, playfield: playfield) {
        (angle, position, speed) in self.fireUFOLaser(angle: angle, position: position, speed: speed)
        timesUFOsShot += 1
      }
    }
    player.fly()
    playfield.wrapCoordinates()
  }

  required init(size: CGSize) {
    super.init(size: size)
    name = "gameScene"
    initGameArea(limitAspectRatio: true)
    initInfo()
    initControls()
    initFutureShader()
    player = Ship(color: "blue", getJoystickDirection: { [unowned self] in return self.joystickDirection })
    physicsWorld.contactDelegate = self
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by GameScene")
  }
}
