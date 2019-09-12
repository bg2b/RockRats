//
//  TextureCache.swift
//  Asteroids
//
//  Created by David Long on 7/11/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class TextureCache {
  var textures = [String: SKTexture]()

  func findTexture(imageNamed name: String) -> SKTexture {
    if let cached = textures[name] {
      return cached
    } else {
      let texture = SKTexture(imageNamed: name)
      textures[name] = texture
      return texture
    }
  }

  func stats() {
    print("Loaded \(textures.count) textures")
  }
}

extension Globals {
  static var textureCache = TextureCache()
}
