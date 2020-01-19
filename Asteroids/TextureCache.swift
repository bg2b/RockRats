//
//  TextureCache.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import SpriteKit
import os.log

/// A cache of, yes, you guessed it, textures!
class TextureCache {
  /// A dictionary mapping texture names to loaded textures
  var textures = [String: SKTexture]()
  /// The number of textures returned from the cache
  var used = 0

  /// Get the texture for an image name
  /// - Parameter name: The image name
  /// - Returns: The texture
  func findTexture(imageNamed name: String) -> SKTexture {
    used += 1
    if let cached = textures[name] {
      // Already loaded, just reuse
      return cached
    } else {
      let texture = SKTexture(imageNamed: name)
      // Textures sometimes don't seem to be really loaded unless I force the issue
      // by calculating the size...
      _ = texture.size()
      // Save it for reuse
      textures[name] = texture
      return texture
    }
  }

  /// Print some random statistics
  func stats() {
    os_log("Texture cache loaded %d textures, used %d", log: .app, type: .debug, textures.count, used)
  }
}

extension Globals {
  /// A cache holding the common textures used in the app
  static let textureCache = TextureCache()
}
