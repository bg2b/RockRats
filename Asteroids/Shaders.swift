//
//  Shaders.swift
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

// MARK: SKAction helpers for shaders

extension SKAction {
  /// Construction an action to animate a shader's `a_time` attribute, then run an action
  ///
  /// The `a_time` attribute is used for animation in shaders that should run over
  /// some finite duration and then stop.  Originally I had a hack based on reading
  /// `u_time` in a shader and computing a `utimeOffset` that could be subtracted
  /// from `u_time` to get `a_time`.  That apparently worked but I was always nervous
  /// that it could be fragile.  So as soon as I discovered `customAction`, I dumped
  /// the scheme in favor of this.
  ///
  /// - Parameters:
  ///   - effectTime: The duration of the effect
  ///   - action: What to do after the effect finishes
  /// - Returns: The composite action
  static func setTime(effectTime: Double, then action: SKAction) -> SKAction {
    let setTimeAction = SKAction.customAction(withDuration: effectTime) { node, time in
      if let sprite = node as? SKSpriteNode {
        sprite.setValue(SKAttributeValue(float: Float(time)), forAttribute: "a_time")
      }
    }
    return .sequence([setTimeAction, action])
  }

  /// Construction an action to animate a shader's `a_time` attribute, then run a closure
  /// - Parameters:
  ///   - effectTime: The duration of the effect
  ///   - action: The closure to execute after completion
  /// - Returns: The composite action
  static func setTime(effectTime: Double, then action: @escaping () -> Void) -> SKAction {
    setTime(effectTime: effectTime, then: SKAction.run(action))
  }
}

// MARK: - Shader caches

/// A cache for various types of texture-dependent shaders
class ShaderCache {
  /// The function that makes the shader for a given texture
  let builder: (_ texture: SKTexture) -> SKShader
  /// A dictionary holding the constructed shaders
  var shaders = [SKTexture: SKShader]()

  /// Create a new shader cache
  /// - Parameter builder: A closure that constructs the shader for a given texture
  init(builder: @escaping (_ texture: SKTexture) -> SKShader) {
    self.builder = builder
  }

  /// Get the shader for a texture if it exists
  /// - Parameter texture: The texture
  /// - Returns: The shader if it exists, else `nil`
  func findShader(texture: SKTexture) -> SKShader? {
    return shaders[texture]
  }

  /// Get the shader corresponding to a texture
  /// - Parameter texture: The texture
  /// - Returns: The shader for effect specialized to the texture
  func getShader(texture: SKTexture) -> SKShader {
    if let result = shaders[texture] {
      return result
    }
    let result = builder(texture)
    shaders[texture] = result
    return result
  }
}
