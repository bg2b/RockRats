//
//  GameScene.swift
//  Asteroids
//
//  Created by David Long on 7/7/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

enum LevelZs: CGFloat {
  case background = -200
  case stars = -100
  case playfield = 0
  case controls = 100
  case info = 200
}

enum ObjectCategories: UInt32 {
  case player = 1
  case playerShot = 2
  case asteroid = 4
  case ufo = 8
  case ufoShot = 16
  case shipFrag = 32
}

extension SKPhysicsBody {
  func isA(_ category: ObjectCategories) -> Bool {
    return (categoryBitMask & category.rawValue) != 0
  }
}

func setOf(_ categories: [ObjectCategories]) -> UInt32 {
  return categories.reduce(0) { $0 | $1.rawValue }
}

func RGB(_ red: Int, _ green: Int, _ blue: Int) -> UIColor {
  return UIColor(red: CGFloat(red)/255.0, green: CGFloat(green)/255.0, blue: CGFloat(blue)/255.0, alpha: 1.0)
}

let teamColors = ["blue", "green", "red", "orange"]
let numColors = teamColors.count

extension SKNode {
  func wrapCoordinates() {
    guard let frame = self.scene?.frame else { return }
    if frame.contains(position) {
      self["wasOnScreen"] = true
    }
    else if name! == "fragment" {
      removeFromParent()
    }
    guard let wasOnScreen: Bool = self["wasOnScreen"], wasOnScreen else { return }
    // We wrap only after going past the edge a little bit so that an object that's
    // moving just along the edge won't stutter back and forth.
    let hysteresis = CGFloat(3)
    if position.x < frame.minX - hysteresis {
      position.x += frame.width
    } else if position.x > frame.maxX + hysteresis {
      position.x -= frame.width
    }
    if position.y < frame.minY - hysteresis {
      position.y += frame.height
    } else if position.y > frame.maxY + hysteresis {
      position.y -= frame.height
    }
  }

  func wait(for time: Double, then action: SKAction) {
    run(SKAction.sequence([SKAction.wait(forDuration: time), action]))
  }

  func wait(for time: Double, then action: @escaping (() -> Void)) {
    wait(for: time, then: SKAction.run(action))
  }
}

extension Globals {
  static var textureCache = TextureCache()
  static var spriteCache = SpriteCache()
  static var lastUpdateTime = 0.0
  static var directControls = 0
}

class GameScene: SKScene, SKPhysicsContactDelegate {
  let textColor = RGB(101, 185, 240)
  let highlightTextColor = RGB(246, 205, 68)
  var playfield: SKNode!
  var player: Ship!
  var score = 0
  var scoreDisplay: SKLabelNode!
  var joystick: Joystick!
  var hyperspaceButton: Button!
  var lastJumpTime = 0.0
  var asteroids = Set<SKSpriteNode>()
  var waveNumber = 0
  var centralDisplay: SKLabelNode!
  var livesRemaining = 0
  var extraLivesAwarded = 0
  var livesDisplay: LivesDisplay!
  var sounds: Sounds!

  func makeSprite(imageNamed name: String, initializer: ((SKSpriteNode) -> Void)? = nil) -> SKSpriteNode {
    return Globals.spriteCache.findSprite(imageNamed: name, initializer: initializer)
  }

  func recycleSprite(_ sprite: SKSpriteNode) {
    Globals.spriteCache.recycleSprite(sprite)
  }

  func tilingShader() -> SKShader {
    let shaderSource = """
    void main() {
      vec2 scaled = v_tex_coord * a_repetitions;
      // rot is 0...3 and a repetion is rotated 90*rot degrees.  That
      // helps avoid any obvious patterning in this case.
      int rot = (int(scaled.x) + int(scaled.y)) & 0x3;
      v_tex_coord = fract(scaled);
      if (rot == 1) v_tex_coord = vec2(1.0 - v_tex_coord.y, v_tex_coord.x);
      else if (rot == 2) v_tex_coord = vec2(1.0) - v_tex_coord;
      else if (rot == 3) v_tex_coord = vec2(v_tex_coord.y, 1.0 - v_tex_coord.x);
      gl_FragColor = SKDefaultShading();
    }
    """
    let shader = SKShader(source: shaderSource)
    shader.attributes = [SKAttribute(name: "a_repetitions", type: .vectorFloat2)]
    return shader
  }

