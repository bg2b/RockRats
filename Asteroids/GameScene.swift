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

class GameScene: SKScene {
  var textureCache = TextureCache()
  var spriteCache: SpriteCache<SKSpriteNode>!
  var playfield: SKNode!

  func makeSprite(imageNamed name: String) -> SKSpriteNode {
    if spriteCache == nil {
      spriteCache = SpriteCache<SKSpriteNode>(textureCache: textureCache)
    }
    return spriteCache.findSprite(imageNamed: name)
  }

  func recycleSprite(_ sprite: SKSpriteNode) {
    spriteCache.recycleSprite(sprite)
  }

  func makeShip() -> SKSpriteNode {
    let ship = makeSprite(imageNamed: "ship_" + teamColors[0])
    ship.physicsBody?.linearDamping = 0.05
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
    let stars = textureCache.findTexture(imageNamed: "starfield_blue")
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
    let texture = textureCache.findTexture(imageNamed: "star1")
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
    let joystick = Joystick(size: controlSize, borderColor: .lightGray, fillColor: .darkGray,
                            texture: textureCache.findTexture(imageNamed: "ship_blue"))
    joystick.position = CGPoint(x: frame.minX + offset, y: frame.minY + offset)
    joystick.zRotation = CGFloat.pi / 2
    controls.addChild(joystick)
  }

  override func didMove(to view: SKView) {
    initBackground()
    initStars()
    initPlayfield()
    initControls()
    let ship1 = makeShip()
    ship1["player"] = "player1"
    ship1.position = CGPoint(x: 500.0, y: -25.0)
    let ship = makeShip()
    ship["player"] = "player2"
    ship.position = CGPoint(x: 0.0, y: 0.0)
    ship1.physicsBody?.applyImpulse(CGVector(dx: -10.0, dy: 1.0))
    ship.physicsBody?.applyImpulse(CGVector(dx: 10.0, dy: -1.0))
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
  }
    
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
  }
    
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
  }

  override func update(_ currentTime: TimeInterval) {
    playfield.children.forEach { $0.wrapCoordinates() }
  }
}
