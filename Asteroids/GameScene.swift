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
}

extension SKPhysicsBody {
  func isA(_ category: ObjectCategories) -> Bool {
    return categoryBitMask == category.rawValue
  }
}

func setOf(_ categories: [ObjectCategories]) -> UInt32 {
  return categories.reduce(0) { $0 | $1.rawValue }
}

let teamColors = ["blue", "green", "red", "orange"]
let numColors = teamColors.count

extension SKNode {
  func wrapCoordinates() {
    guard let frame = self.scene?.frame else { return }
    if frame.contains(position) {
      self["wasOnScreen"] = true
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
}

extension Globals {
  static var textureCache = TextureCache()
  static var spriteCache = SpriteCache()
}

class GameScene: SKScene, SKPhysicsContactDelegate {
  var playfield: SKNode!
  var player: Ship!
  var info: SKLabelNode!
  var joystick: Joystick!

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

  func RGB(_ red: Int, _ green: Int, _ blue: Int) -> UIColor {
    return UIColor(red: CGFloat(red)/255.0, green: CGFloat(green)/255.0, blue: CGFloat(blue)/255.0, alpha: 1.0)
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
      let initialWait = SKAction.wait(forDuration: .random(in: 0.0...period))
      star.run(SKAction.sequence([initialWait, twinkle]))
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
  }

  func initInfo() {
    info = SKLabelNode(text: nil)
    info.name = "info"
    info.zPosition = LevelZs.info.rawValue
    addChild(info)
    info.position = CGPoint(x: frame.midX, y: frame.maxY - 50.0)
  }

  func makeShip() -> Ship {
    let ship = Ship(color: teamColors[0], joystick: joystick)
    playfield.addChild(ship)
    return ship
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
      body.contactTestBitMask = ObjectCategories.asteroid.rawValue | ObjectCategories.ufo.rawValue
      sprite.physicsBody = body
      sprite.zPosition = -1
    }
    let travel = SKAction.wait(forDuration: 1.0)
    laser.run(travel) { self.removeLaser(laser) }
    playfield.addChild(laser)
    player.shoot(laser: laser)
  }
  
  func removeLaser(_ laser: SKSpriteNode) {
    laser.removeAllActions()
    recycleSprite(laser)
    player.laserDestroyed()
  }
  
  func removeAsteroid(_ asteroid: SKSpriteNode) {
    recycleSprite(asteroid)
  }
  
  func spawnAsteroid(position pos: CGPoint, size: Int) {
    let asteroid = Globals.spriteCache.findSprite(imageNamed: "meteorbig\(Int.random(in: 1...4))") { sprite in
      guard let texture = sprite.texture else { fatalError("Where is the asteroid texture?") }
      let body = SKPhysicsBody(texture: texture, size: texture.size())
      body.angularDamping = 0
      body.linearDamping = 0
      body.categoryBitMask = ObjectCategories.asteroid.rawValue
      body.collisionBitMask = 0
      body.contactTestBitMask = setOf([.player, .playerShot, .ufo, .ufoShot])
      sprite.physicsBody = body
      sprite.zPosition = -1
    }
    asteroid.position = pos
    let a = atan2(frame.midY - pos.y, frame.midX - pos.x) + .random(in: -0.5...0.5)
    asteroid.physicsBody?.velocity = CGVector(angle: a).scale(by: 50) // 50 to global var asteroidSpeed
    asteroid.physicsBody?.angularVelocity = .random(in: -.pi ... .pi)
    playfield.addChild(asteroid)
  }

  func makeExplosion(at position: CGPoint, color: UIColor) {
    guard let explosion = SKEmitterNode(fileNamed: "BlueExplosion.sks") else { fatalError("Could not load emitter node") }
    let maxParticleLifetime = explosion.particleLifetime + 0.5 * explosion.particleLifetimeRange
    let maxEmissionTime = CGFloat(explosion.numParticlesToEmit) / explosion.particleBirthRate
    let maxExplosionTime = Double(maxEmissionTime + maxParticleLifetime)
    let waitAndRemove = SKAction.sequence([
      SKAction.wait(forDuration: maxExplosionTime),
      SKAction.removeFromParent()])
    explosion.position = position
    explosion.zPosition = 1
    explosion.run(waitAndRemove)
    playfield.addChild(explosion)
  }
  
  func laserHitAsteroid(laser: SKNode, asteroid: SKNode) {
    removeLaser(laser as! SKSpriteNode)
    removeAsteroid(asteroid as! SKSpriteNode)
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
    when(contact, isBetween: .asteroid, and: .playerShot) { laserHitAsteroid(laser: $0, asteroid: $1) }
  }
  
  override func didMove(to view: SKView) {
    physicsWorld.contactDelegate = self
    initBackground()
    initStars()
    initPlayfield()
    initControls()
    initInfo()
    player = makeShip()
    player.reset()
    spawnAsteroid(position: CGPoint(x: -800, y: -500), size: 3)
  }

  override func update(_ currentTime: TimeInterval) {
    player.fly()
    playfield.children.forEach { $0.wrapCoordinates() }
  }
}
