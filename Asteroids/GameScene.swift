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
  case fragment = 32
  case offScreen = 32768
}

extension SKPhysicsBody {
  func isA(_ category: ObjectCategories) -> Bool {
    return (categoryBitMask & category.rawValue) != 0
  }

  var isOnScreen: Bool {
    get { return categoryBitMask & ObjectCategories.offScreen.rawValue == 0 }
    set { if newValue {
      categoryBitMask &= ~ObjectCategories.offScreen.rawValue
      } else {
      categoryBitMask |= ObjectCategories.offScreen.rawValue
      }
    }
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
  var playfield: Playfield!
  var player: Ship!
  var score = 0
  var scoreDisplay: SKLabelNode!
  var joystick: Joystick!
  var hyperspaceButton: Button!
  var lastJumpTime = 0.0
  var asteroids = Set<SKSpriteNode>()
  var wantToSpawnUFO = false
  var ufos = Set<UFO>()
  var centralDisplay: SKLabelNode!
  var livesRemaining = 0
  var extraLivesAwarded = 0
  var livesDisplay: LivesDisplay!
  var sounds: Sounds!
  var gameOver = false

  func makeSprite(imageNamed name: String, initializer: ((SKSpriteNode) -> Void)? = nil) -> SKSpriteNode {
    return Globals.spriteCache.findSprite(imageNamed: name, initializer: initializer)
  }

  func recycleSprite(_ sprite: SKSpriteNode) {
    Globals.spriteCache.recycleSprite(sprite)
  }

  func tilingShader(forTexture texture: SKTexture) -> SKShader {
    // Do not to assume that the texture has v_tex_coord ranging in (0, 0) to (1, 1)!
    // If the texture is part of a texture atlas, this is not true.  Since we only
    // use this for a particular texture, we just pass in the texture and hard-code
    // the required v_tex_coord transformations.  For this case, the INPUT
    // v_tex_coord is from (0,0) to (1,1), since it corresponds to the coordinates in
    // the shape node that we're tiling.  The OUTPUT v_tex_coord has to be in the
    // space of the texture, so it needs a scale and shift.
    let rect = texture.textureRect()
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
      // Transform from (0,0)-(1,1)
      v_tex_coord *= vec2(\(rect.size.width), \(rect.size.height));
      v_tex_coord += vec2(\(rect.origin.x), \(rect.origin.y));
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
    background.fillShader = tilingShader(forTexture: stars)
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
    playfield = Playfield()
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
    fireButton.action = { [unowned self] in self.fireLaser() }
    controls.addChild(fireButton)
    hyperspaceButton = Button(size: controlSize, borderColor: .lightGray, fillColor: controlFill,
                              texture: Globals.textureCache.findTexture(imageNamed: "warpedship_blue"))
    hyperspaceButton.position = CGPoint(x: frame.maxX - offset, y: frame.minY + 2.25 * offset)
    hyperspaceButton.zRotation = .pi / 2
    hyperspaceButton.action = { [unowned self] in self.hyperspaceJump() }
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
      spawnUFOs()
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
    laser.wait(for: 0.9) { self.removeLaser(laser) }
    playfield.addWithScaling(laser)
    player.shoot(laser: laser)
    sounds.soundEffect(.playerShot)
  }
  
  func removeLaser(_ laser: SKSpriteNode) {
    assert(laser.name == "lasersmall_green")
    laser.removeAllActions()
    recycleSprite(laser)
    player.laserDestroyed()
  }
  
  func fireUFOLaser(angle: CGFloat, position: CGPoint, speed: CGFloat) {
    let laser = Globals.spriteCache.findSprite(imageNamed: "lasersmall_red") { sprite in
      guard let texture = sprite.texture else { fatalError("Where is the laser texture?") }
      let body = SKPhysicsBody(texture: texture, size: texture.size())
      body.allowsRotation = false
      body.linearDamping = 0
      body.categoryBitMask = ObjectCategories.ufoShot.rawValue
      body.collisionBitMask = 0
      body.contactTestBitMask = setOf([.asteroid, .player])
      sprite.physicsBody = body
      sprite.zPosition = -1
    }
    laser.wait(for: Double(0.9 * frame.height / speed)) { self.removeUFOLaser(laser) }
    playfield.addWithScaling(laser)
    laser.position = position
    laser.zRotation = angle
    guard let body = laser.physicsBody else { fatalError("Laser has no physics body") }
    body.velocity = CGVector(angle: angle).scale(by: speed)
    sounds.soundEffect(.playerShot, at: position)
  }
  
  func removeUFOLaser(_ laser: SKSpriteNode) {
    assert(laser.name == "lasersmall_red")
    laser.removeAllActions()
    recycleSprite(laser)
  }
  
  func hyperspaceJump() {
    guard player.canJump() else { return }
    lastJumpTime = Globals.lastUpdateTime
    let effects = player.warpOut()
    playfield.addWithScaling(effects[0])
    playfield.addWithScaling(effects[1])
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
      body.restitution = 0.9
      sprite.physicsBody = body
    }
    asteroid.position = pos
    let minSpeed = Globals.gameConfig.asteroidMinSpeed
    let maxSpeed = Globals.gameConfig.asteroidMaxSpeed
    var finalVelocity = velocity
    let speed = velocity.norm2()
    if speed == 0 {
      finalVelocity = CGVector(angle: .random(in: 0 ... 2 * .pi)).scale(by: .random(in: minSpeed...maxSpeed))
    } else if speed < minSpeed {
      finalVelocity = velocity.scale(by: minSpeed / speed)
    } else if speed > maxSpeed {
      finalVelocity = velocity.scale(by: maxSpeed / speed)
    }
    // Important: addChild must be done BEFORE setting the velocity.  If it's after,
    // then the addChild mucks with the velocity a little bit, which is totally
    // bizarre and also can totally screw us up.  If the asteroid is being spawned,
    // we've calculated the initial position and velocity so that it will get onto
    // the screen, but if the velocity gets tweaked, then that guarantee is out the
    // window.
    playfield.addWithScaling(asteroid)
    guard let body = asteroid.physicsBody else { fatalError("An asteroid has lost its physicsBody") }
    body.velocity = finalVelocity
    body.isOnScreen = onScreen
    body.angularVelocity = .random(in: -.pi ... .pi)
    asteroids.insert(asteroid)
  }

