//
//  BasicScene.swift
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
  case info = 100
}

extension SKNode {
  func setZ(_ z: LevelZs) {
    zPosition = z.rawValue
  }
}

enum ObjectCategories: UInt32 {
  case player = 1
  case playerShot = 2
  case asteroid = 4
  case ufo = 8
  case ufoShot = 16
  case fragment = 32
  case offScreen = 32768
  case hasWrapped = 65536
}

extension SKPhysicsBody {
  func isA(_ category: ObjectCategories) -> Bool {
    return (categoryBitMask & category.rawValue) != 0
  }

  func isOneOf(_ categories: UInt32) -> Bool {
    return (categoryBitMask & categories) != 0
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
  
  var hasWrapped: Bool {
    get { return categoryBitMask & ObjectCategories.hasWrapped.rawValue != 0 }
    set { if newValue {
      categoryBitMask |= ObjectCategories.hasWrapped.rawValue
    } else {
      categoryBitMask &= ~ObjectCategories.hasWrapped.rawValue
      }
    }
  }
}

func setOf(_ categories: [ObjectCategories]) -> UInt32 {
  return categories.reduce(0) { $0 | $1.rawValue }
}

extension SKNode {
  func wait(for time: Double, then action: SKAction) {
    run(SKAction.sequence([SKAction.wait(forDuration: time), action]))
  }

  func wait(for time: Double, then action: @escaping (() -> Void)) {
    wait(for: time, then: SKAction.run(action))
  }

  func requiredPhysicsBody() -> SKPhysicsBody {
    guard let body = physicsBody else { fatalError("Node \(name ?? "<unknown name>") is missing a physics body") }
    return body
  }
}

extension SKSpriteNode {
  func requiredTexture() -> SKTexture {
    guard let texture = texture else { fatalError("SpriteNode \(name ?? "<unknown name>") is missing a texture") }
    return texture
  }
}

extension Globals {
  static var lastUpdateTime = 0.0
  static var asteroidSplitEffectsCache = CyclicCache<Int, SKEmitterNode>(cacheId: "Asteroid split effects cache")
}

class BasicScene: SKScene, SKPhysicsContactDelegate {
  var fullFrame: CGRect!
  var gameFrame: CGRect!
  var gameAreaCrop = SKCropNode()
  var gameArea = SKEffectNode()
  var playfield: Playfield!
  var audio: SceneAudio!
  var asteroids = Set<SKSpriteNode>()
  var ufos = Set<UFO>()

  func tilingShader(forTexture texture: SKTexture) -> SKShader {
    // Do not to assume that the texture has v_tex_coord ranging in (0, 0) to (1, 1)!
    // If the texture is part of a texture atlas, this is not true.  Since we only
    // use this for a particular texture, we just pass in the texture and hard-code
    // the required v_tex_coord transformations.  For this case, the INPUT
    // v_tex_coord is from (0,0) to (1,1), since it corresponds to the coordinates in
    // the shape node that we're tiling.  The OUTPUT v_tex_coord has to be in the
    // space of the texture, so it needs a scale and shift.
    //
    // (Actually I moved the background texture out of the texture atlas because
    // there seemed to be some weirdness that gave a slight green tinge to a border
    // in the latest Xcode for an iOS 12 device.  Since we're tiling the whole
    // background anyway, having it not in the atlas won't affect the draw count.)
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
    let background = SKShapeNode(rect: gameFrame)
    background.name = "background"
    background.strokeColor = .clear
    background.blendMode = .replace
    background.setZ(.background)
    let stars = Globals.textureCache.findTexture(imageNamed: "starfield_blue")
    let tsize = stars.size()
    background.fillTexture = stars
    background.fillColor = .white
    background.fillShader = tilingShader(forTexture: stars)
    let reps = vector_float2([Float(gameFrame.width / tsize.width), Float(gameFrame.height / tsize.height)])
    background.setValue(SKAttributeValue(vectorFloat2: reps), forAttribute: "a_repetitions")
    gameArea.addChild(background)
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
    stars.setZ(.stars)
    gameArea.addChild(stars)
    let dim = CGFloat(0.1)
    let bright = CGFloat(0.3)
    let period = 8.0
    let twinkle = twinkleAction(period: period, from: dim, to: bright)
    for _ in 0..<100 {
      let star = makeStar()
      star.alpha = dim
      var minSep = CGFloat(0)
      let wantedSep = 3 * star.size.diagonal()
      while minSep < wantedSep {
        minSep = .infinity
        star.position = CGPoint(x: .random(in: gameFrame.minX...gameFrame.maxX),
                                y: .random(in: gameFrame.minY...gameFrame.maxY))
        for otherStar in stars.children {
          minSep = min(minSep, (otherStar.position - star.position).norm2())
        }
      }
      star.wait(for: .random(in: 0.0...period), then: twinkle)
      star.speed = .random(in: 0.75...1.5)
      stars.addChild(star)
    }
  }

