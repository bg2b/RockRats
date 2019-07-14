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

let teamColors = ["blue", "green", "red", "orange"]
let numColors = teamColors.count

extension SKNode {
  func wrapCoordinates() {
    guard let frame = self.scene?.frame else { return }
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

class Ship: SKNode {
  var flames = [SKSpriteNode]()

  func buildFlames(at exhaustPos: CGPoint) {
    var fire = (1...3).compactMap { Globals.textureCache.findTexture(imageNamed: "fire\($0)") }
    fire.append(fire[1])
    let fireSize = fire[0].size()
    var fireAnimation = SKAction.animate(with: fire, timePerFrame: 0.1, resize: false, restore: true)
    fireAnimation = SKAction.repeatForever(fireAnimation)
    for scale in [0.5, 1.0, 1.5, 2.0] {
      let sprite = SKSpriteNode(texture: fire[0], size: fireSize)
      sprite.anchorPoint = CGPoint(x: 1.0, y: 0.5)
      sprite.run(fireAnimation)
      sprite.scale(to: CGSize(width: CGFloat(scale) * fireSize.width, height: fireSize.height))
      sprite.zPosition = -1
      sprite.position = exhaustPos
      sprite.alpha = 0.0
      flames.append(sprite)
      addChild(sprite)
    }
  }

  required init(color: String) {
    super.init()
    self.name = "ship"
    let shipTexture = Globals.textureCache.findTexture(imageNamed: "ship_\(color)")
    let ship = SKSpriteNode(texture: shipTexture)
    ship.name = "shipImage"
    addChild(ship)
    buildFlames(at: CGPoint(x: -shipTexture.size().width / 2, y: 0.0))
    let body = SKPhysicsBody(texture: shipTexture, size: shipTexture.size())
    body.linearDamping = 0.05
    physicsBody = body
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Ship")
  }

  func flamesOff() {
    flames.forEach { $0.alpha = 0 }
  }

  func flamesOn(_ amount: CGFloat) {
    let flameIndex = Int(0.99 * amount * CGFloat(flames.count))
    flames[flameIndex].alpha = 1
  }

  // Sets the ship to the standard coasting configuration
  func coastingConfiguration() -> SKPhysicsBody {
    guard let body = physicsBody else { fatalError("Where did Ship's physicsBody go?") }
    body.linearDamping = 0.05
    body.angularVelocity = 0
    flamesOff()
    return body
  }

  func fly(stickPosition stick: CGVector) {
    let body = coastingConfiguration()
    guard stick != CGVector.zero else { return }
    let angle = stick.angle()
    if abs(angle) >= 3 * .pi / 4 {
      // Joystick is pointing backwards, put on the brakes
      body.linearDamping = max(min(-stick.dx, 0.7), 0.05)
    }
    if abs(angle) <= .pi / 4 {
      // Pointing forwards, thrusters active
      let thrustAmount = min(stick.dx, 0.7) / 0.7
      let thrust = CGVector(angle: zRotation).scale(by: 2 * thrustAmount)
      body.applyForce(thrust)
      flamesOn(thrustAmount)
    }
    if abs(abs(angle) - .pi / 2) <= .pi / 4 {
      // Left or right rotation, set an absolute angular speed
      body.angularVelocity = copysign(.pi * min(abs(stick.dy), 0.7), angle)
    }
  }
}

class GameScene: SKScene {
  var playfield: SKNode!
  var player: Ship!
  var info: SKLabelNode!
  var joystick: Joystick!

  func makeSprite(imageNamed name: String) -> SKSpriteNode {
    return Globals.spriteCache.findSprite(imageNamed: name)
  }

  func recycleSprite(_ sprite: SKSpriteNode) {
    Globals.spriteCache.recycleSprite(sprite)
  }

  func makeShip() -> Ship {
    let ship = Ship(color: teamColors[0])
    playfield.addChild(ship)
    return ship
  }

  func tilingShader() -> SKShader {
    let shaderSource = """
    void main() {
      v_tex_coord = fract(v_tex_coord * a_repetitions);
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
    let scale = CGFloat.random(in: 0.5...1.0)
    let texture = Globals.textureCache.findTexture(imageNamed: "star1")
    let star = SKSpriteNode(texture: texture, size: texture.size().scale(by: scale))
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
    let bright = CGFloat(0.2)
    let period = 8.0
    let twinkle = twinkleAction(period: period, from: dim, to: bright)
    for _ in 0..<50 {
      let star = makeStar()
      star.alpha = dim
      star.position = CGPoint(x: CGFloat.random(in: frame.minX...frame.maxX),
                              y: CGFloat.random(in: frame.minY...frame.maxY))
      let initialWait = SKAction.wait(forDuration: Double.random(in: 0.0...period))
      star.run(SKAction.sequence([initialWait, twinkle]))
      star.speed = CGFloat.random(in: 0.75...1.5)
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
    joystick = Joystick(size: controlSize, borderColor: .lightGray, fillColor: UIColor(white: 0.33, alpha: 0.33),
                        texture: Globals.textureCache.findTexture(imageNamed: "ship_blue"))
    joystick.position = CGPoint(x: frame.minX + offset, y: frame.minY + offset)
    joystick.zRotation = .pi / 2
    controls.addChild(joystick)
  }

  func initInfo() {
    info = SKLabelNode(text: nil)
    info.name = "info"
    info.zPosition = LevelZs.info.rawValue
    addChild(info)
    info.position = CGPoint(x: frame.midX, y: frame.maxY - 50.0)
  }

  override func didMove(to view: SKView) {
    initBackground()
    initStars()
    initPlayfield()
    initControls()
    initInfo()
    player = makeShip()
    player.position = CGPoint.zero
  }

  override func update(_ currentTime: TimeInterval) {
    player.fly(stickPosition: joystick.getDirection())
    playfield.children.forEach { $0.wrapCoordinates() }
  }
}