  func spawnAsteroid(size: String) {
    // Initial direction of the asteroid from the center of the screen
    let dir = CGVector(angle: .random(in: -.pi ... .pi))
    // Traveling towards the center at a random speed
    let minSpeed = Globals.gameConfig.asteroidMinSpeed
    let maxSpeed = Globals.gameConfig.asteroidMaxSpeed
    let speed = CGFloat.random(in: minSpeed ... max(min(4 * minSpeed, 0.33 * maxSpeed), 0.25 * maxSpeed))
    let velocity = dir.scale(by: -speed)
    // Offset from the center by some random amount
    let offset = CGPoint(x: .random(in: 0.75 * frame.minX...0.75 * frame.maxX),
                         y: .random(in: 0.75 * frame.minY...0.75 * frame.maxY))
    // Find a random distance that places us beyond the screen by a reasonable amount
    var dist = .random(in: 0.25...0.5) * frame.height
    let minExclusion = max(1.25 * speed, 50)
    let maxExclusion = max(5 * speed, 200)
    let exclusion = -CGFloat.random(in: minExclusion...maxExclusion)
    while frame.insetBy(dx: exclusion, dy: exclusion).contains(offset + dir.scale(by: dist)) {
      dist *= 1.5
    }
    makeAsteroid(position: offset + dir.scale(by: dist), size: size, velocity: velocity, onScreen: false)
  }

  func spawnWave() {
    let numAsteroids = Globals.gameConfig.numAsteroids()
    for _ in 1...numAsteroids {
      spawnAsteroid(size: "huge")
    }
    spawnUFOs()
  }

  func nextWave() {
    Globals.gameConfig.waveNumber += 1
    displayMessage("WAVE \(Globals.gameConfig.waveNumber)", forTime: 1.5) {
      self.spawnWave()
    }
  }