  func initPlayfield() {
    playfield = Playfield(bounds: gameFrame)
    playfield.setZ(.playfield)
    gameArea.addChild(playfield)
  }

  func initGameArea(avoidSafeArea: Bool, maxAspectRatio: CGFloat = .infinity) {
    var width = size.width
    if avoidSafeArea {
      width -= Globals.safeAreaPaddingLeft
      width -= Globals.safeAreaPaddingRight
    }
    if width / size.height > maxAspectRatio {
      width = size.height * maxAspectRatio
    }
    gameFrame = CGRect(x: -0.5 * width, y: -0.5 * size.height, width: width, height: size.height)
    gameAreaCrop.name = "gameAreaCrop"
    if gameFrame.width == fullFrame.width {
      gameAreaCrop.maskNode = nil
    } else {
      let mask = SKShapeNode(rect: gameFrame)
      mask.fillColor = .white
      mask.strokeColor = .clear
      gameAreaCrop.maskNode = mask
    }
    addChild(gameAreaCrop)
    gameArea.name = "gameArea"
    if let filter = CIFilter(name: "CICrystallize") {
      filter.setValue(10, forKey: kCIInputRadiusKey)
      gameArea.filter = filter
      gameArea.shouldCenterFilter = true
    }
    gameArea.shouldEnableEffects = false
    gameAreaCrop.addChild(gameArea)
    initBackground()
    initStars()
    initPlayfield()
    audio = SceneAudio(stereoEffectsFrame: gameFrame, audioEngine: audioEngine)
  }

  func setGameAreaBlur(_ enable: Bool) {
    gameArea.shouldEnableEffects = enable && gameArea.filter != nil
  }

  func fireUFOLaser(angle: CGFloat, position: CGPoint, speed: CGFloat) {
    let laser = Globals.spriteCache.findSprite(imageNamed: "lasersmall_red") { sprite in
      let texture = sprite.requiredTexture()
      let ht = texture.size().height
      let body = SKPhysicsBody(circleOfRadius: 0.5 * ht,
                               center: CGPoint(x: 0.5 * (texture.size().width - ht), y: 0))
      body.allowsRotation = false
      body.linearDamping = 0
      body.categoryBitMask = ObjectCategories.ufoShot.rawValue
      body.collisionBitMask = 0
      body.contactTestBitMask = setOf([.asteroid, .player])
      sprite.physicsBody = body
    }
    laser.wait(for: Double(0.9 * gameFrame.height / speed)) { self.removeUFOLaser(laser) }
    playfield.addWithScaling(laser)
    laser.position = position
    laser.zRotation = angle
    laser.requiredPhysicsBody().velocity = CGVector(angle: angle).scale(by: speed)
    audio.soundEffect(.ufoShot, at: position)
  }
  
  func removeUFOLaser(_ laser: SKSpriteNode) {
    assert(laser.name == "lasersmall_red")
    Globals.spriteCache.recycleSprite(laser)
  }
  
