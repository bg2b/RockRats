//
//  GameScene.swift
//  Asteroids
//
//  Created by David Long on 7/7/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

let teamColors = ["blue", "green", "red", "orange"]
let numColors = teamColors.count

extension SKNode {
  func wrapCoordinates() {
    guard let frame = self.parent?.frame else { return }
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

extension CGSize {
  func scale(by amount: CGFloat) -> CGSize {
    return CGSize(width: width * amount, height: height * amount)
  }

  func scale(to size: CGFloat) -> CGSize {
    if width > height {
      return scale(by: size / width)
    } else {
      return scale(by: size / height)
    }
  }
}

class GameScene: SKScene {
  var textureCache = TextureCache()
  var spriteCache: SpriteCache<SKSpriteNode>!
  var playfield: SKShapeNode!

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

  func RGB(_ red: Int, _ green: Int, _ blue: Int) -> UIColor {
    return UIColor(red: CGFloat(red)/255.0, green: CGFloat(green)/255.0, blue: CGFloat(blue)/255.0, alpha: 1.0)
  }

  func makeStar() -> SKNode {
    let starType = Int.random(in: 1...5)
    let tints = [RGB(202, 215, 255),
                 RGB(248, 247, 255),
                 RGB(255, 244, 234),
                 RGB(255, 210, 161),
                 RGB(255, 204, 111)]
    let tint = tints.randomElement()!
    let alpha = CGFloat.random(in: 0.5...1.0)
    if starType <= 3 {
      let scale = CGFloat.random(in: 0.5...1.0)
      let texture = textureCache.findTexture(imageNamed: "star\(starType)")
      let star = SKSpriteNode(texture: texture, size: texture.size().scale(by: scale))
      star.color = tint
      star.colorBlendFactor = 1.0
      star.alpha = alpha
      return star
    } else {
      let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.0...5.0))
      star.fillColor = tint
      star.strokeColor = .clear
      star.alpha = alpha
      return star
    }
  }

  func initStars() {
    let stars = SKNode()
    stars.zPosition = -1
    addChild(stars)
    var twinkleActions = [SKAction]()
    for _ in 0..<5 {
      let angle = CGFloat(2 * Int.random(in: 0...1) - 1) * CGFloat.pi
      let rot = SKAction.repeatForever(SKAction.rotate(byAngle: angle,
                                                       duration: Double.random(in: 2.0...8.0)))
      let duration = Double.random(in: 2.0...8.0)
      let brighten = SKAction.fadeAlpha(to: 1.0, duration: 0.5 * duration)
      let dim = SKAction.fadeAlpha(to: 0.5, duration: 0.5 * duration)
      let brightenAndDim = SKAction.repeatForever(SKAction.sequence([brighten, dim]))
      twinkleActions.append(SKAction.group([rot, brightenAndDim]))
    }
    for _ in 0..<100 {
      let star = makeStar()
      star.position = CGPoint(x: CGFloat.random(in: frame.minX...frame.maxX),
                              y: CGFloat.random(in: frame.minY...frame.maxY))
      star.run(twinkleActions.randomElement()!)
      stars.addChild(star)
    }
  }

  override func didMove(to view: SKView) {
    initStars()
    playfield = SKShapeNode(rect: frame)
    playfield.zPosition = 0
    playfield.blendMode = .replace
    playfield.fillColor = .clear
    playfield.strokeColor = .clear
    print(playfield.frame)
    addChild(playfield)
    let ship1 = makeShip()
    ship1["player"] = "player1"
    ship1.position = CGPoint(x: 500.0, y: -25.0)
    let ship = makeShip()
    ship["player"] = "player2"
    ship.position = CGPoint(x: 0.0, y: 0.0)
    ship1.physicsBody?.applyImpulse(CGVector(dx: -10.0, dy: 1.0))
    ship.physicsBody?.applyImpulse(CGVector(dx: 10.0, dy: -1.0))
    let joystick = Joystick(size: 100.0, fgColor: .lightGray, bgColor: .darkGray, texture: textureCache.findTexture(imageNamed: "ship_blue"))
    joystick.position = CGPoint(x: frame.minX + 100.0, y: frame.minY + 100.0)
    joystick.zPosition = 2.0
    addChild(joystick)
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
