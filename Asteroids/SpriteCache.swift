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

  func makeSprite(imageNamed name: String) -> SKSpriteNode {
    let sprite = SKSpriteNode(texture: Globals.textureCache.findTexture(imageNamed: name))
    sprite.physicsBody = SKPhysicsBody(texture: sprite.texture!, size: sprite.texture!.size())
    sprite.name = name
    created += 1
    return sprite
  }

  func findSprite(imageNamed name: String) -> SKSpriteNode {
    if sprites[name] == nil {
      sprites[name] = [SKSpriteNode]()
    }
    if sprites[name]!.isEmpty {
      return makeSprite(imageNamed: name)
    }
    recycled -= 1
    return sprites[name]!.popLast()!
  }

  func recycleSprite(_ sprite: SKSpriteNode) {
    if let _ = sprite.parent {
      sprite.removeFromParent()
    }
    sprites[sprite.name!]!.append(sprite)
    recycled += 1
  }

  func stats() {
    print("Created \(created) sprites; \(recycled) sprites are in the recycle bin")
  }
}