  func initBackground() {
    let background = SKShapeNode(rect: frame)
    background.name = "background"
    background.strokeColor = .clear
    background.blendMode = .replace
    background.zPosition = LevelZs.background.rawValue
    let stars = Globals.textureCache.findTexture(imageNamed: "starfield_blue")
    let tsize = stars.size()
    background.fillTexture = stars
    background.fillColor = .white
    background.fillShader = tilingShader()
    let reps = vector_float2([Float(frame.width / tsize.width), Float(frame.height / tsize.height)])
    background.setValue(SKAttributeValue(vectorFloat2: reps), forAttribute: "a_repetitions")
    addChild(background)
  }


  func twinkleAction(period: Double, from dim: CGFloat, to bright: CGFloat) -> SKAction {
    let twinkleDuration = 0.4
    let delay = SKAction.wait(forDuration: period - twinkleDuration)
    let brighten = SKAction.fadeAlpha(to: bright, duration: 0.5 * twinkleDuration)
    brighten.timingMode = .easeIn
    let fade = SKAction.fadeAlpha(to: dim, duration: 0.5 * twinkleDuration)
    fade.timingMode = .easeOut
    return SKAction.repeatForever(SKAction.sequence([brighten, fade, delay]))
  }

  func makeStar() -> SKSpriteNode {
    let tints = [RGB(202, 215, 255),
                 RGB(248, 247, 255),
                 RGB(255, 244, 234),
                 RGB(255, 210, 161),
                 RGB(255, 204, 111)]
    let tint = tints.randomElement()!
    let texture = Globals.textureCache.findTexture(imageNamed: "star1")
    let star = SKSpriteNode(texture: texture, size: texture.size().scale(by: .random(in: 0.5...1.0)))
    star.name = "star"
    star.color = tint
    star.colorBlendFactor = 1.0
    return star
  }

  func initStars() {
    let stars = SKNode()
    stars.name = "stars"
    stars.zPosition = LevelZs.stars.rawValue
    addChild(stars)
    let dim = CGFloat(0.1)
    let bright = CGFloat(0.3)
    let period = 8.0
    let twinkle = twinkleAction(period: period, from: dim, to: bright)
    for _ in 0..<100 {
      let star = makeStar()
      star.alpha = dim
      star.position = CGPoint(x: .random(in: frame.minX...frame.maxX),
                              y: .random(in: frame.minY...frame.maxY))
      star.wait(for: .random(in: 0.0...period), then: twinkle)
      star.speed = .random(in: 0.75...1.5)
      stars.addChild(star)
    }
  }

  func initPlayfield() {
    playfield = SKNode()
    playfield.name = "playfield"
    playfield.zPosition = LevelZs.playfield.rawValue
    addChild(playfield)
  }

  func initControls() {
    let controls = SKNode()
    controls.name = "controls"
    controls.zPosition = LevelZs.controls.rawValue
    addChild(controls)
    let controlSize = CGFloat(100)
    let offset = controlSize
    let controlFill: UIColor = UIColor(white: 0.33, alpha: 0.33)
    joystick = Joystick(size: controlSize, borderColor: .lightGray, fillColor: controlFill,
                        texture: Globals.textureCache.findTexture(imageNamed: "ship_blue"))
    joystick.position = CGPoint(x: frame.minX + offset, y: frame.minY + offset)
    joystick.zRotation = .pi / 2
    controls.addChild(joystick)
    let fireButton = Button(size: controlSize, borderColor: .lightGray, fillColor: controlFill,
                            texture: Globals.textureCache.findTexture(imageNamed: "laserbig_green"))
    fireButton.position = CGPoint(x: frame.maxX - offset, y: frame.minY + offset)
    fireButton.zRotation = .pi / 2
    fireButton.action = { self.fireLaser() }
    controls.addChild(fireButton)
    hyperspaceButton = Button(size: controlSize, borderColor: .lightGray, fillColor: controlFill,
                              texture: Globals.textureCache.findTexture(imageNamed: "warpedship_blue"))
    hyperspaceButton.position = CGPoint(x: frame.maxX - offset, y: frame.minY + 2.25 * offset)
    hyperspaceButton.zRotation = .pi / 2
    hyperspaceButton.action = { self.hyperspaceJump() }
    controls.addChild(hyperspaceButton)
    enableHyperspaceJump()
  }

