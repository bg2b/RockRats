//
//  SpriteCache.swift
//  Asteroids
//
//  Created by David Long on 7/7/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class SpriteCache {
  var sprites = [String: [SKSpriteNode]]()
  var created = 0
  var recycled = 0

  func makeSprite(imageNamed name: String, initializer: ((SKSpriteNode) -> Void)?) -> SKSpriteNode {
    let sprite = SKSpriteNode(texture: Globals.textureCache.findTexture(imageNamed: name))
    sprite.name = name
    initializer?(sprite)
    created += 1
    return sprite
  }

  func findSprite(imageNamed name: String, initializer: ((SKSpriteNode) -> Void)? = nil) -> SKSpriteNode {
    if sprites[name] == nil {
      sprites[name] = [SKSpriteNode]()
    }
    if sprites[name]!.isEmpty {
      return makeSprite(imageNamed: name, initializer: initializer)
    }
    recycled -= 1
    return sprites[name]!.popLast()!
  }

  func recycleSprite(_ sprite: SKSpriteNode) {
    if let _ = sprite.parent {
      sprite.removeFromParent()
    }
    if let body = sprite.physicsBody {
      body.velocity = .zero
      body.angularVelocity = 0
    }
    sprite.position = .zero
    sprites[sprite.name!]!.append(sprite)
    recycled += 1
  }

  func stats() {
    print("Created \(created) sprites; \(recycled) sprites are in the recycle bin")
  }
}

extension Globals {
  static let spriteCache = SpriteCache()
}