  func removeAsteroid(_ asteroid: SKSpriteNode) {
    recycleSprite(asteroid)
    asteroids.remove(asteroid)
    if asteroids.isEmpty && !gameOver {
      sounds.normalHeartbeatRate()
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

  func addEmitter(_ emitter: SKEmitterNode) {
    emitter.name = "emitter"
    let maxParticleLifetime = emitter.particleLifetime + 0.5 * emitter.particleLifetimeRange
    let maxEmissionTime = CGFloat(emitter.numParticlesToEmit) / emitter.particleBirthRate
    let maxTotalTime = Double(maxEmissionTime + maxParticleLifetime)
    emitter.zPosition = 1
    emitter.wait(for: maxTotalTime, then: SKAction.removeFromParent())
    emitter.isPaused = false
    playfield.addWithScaling(emitter)
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

  func splitAsteroid(_ asteroid: SKSpriteNode, updateScore: Bool = true) {
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
      let oomph = Globals.gameConfig.value(for: \.asteroidSpeedBoost)
      makeAsteroid(position: pos, size: sizes[size - 1], velocity: velocity1.scale(by: oomph), onScreen: true)
      makeAsteroid(position: pos, size: sizes[size - 1], velocity: velocity2.scale(by: oomph), onScreen: true)
    }
    removeAsteroid(asteroid)
    if updateScore {
      addToScore(pointValues[size])
    }
  }

  func laserHit(laser: SKNode, asteroid: SKNode) {
    removeLaser(laser as! SKSpriteNode)
    splitAsteroid(asteroid as! SKSpriteNode)
  }
  
  func laserHit(laser: SKNode, ufo: SKNode) {
    removeLaser(laser as! SKSpriteNode)
    destroyUFO(ufo as! UFO)
  }

  func ufoLaserHit(laser: SKNode, asteroid: SKNode) {
    removeUFOLaser(laser as! SKSpriteNode)
    splitAsteroid(asteroid as! SKSpriteNode, updateScore: false)
  }

  func ufoLaserHit(laser: SKNode, player: SKNode) {
    removeUFOLaser(laser as! SKSpriteNode)
    destroyPlayer()
  }

  func addExplosion(_ pieces: [SKNode]) {
    for p in pieces {
      playfield.addWithScaling(p)
    }
  }
  
  func respawnOrGameOver() {
    if livesRemaining > 0 {
      wait(for: 1) { self.spawnPlayer() }
    } else {
      gameOver = true
      sounds.stopHeartbeat()
      self.removeAction(forKey: "spawnWave")
      wait(for: 2) {
        self.sounds.soundEffect(.gameOver)
        self.displayMessage("GAME OVER", forTime: 4)
      }
    }
  }
  
  func destroyPlayer() {
    enableHyperspaceJump()
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
    sounds.soundEffect(.playerExplosion)
    stopSpawningUFOs()
  }
  
  func spawnUFO() {
    guard player.parent != nil && ufos.count < Globals.gameConfig.value(for: \.maxUFOs) else { return }
    let ufo = UFO(sounds: sounds)
    positionUFO(ufo: ufo)
    playfield.addWithScaling(ufo)
    ufos.insert(ufo)
  }
  
  func positionUFO(ufo: UFO) {
    let x = (.random(in: 0...1) == 1 ? frame.maxX : frame.minX) * 1.5
    ufo.position = CGPoint(x: x, y: .random(in: frame.minY ... frame.maxY))
    ufo.physicsBody?.velocity = CGVector(dx: (x > 0 ? -1 : 1) * 100, dy: 0)
    ufo.physicsBody?.isOnScreen = false
  }
  
  func destroyUFO(_ ufo: UFO, updateScore: Bool = true) {
    if updateScore {
      addToScore(ufo.isBig ? 20 : 100)
    }
    ufos.remove(ufo)
    sounds.soundEffect(.ufoExplosion, at: ufo.position)
    addExplosion(ufo.explode())
  }

  func spawnUFOs() {
    stopSpawningUFOs()  // Remove any existing scheduled spawn
    let meanTimeToNextUFO = Globals.gameConfig.value(for: \.meanUFOTime)
    let delay = Double.random(in: 0.75 * meanTimeToNextUFO ... 1.25 * meanTimeToNextUFO)
    run(SKAction.sequence([SKAction.wait(forDuration: delay),
                           SKAction.run { self.spawnUFO(); self.spawnUFOs() }]),
        withKey: "spawnUFOs")
  }

  func stopSpawningUFOs() {
    removeAction(forKey: "spawnUFOs")
  }

  func playerCollided(asteroid: SKNode) {
    splitAsteroid(asteroid as! SKSpriteNode)
    destroyPlayer()
  }
  
  func playerHitUFO(ufo: SKNode) {
    destroyUFO(ufo as! UFO)
    destroyPlayer()
  }
  
  func ufoCollided(ufo: SKNode, asteroid: SKNode) {
    splitAsteroid(asteroid as! SKSpriteNode, updateScore: false)
    destroyUFO(ufo as! UFO, updateScore: false)
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
    when(contact, isBetween: .playerShot, and: .ufo) { laserHit(laser: $0, ufo: $1) }
    when(contact, isBetween: .player, and: .ufo) { playerHitUFO(ufo: $1) }
    when(contact, isBetween: .ufoShot, and: .asteroid) { ufoLaserHit(laser: $0, asteroid: $1)}
    when(contact, isBetween: .ufo, and: .asteroid) { ufoCollided(ufo: $0, asteroid: $1) }
    when(contact, isBetween: .ufoShot, and: .player) { ufoLaserHit(laser: $0, player: $1)}
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
    Globals.gameConfig.waveNumber = 0
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
    ufos.forEach {
      $0.fly(player: player, playfield: playfield) {
        (angle, position, speed) in self.fireUFOLaser(angle: angle, position: position, speed: speed)
      }
    }
    player.fly()
    playfield.wrapCoordinates()
  }
}