  func initInfo() {
    let info = SKNode()
    info.name = "info"
    info.zPosition = LevelZs.info.rawValue
    addChild(info)
    scoreDisplay = SKLabelNode(fontNamed: "KenVector Future")
    scoreDisplay.fontSize = 50
    scoreDisplay.fontColor = textColor
    scoreDisplay.text = "0"
    scoreDisplay.name = "score"
    scoreDisplay.position = CGPoint(x: frame.midX, y: frame.maxY - 50)
    info.addChild(scoreDisplay)
    centralDisplay = SKLabelNode(fontNamed: "KenVector Future")
    centralDisplay.fontSize = 100
    centralDisplay.fontColor = highlightTextColor
    centralDisplay.text = ""
    centralDisplay.name = "centralDisplay"
    centralDisplay.isHidden = true
    centralDisplay.verticalAlignmentMode = .center
    centralDisplay.position = CGPoint(x: frame.midX, y: frame.midY)
    info.addChild(centralDisplay)
    livesDisplay = LivesDisplay(extraColor: textColor)
    livesDisplay.position = CGPoint(x: frame.minX + 20, y: frame.maxY - 20)
    info.addChild(livesDisplay)
  }

  func addToScore(_ amount: Int) {
    score += amount
    let extraLivesEarned = score / Globals.gameConfig.extraLifeScore
    if extraLivesEarned > extraLivesAwarded {
      updateLives(+1)
      sounds.soundEffect(.extraLife)
      extraLivesAwarded += 1
    }
    scoreDisplay.text = "\(score)"
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
      SKAction.hide()
      ])
    if let action = action {
      centralDisplay.run(growAndFade, completion: action)
    } else {
      centralDisplay.run(growAndFade)
    }
  }

  func initSounds() {
    sounds = Sounds(listener: player)
    addChild(sounds)
  }

  func isSafe(point: CGPoint, forDuration time: CGFloat) -> Bool {
    if time > 0 {
      for asteroid in asteroids {
        let asteroidRadius = 0.5 * asteroid.texture!.size().diagonal()
        let playerRadius = 0.5 * player.shipTexture.size().diagonal()
        let pathStart = asteroid.position
        let pathEnd = asteroid.position + asteroid.physicsBody!.velocity.scale(by: time)
        if distanceBetween(point: point, segment: (pathStart, pathEnd)) < asteroidRadius + playerRadius {
          return false
        }
      }
    }
    return true
  }

  func enableHyperspaceJump() {
    // Ensure that the button stays enabled
    lastJumpTime = -Globals.gameConfig.hyperspaceCooldown
    hyperspaceButton.enable()
  }

  func spawnPlayer(safeTime: CGFloat = Globals.gameConfig.safeTime) {
    var spawnPosition = CGPoint(x: frame.midX, y: frame.midY)
    var attemptsRemaining = 5
    while attemptsRemaining > 0 && !isSafe(point: spawnPosition, forDuration: safeTime) {
      let spawnRegion = frame.insetBy(dx: 0.33 * frame.width, dy: 0.33 * frame.height)
      spawnPosition = CGPoint(x: .random(in: spawnRegion.minX...spawnRegion.maxX),
                              y: .random(in: spawnRegion.minY...spawnRegion.maxY))
      attemptsRemaining -= 1
    }
    if attemptsRemaining == 0 {
      // We didn't find a safe position so wait a bit and try again.  Be a little more
      // aggressive about what is considered safe.
      wait(for: 0.5) { self.spawnPlayer(safeTime: max(safeTime - 0.25, 0)) }
    } else {
      enableHyperspaceJump()
      sounds.soundEffect(.warpIn)
      player.reset()
      player.warpIn(to: spawnPosition, atAngle: player.zRotation, addTo: playfield)
      updateLives(-1)
    }
  }

  func fireLaser() {
    guard player.canShoot() else { return }
    let laser = Globals.spriteCache.findSprite(imageNamed: "lasersmall_green") { sprite in
      guard let texture = sprite.texture else { fatalError("Where is the laser texture?") }
      let body = SKPhysicsBody(texture: texture, size: texture.size())
      body.allowsRotation = false
      body.linearDamping = 0
      body.categoryBitMask = ObjectCategories.playerShot.rawValue
      body.collisionBitMask = 0
      body.contactTestBitMask = setOf([.asteroid, .ufo])
      sprite.physicsBody = body
      sprite.zPosition = -1
    }
    laser.wait(for: Double(0.9 * frame.height / Globals.gameConfig.playerShotSpeed)) { self.removeLaser(laser) }
    playfield.addChild(laser)
    player.shoot(laser: laser)
    sounds.soundEffect(.playerShot)
  }
  
  func removeLaser(_ laser: SKSpriteNode) {
    laser.removeAllActions()
    recycleSprite(laser)
    player.laserDestroyed()
  }

  func hyperspaceJump() {
    guard player.canJump() else { return }
    lastJumpTime = Globals.lastUpdateTime
    playfield.addChild(player.warpOut())
    sounds.soundEffect(.warpOut)
    let jumpRegion = frame.insetBy(dx: 0.05 * frame.width, dy: 0.05 * frame.height)
    let jumpPosition = CGPoint(x: .random(in: jumpRegion.minX...jumpRegion.maxX),
                               y: .random(in: jumpRegion.minY...jumpRegion.maxY))
    wait(for: 1) {
      self.sounds.soundEffect(.warpIn)
      self.player.warpIn(to: jumpPosition, atAngle: .random(in: 0 ... 2 * .pi), addTo: self.playfield)
    }
  }
  
  func makeAsteroid(position pos: CGPoint, size: String, velocity: CGVector, onScreen: Bool) {
    let typesForSize = ["small": 2, "med": 2, "big": 4, "huge": 3]
    guard let numTypes = typesForSize[size] else { fatalError("Incorrect asteroid size") }
    var type = Int.random(in: 1...numTypes)
    if Int.random(in: 1...4) != 1 {
      // Prefer the last type for each size, rest just for variety
      type = numTypes
    }
    let name = "meteor\(size)\(type)"
    let asteroid = Globals.spriteCache.findSprite(imageNamed: name) { sprite in
      guard let texture = sprite.texture else { fatalError("Where is the asteroid texture?") }
      let body = SKPhysicsBody(texture: texture, size: texture.size())
      body.angularDamping = 0
      body.linearDamping = 0
      body.categoryBitMask = ObjectCategories.asteroid.rawValue
      body.collisionBitMask = 0
      body.contactTestBitMask = setOf([.player, .playerShot, .ufo, .ufoShot])
      sprite.physicsBody = body
    }
    asteroid.position = pos
    let minSpeed = Globals.gameConfig.asteroidMinSpeed
    let maxSpeed = Globals.gameConfig.asteroidMaxSpeed
    var finalVelocity = velocity
    let speed = velocity.norm2()
    if speed == 0 {
      finalVelocity = CGVector(angle: .random(in: 0 ... 2 * .pi)).scale(by: minSpeed)
    } else if speed < minSpeed {
      finalVelocity = velocity.scale(by: minSpeed / speed)
    } else if speed > maxSpeed {
      finalVelocity = velocity.scale(by: maxSpeed / speed)
    }
    asteroid.physicsBody?.velocity = finalVelocity
    asteroid["wasOnScreen"] = onScreen
    asteroid.physicsBody?.angularVelocity = .random(in: -.pi ... .pi)
    asteroids.insert(asteroid)
    playfield.addChild(asteroid)
  }

  func spawnAsteroid(size: String) {
    // Initial direction of the asteroid from the center of the screen
    let dir = CGVector(angle: .random(in: -.pi ... .pi))
    // Traveling towards the center at a random speed
    let velocity = dir.scale(by: -.random(in: 50...100))
    // Offset from the center by some random amount
    let offset = CGPoint(x: .random(in: 0.75 * frame.minX...0.75 * frame.maxX),
                         y: .random(in: 0.75 * frame.minY...0.75 * frame.maxY))
    // Find a random distance that places us beyond the screen by a reasonable amount
    var dist = .random(in: 0.25...0.5) * frame.height
    let exclusion = -CGFloat.random(in: 200...500)
    while frame.insetBy(dx: exclusion, dy: exclusion).contains(offset + dir.scale(by: dist)) {
      dist *= 1.5
    }
    makeAsteroid(position: offset + dir.scale(by: dist), size: size, velocity: velocity, onScreen: false)
  }

  func spawnWave() {
    let numAsteroids = Globals.gameConfig.numAsteroids(atWave: waveNumber)
    for _ in 1...numAsteroids {
      spawnAsteroid(size: "huge")
    }
  }

  func nextWave() {
    waveNumber += 1
    displayMessage("WAVE \(waveNumber)", forTime: 1.5) {
      self.spawnWave()
    }
  }

  func removeAsteroid(_ asteroid: SKSpriteNode) {
    recycleSprite(asteroid)
    asteroids.remove(asteroid)
    if asteroids.isEmpty {
      sounds.normalHeartbeatRate()
      wait(for: 4.0) { self.nextWave() }
    }
  }

  func addEmitter(_ emitter: SKEmitterNode) {
    emitter.name = "emitter"
    let maxParticleLifetime = emitter.particleLifetime + 0.5 * emitter.particleLifetimeRange
    let maxEmissionTime = CGFloat(emitter.numParticlesToEmit) / emitter.particleBirthRate
    let maxTotalTime = Double(maxEmissionTime + maxParticleLifetime)
    emitter.zPosition = 1
    emitter.wait(for: maxTotalTime, then: SKAction.removeFromParent())
    emitter.isPaused = false
    playfield.addChild(emitter)
  }

  func makeAsteroidSplitEffect(_ asteroid: SKSpriteNode, ofSize size: Int) {
    let emitter = SKEmitterNode()
    emitter.particleTexture = Globals.textureCache.findTexture(imageNamed: "meteorsmall1")
    let effectDuration = CGFloat(0.25)
    emitter.particleLifetime = effectDuration
    emitter.particleLifetimeRange = 0.15 * effectDuration
    emitter.particleScale = 0.75
    emitter.particleScaleRange = 0.25
    emitter.numParticlesToEmit = 4 * size
    emitter.particleBirthRate = CGFloat(emitter.numParticlesToEmit) / (0.25 * effectDuration)
    let radius = 0.75 * asteroid.texture!.size().width
    emitter.particleSpeed = radius / effectDuration
    emitter.particleSpeedRange = 0.25 * emitter.particleSpeed
    emitter.particlePosition = .zero
    emitter.particlePositionRange = CGVector(dx: radius, dy: radius).scale(by: 0.25)
    emitter.emissionAngle = 0
    emitter.emissionAngleRange = 2 * .pi
    emitter.particleRotation = 0
    emitter.particleRotationRange = .pi
    emitter.particleRotationSpeed = 2 * .pi / effectDuration
    emitter.position = asteroid.position
    addEmitter(emitter)
  }

  func splitAsteroid(_ asteroid: SKSpriteNode) {
    let sizes = ["small", "med", "big", "huge"]
    let pointValues = [20, 10, 5, 2]
    let hitEffect: [SoundEffect] = [.asteroidSmallHit, .asteroidMedHit, .asteroidBigHit, .asteroidHugeHit]
    guard let size = (sizes.firstIndex { asteroid.name!.contains($0) }) else {
      fatalError("Asteroid not of recognized size")
    }
    guard let velocity = asteroid.physicsBody?.velocity else { fatalError("Asteroid had no velocity") }
    let pos = asteroid.position
    makeAsteroidSplitEffect(asteroid, ofSize: size)
    sounds.soundEffect(hitEffect[size], at: pos)
    // Don't split med or small asteroids.  Size progression should go huge -> big -> med,
    // but we include small just for completeness in case we change our minds later.
    if size >= 2 {
      // Choose a random direction for the first child and project to get that child's velocity
      let velocity1Angle = CGVector(angle: velocity.angle() + .random(in: -0.4 * .pi...0.4 * .pi))
      // Throw in a random scaling just to keep it from being too uniform
      let velocity1 = velocity.project(unitVector: velocity1Angle).scale(by: .random(in: 0.75 ... 1.25))
      // The second child's velocity is chosen from momentum conservation
      let velocity2 = velocity.scale(by: 2) - velocity1
      // Add a bit of extra spice just to keep the player on their toes
      let oomph = Globals.gameConfig.value(for: \WaveConfig.asteroidSpeedBoost, atWave: waveNumber)
      makeAsteroid(position: pos, size: sizes[size - 1], velocity: velocity1.scale(by: oomph), onScreen: true)
      makeAsteroid(position: pos, size: sizes[size - 1], velocity: velocity2.scale(by: oomph), onScreen: true)
    }
    removeAsteroid(asteroid)
    addToScore(pointValues[size])
  }

  func laserHit(laser: SKNode, asteroid: SKNode) {
    removeLaser(laser as! SKSpriteNode)
    splitAsteroid(asteroid as! SKSpriteNode)
  }

  func destroyPlayer() {
    enableHyperspaceJump()
    let pieces = player.explode()
    for p in pieces {
      playfield.addChild(p)
    }
    sounds.soundEffect(.playerExplosion)
    if livesRemaining > 0 {
      wait(for: 5.0) { self.spawnPlayer() }
    } else {
      sounds.stopHeartbeat()
      self.removeAllActions()
      wait(for: 2.0) {
        self.sounds.soundEffect(.gameOver)
        self.displayMessage("GAME OVER", forTime: 4)
      }
    }
  }

  func playerCollided(asteroid: SKNode) {
    splitAsteroid(asteroid as! SKSpriteNode)
    destroyPlayer()
    //splitAsteroid(asteroid as! SKSpriteNode)
  }

  func when(_ contact: SKPhysicsContact,
            isBetween type1: ObjectCategories, and type2: ObjectCategories,
            action: (SKNode, SKNode) -> Void) {
    let b1 = contact.bodyA
    let b2 = contact.bodyB
    guard let node1 = contact.bodyA.node, node1.parent != nil else { return }
    guard let node2 = contact.bodyB.node, node2.parent != nil else { return }
    if b1.isA(type1) && b2.isA(type2) {
      action(node1, node2)
    } else if b2.isA(type1) && b1.isA(type2) {
      action(node2, node1)
    }
  }

  func didBegin(_ contact: SKPhysicsContact) {
    when(contact, isBetween: .playerShot, and: .asteroid) { laserHit(laser: $0, asteroid: $1) }
    when(contact, isBetween: .player, and: .asteroid) { playerCollided(asteroid: $1) }
  }
  
  override func didMove(to view: SKView) {
    name = "scene"
    physicsWorld.contactDelegate = self
    initBackground()
    initStars()
    initPlayfield()
    initControls()
    initInfo()
    initSounds()
    livesRemaining = Globals.gameConfig.initialLives
    extraLivesAwarded = 0
    updateLives(0)
    player = Ship(color: teamColors[0], sounds: sounds, joystick: joystick)
    sounds.heartbeat()
    nextWave()
    wait(for: 3.0) { self.spawnPlayer() }
  }

  override func update(_ currentTime: TimeInterval) {
    Globals.lastUpdateTime = currentTime
    if currentTime >= lastJumpTime + Globals.gameConfig.hyperspaceCooldown {
      hyperspaceButton.enable()
    } else {
      hyperspaceButton.disable()
    }
    player.fly()
    playfield.children.forEach { $0.wrapCoordinates() }
  }
}
