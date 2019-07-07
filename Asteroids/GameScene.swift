//
//  GameScene.swift
//  Asteroids
//
//  Created by David Long on 7/7/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

enum TeamColor: String {
  case blue = "blue"
  case green = "green"
  case orange = "orange"
  case red = "red"
}

extension SKSpriteNode {
  convenience init(physicsImageName: String) {
    self.init(imageNamed: physicsImageName)
    self.physicsBody = SKPhysicsBody(texture: self.texture!, size: self.texture!.size())
  }

  func wrapCoordinates() {
    guard let frame = self.parent?.frame else { return }
    if position.x < frame.minX {
      position.x += frame.width
    } else if position.x > frame.maxX {
      position.x -= frame.width
    }
    if position.y < frame.minY {
      position.y += frame.height
    } else if position.y > frame.maxY {
      position.y -= frame.height
    }
  }
}

class GameScene: SKScene {

  var spriteCache = SpriteCache()
  var sprites = [SKSpriteNode]()

  func makeSprite(imageNamed name: String) -> SKSpriteNode {
    let sprite = spriteCache.findSprite(imageNamed: name)
    addChild(sprite)
    sprites.append(sprite)
    return sprite
  }

  func recycleSprite(_ sprite: SKSpriteNode) {
    if let index = sprites.firstIndex(of: sprite) {
      sprites.remove(at: index)
    }
    spriteCache.recycleSprite(sprite)
  }

  func makeShip(color: TeamColor) -> SKSpriteNode {
    return makeSprite(imageNamed: "playerShip_" + color.rawValue)
  }

  override func didMove(to view: SKView) {
    let ship1 = makeShip(color: .blue)
    ship1.position = CGPoint(x: 500.0, y: -25.0)
    let ship = makeShip(color: .blue)
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
    for sprite in sprites {
      sprite.wrapCoordinates()
    }
  }
}
