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
      // It seems like the texture is not always really loaded for reasons that I don't
      // understand.  Evaluating the size seems to force it to do the loading for real.
      let _ = texture.size()
      textures[name] = texture
      return texture
    }
  }

  func stats() {
    print("Loaded \(textures.count) textures")
  }
}

extension Globals {
  static let textureCache = TextureCache()
}