  func makeAsteroid(position pos: CGPoint, size: String, velocity: CGVector, onScreen: Bool) {
    let typesForSize = ["small": 2, "med": 2, "big": 4, "huge": 3]
    guard let numTypes = typesForSize[size] else { fatalError("Incorrect asteroid size") }
    var type = Int.random(in: 1...numTypes)
    if Int.random(in: 1...4) != 1 {
      // Prefer the last type for each size (where we can use a circular physics
      // body), rest just for variety.
      type = numTypes
    }
    let name = "meteor\(size)\(type)"
    let asteroid = Globals.spriteCache.findSprite(imageNamed: name) { sprite in
      let texture = sprite.requiredTexture()
      // Huge and big asteroids of all types except the default have irregular shape,
      // so we use a pixel-perfect physics body for those.  Everything else gets a
      // circle.
      let body = (type == numTypes || size == "med" || size == "small" ?
        SKPhysicsBody(circleOfRadius: 0.5 * texture.size().width) :
        Globals.conformingPhysicsCache.makeBody(texture: texture))
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
    let body = asteroid.requiredPhysicsBody()
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
    let offset = CGPoint(x: .random(in: 0.75 * gameFrame.minX...0.75 * gameFrame.maxX),
                         y: .random(in: 0.75 * gameFrame.minY...0.75 * gameFrame.maxY))
    // Find a random distance that places us beyond the screen by a reasonable amount
    var dist = .random(in: 0.25...0.5) * gameFrame.height
    let minExclusion = max(1.25 * speed, 50)
    let maxExclusion = max(3.5 * speed, 200)
    let exclusion = -CGFloat.random(in: minExclusion...maxExclusion)
    while gameFrame.insetBy(dx: exclusion, dy: exclusion).contains(offset + dir.scale(by: dist)) {
      dist *= 1.1
    }
    makeAsteroid(position: offset + dir.scale(by: dist), size: size, velocity: velocity, onScreen: false)
  }

  func asteroidRemoved() {
    // Subclasses should override this to do additional work or checks when an
    // asteroid is removed.  E.g., GameScene would see if there are no more
    // asteroids, and if not, spawn a new wave.
  }

  func removeAsteroid(_ asteroid: SKSpriteNode) {
    Globals.spriteCache.recycleSprite(asteroid)
    asteroids.remove(asteroid)
    asteroidRemoved()
  }

  func clearPlayfield() {
    asteroids.forEach {
      $0.removeFromParent()
      Globals.spriteCache.recycleSprite($0)
    }
    asteroids.removeAll()
    ufos.removeAll()
  }

  func getAsteroidSplitEffect(size: Int) -> SKEmitterNode {
    let textureNames = ["meteormed1", "meteorbig1", "meteorhuge1"]
    let texture = Globals.textureCache.findTexture(imageNamed: textureNames[size - 1])
    let emitter = SKEmitterNode()
    emitter.particleTexture = Globals.textureCache.findTexture(imageNamed: "meteorsmall1")
    let effectDuration = CGFloat(0.25)
    emitter.particleLifetime = effectDuration
    emitter.particleLifetimeRange = 0.15 * effectDuration
    emitter.particleScale = 0.75
    emitter.particleScaleRange = 0.25
    emitter.numParticlesToEmit = 4 * size
    emitter.particleBirthRate = CGFloat(emitter.numParticlesToEmit) / (0.25 * effectDuration)
    let radius = 0.75 * texture.size().width
    emitter.particleSpeed = radius / effectDuration
    emitter.particleSpeedRange = 0.25 * emitter.particleSpeed
    emitter.particlePosition = .zero
    emitter.particlePositionRange = CGVector(dx: radius, dy: radius).scale(by: 0.25)
    emitter.emissionAngle = 0
    emitter.emissionAngleRange = 2 * .pi
    emitter.particleRotation = 0
    emitter.particleRotationRange = .pi
    emitter.particleRotationSpeed = 2 * .pi / effectDuration
    emitter.particleRenderOrder = .dontCare
    emitter.isPaused = true
    emitter.name = "asteroidSplitEmitter"
    return emitter
  }

  func preloadAsteroidSplitEffects() {
    for size in 1...3 {
      Globals.asteroidSplitEffectsCache.load(count: 10, forKey: size) { getAsteroidSplitEffect(size: size) }
    }
  }

  func makeAsteroidSplitEffect(_ asteroid: SKSpriteNode, ofSize size: Int) {
    let emitter = Globals.asteroidSplitEffectsCache.next(forKey: size)
    if emitter.parent != nil {
      emitter.removeFromParent()
    }
    emitter.removeAllActions()
    emitter.run(SKAction.sequence([SKAction.wait(forDuration: 0.5), SKAction.removeFromParent()]))
    emitter.position = asteroid.position
    emitter.isPaused = true
    emitter.resetSimulation()
    emitter.isPaused = false
    playfield.addWithScaling(emitter)
  }

  func splitAsteroid(_ asteroid: SKSpriteNode) {
    let sizes = ["small", "med", "big", "huge"]
    let hitEffect: [SoundEffect] = [.asteroidSmallHit, .asteroidMedHit, .asteroidBigHit, .asteroidHugeHit]
    guard let size = (sizes.firstIndex { asteroid.name!.contains($0) }) else {
      fatalError("Asteroid not of recognized size")
    }
    let velocity = asteroid.requiredPhysicsBody().velocity
    let pos = asteroid.position
    makeAsteroidSplitEffect(asteroid, ofSize: size)
    audio.soundEffect(hitEffect[size], at: pos)
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
  }

  func addExplosion(_ pieces: [SKNode]) {
    for p in pieces {
      playfield.addWithScaling(p)
    }
  }

  func warpOutUFO(_ ufo: UFO) {
    ufos.remove(ufo)
    audio.soundEffect(.ufoWarpOut, at: ufo.position)
    let effects = ufo.warpOut()
    playfield.addWithScaling(effects[0])
    playfield.addWithScaling(effects[1])
  }

  func warpOutUFOs(averageDelay: Double = 1) -> Double {
    // This is a little involved, but here's the idea.  The player has just died and
    // we've delayed a bit to let any of his existing shots hit stuff.  After the
    // shots are gone, any remaining UFOs will warp out before the player respawns or
    // we show GAME OVER.  We warp out the UFOs by having each run an action that
    // waits for a random delay before calling ufo.warpOut.  While the UFO is
    // delaying though, it might hit an asteroid and be destroyed, so the action has
    // a "warpOut" key through which we can cancel it.  This function returns the
    // maximum warpOut delay for all the UFOs; respawnOrGameOver will wait a bit
    // longer than that before triggering whatever it's going to do.
    //
    // One further caveat...
    //
    // When a UFO gets added by spawnUFO, it's initially way off the playfield, but
    // its audio will start so as to give the player a chance to prepare.  After a
    // second, an action will trigger to launch the UFO.  It gets moved to just off
    // the screen and its velocity is set so that it will move and become visible,
    // and as soon as isOnScreen becomes true, it will start flying normally.  For
    // warpOuts of these UFOs, everything will happen as you expect with the usual
    // animations.  However, for a UFO that has been spawned but not yet launched, we
    // still want warpOutUFOs to get rid of it.  These we'll just nuke immediately,
    // but be sure to call their cleanup method to give them a chance to do any
    // housekeeping that they may need.
    var maxDelay = 0.0
    ufos.forEach { ufo in
      if ufo.requiredPhysicsBody().isOnScreen {
        let delay = Double.random(in: 0.5 * averageDelay ... 1.5 * averageDelay)
        maxDelay = max(maxDelay, delay)
        ufo.run(SKAction.sequence([
          SKAction.wait(forDuration: delay),
          SKAction.run({ self.warpOutUFO(ufo) })
          ]), withKey: "warpOut")
      } else {
        logging("Cleanup on unlaunched ufo")
        ufo.cleanup()
        ufos.remove(ufo)
      }
    }
    return maxDelay
  }

  func spawnUFO(ufo: UFO) {
    playfield.addWithScaling(ufo)
    ufos.insert(ufo)
    // Position the UFO just off the screen on one side or another.  We set the side
    // here so that the positional audio will give a clue about where it's coming
    // from.  Actual choice of Y position and beginning of movement happens after a
    // delay.
    let ufoSize = 0.6 * ufo.size.diagonal()
    let x = (Bool.random() ? gameFrame.maxX + ufoSize : gameFrame.minX - ufoSize)
    // Audio depends only on left/right, i.e., x.
    ufo.position = CGPoint(x: x, y: 0)
    wait(for: 1) { self.launchUFO(ufo) }
  }
  
  func launchUFO(_ ufo: UFO) {
    let ufoRadius = 0.5 * ufo.size.diagonal()
    // Try to find a safe spawning position, but if we can't find one after some
    // number of tries, just go ahead and spawn anyway.
    var bestPosition: CGPoint? = nil
    var bestClearance = CGFloat.infinity
    for _ in 0..<10 {
      let pos = CGPoint(x: ufo.position.x, y: .random(in: 0.9 * gameFrame.minY ... 0.9 * gameFrame.maxY))
      var thisClearance = CGFloat.infinity
      for asteroid in asteroids {
        let bothRadii = ufoRadius + 0.5 * asteroid.size.diagonal()
        thisClearance = min(thisClearance, (asteroid.position - pos).norm2() - bothRadii)
        // Check the wrapped position too
        thisClearance = min(thisClearance, (asteroid.position - CGPoint(x: -pos.x, y: pos.y)).norm2() - bothRadii)
      }
      if bestPosition == nil || thisClearance > bestClearance {
        bestPosition = pos
        bestClearance = thisClearance
      }
      if bestClearance > 5 * ufoRadius {
        break
      }
    }
    ufo.position = bestPosition!
    let body = ufo.requiredPhysicsBody()
    body.isDynamic = true
    body.velocity = CGVector(dx: copysign(ufo.currentSpeed, -ufo.position.x), dy: 0)
  }
  
  func destroyUFO(_ ufo: UFO) {
    // If the player was destroyed earlier, the UFO will have been scheduled for
    // warpOut.  But if it just got destroyed (by hitting an asteroid) we have to be
    // sure to cancel the warp.
    ufo.removeAction(forKey: "warpOut")
    ufos.remove(ufo)
    audio.soundEffect(.ufoExplosion, at: ufo.position)
    addExplosion(ufo.explode())
  }

  func ufoLaserHit(laser: SKNode, asteroid: SKNode) {
    removeUFOLaser(laser as! SKSpriteNode)
    splitAsteroid(asteroid as! SKSpriteNode)
  }

  func ufoCollided(ufo: SKNode, asteroid: SKNode) {
    // I'm not sure if this check is needed anyway, but non-launched UFOs have
    // isDynamic set to false so that they're holding.  Make sure that the UFO has
    // been launched before we'll flag a collision.
    guard ufo.requiredPhysicsBody().isDynamic else { return }
    splitAsteroid(asteroid as! SKSpriteNode)
    destroyUFO(ufo as! UFO)
  }

  func ufosCollided(ufo1: SKNode, ufo2: SKNode) {
    // I'm not sure if these check is needed anyway, but non-launched UFOs have
    // isDynamic set to false so that they're holding.  Make sure that the UFO has
    // been launched before we'll flag a collision.
    guard ufo1.requiredPhysicsBody().isDynamic else { return }
    guard ufo2.requiredPhysicsBody().isDynamic else { return }
    destroyUFO(ufo1 as! UFO)
    destroyUFO(ufo2 as! UFO)
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

  func switchScene(to newScene: SKScene, withDuration duration: Double = 1) {
    logging("\(name!) switchScene to \(newScene.name!)")
    let transition = SKTransition.fade(with: AppColors.transitionColor, duration: duration)
    newScene.removeAllActions()
    logging("\(name!) about to call presentScene")
    view?.presentScene(newScene, transition: transition)
    logging("\(name!) finished presentScene")
  }

  // Subclasses should provide a didBegin method and set themselves as the
  // contactDelegate for physicsWorld.  E.g.
  //
  //  func didBegin(_ contact: SKPhysicsContact) {
  //    when(contact, isBetween: .ufoShot, and: .asteroid) { ufoLaserHit(laser: $0, asteroid: $1) }
  //    when(contact, isBetween: .ufo, and: .asteroid) { ufoCollided(ufo: $0, asteroid: $1) }
  //    ...
  //  }
  //
  // They should also provide an update method with their own frame logic, e.g.,
  //
  //  override func update(_ currentTime: TimeInterval) {
  //    super.update(currentTime)
  //    ufos.forEach {
  //      $0.fly(player: player, playfield: playfield) {
  //        (angle, position, speed) in self.fireUFOLaser(angle: angle, position: position, speed: speed)
  //      }
  //    }
  //    playfield.wrapCoordinates()
  //    ...
  //  }
  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    Globals.lastUpdateTime = currentTime
    logging("\(name!) update", "time \(currentTime)")
    _ = getUtimeOffset(view: view)
  }

  // The initializers should also be overridden by subclasses, but be sure to call
  // super.init()
  override init(size: CGSize) {
    super.init(size: size)
    fullFrame = CGRect(x: -0.5 * size.width, y: -0.5 * size.height, width: size.width, height: size.height)
    scaleMode = .aspectFill
    anchorPoint = CGPoint(x: 0.5, y: 0.5)
    physicsWorld.gravity = .zero
    preloadAsteroidSplitEffects()
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by BasicScene or its subclasses")
  }

  // Subclasses should override these too, typically to do something like starting a
  // new game or showing a menu.  When debugging, messages can go here.
  override func didMove(to view: SKView) {
    logging("Cache stats:")
    Globals.textureCache.stats()
    Globals.spriteCache.stats()
    Globals.explosionCache.stats()
    Globals.conformingPhysicsCache.stats()
    Globals.asteroidSplitEffectsCache.stats()
    Globals.sounds.stats()
    logging("\(name!) didMove to view")
  }

  override func willMove(from view: SKView) {
    logging("\(name!) willMove from view")
    removeAllActions()
    resetUtimeOffset()
  }

  func removeActionsForEverything(node: SKNode) {
    node.removeAllActions()
    for child in node.children {
      removeActionsForEverything(node: child)
    }
  }

  func cleanup() {
    // Call this from willMove(from:) when a scene will be destroyed.  We use this
    // for game scenes especially because it's hard to be sure we're in a consistent
    // state at the time of scene transition because of the possibility that the
    // player quit in the middle of the game.  At the time of the quit, the game is
    // paused, so all kinds of actions and things may be running, the playfield may
    // be full of sprites, etc.  We need to fix up everything so that the scene will
    // get garbage collected cleanly.  First we tell the playfield to recycle
    // sprites.  Then we cancel all actions so that any closures which may have
    // captured something that would lead to a retain cycle get nuked from orbit.
    playfield.recycle()
    removeActionsForEverything(node: self)
  }
}
