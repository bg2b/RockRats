//
//  SpriteCache.swift
//  Asteroids
//
//  Created by David Long on 7/7/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// A cache for sprites that get created and destroyed a lot, e.g., asteroids of
/// various shapes and shots.  Sprites managed by this class must not be renamed,
/// since the name is used as a key to identify the type of sprite.
class SpriteCache {
  /// A dictionary mapping image names to a list of available sprites
  var sprites = [String: [SKSpriteNode]]()
  /// Number of sprites created
  var created = 0
  /// Number of sprites used
  var used = 0
  /// Number of sprites in the recycling bin waiting for reuse
  var recycled = 0

  /// Create a new sprite
  /// - Parameters:
  ///   - name: The image name for the sprite's texture
  ///   - initializer: An optional closure to initialize the new sprite
  func makeSprite(imageNamed name: String, initializer: ((SKSpriteNode) -> Void)?) -> SKSpriteNode {
    let sprite = SKSpriteNode(texture: Globals.textureCache.findTexture(imageNamed: name))
    sprite.name = name
    initializer?(sprite)
    created += 1
    return sprite
  }

  /// Find an existing unused sprite, or make a new one
  /// - Parameters:
  ///   - name: The image name for the sprite's texture
  ///   - initializer: An optional closure to initialize the sprite if it has to be created
  func findSprite(imageNamed name: String, initializer: ((SKSpriteNode) -> Void)? = nil) -> SKSpriteNode {
    used += 1
    if sprites[name] == nil {
      // First time asking for this particular type of sprite
      sprites[name] = [SKSpriteNode]()
    }
    if sprites[name]!.isEmpty {
      // The recycle bin is empty, make a new sprite
      return makeSprite(imageNamed: name, initializer: initializer)
    }
    recycled -= 1
    // Reuse an item from the bin
    return sprites[name]!.popLast()!
  }

  /// Recycle a sprite that's no longer needed so that it can be reused later
  /// - Parameter sprite: The sprite to recycle
  func recycleSprite(_ sprite: SKSpriteNode) {
    // Make sure the sprite is in a consistent state
    sprite.removeFromParent()
    sprite.removeAllActions()
    if let body = sprite.physicsBody {
      body.velocity = .zero
      body.angularVelocity = 0
    }
    sprite.position = .zero
    sprite.speed = 1
    sprite.isPaused = false
    // Add the sprite to the recycling bin
    sprites[sprite.name!]!.append(sprite)
    recycled += 1
  }

  /// Print some random statistics
  func stats() {
    logging("Sprite cache created \(created) unique sprites, used \(used); \(recycled) sprites are in the recycle bin")
  }
}

extension Globals {
  /// A cache for all the simple sprites in the game
  static let spriteCache = SpriteCache()
}
