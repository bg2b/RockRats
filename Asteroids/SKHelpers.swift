//
//  SKHelpers.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import SpriteKit

// MARK: - SKAction helpers

extension SKAction {
  /// Construct an action to wait for a given time, then run another action
  /// - Parameters:
  ///   - duration: Number of seconds to wait
  ///   - action: `SKAction` to run
  /// - Returns: The composite action
  static func wait(for duration: Double, then action: SKAction) -> SKAction {
    SKAction.sequence([SKAction.wait(forDuration: duration), action])
  }

  /// Construct an action to wait for a given time, then run a closure
  /// - Parameters:
  ///   - duration: Number of seconds to wait
  ///   - action: Closure to execute after that
  /// - Returns: The composite action
  static func wait(for duration: Double, then action: @escaping () -> Void) -> SKAction {
    wait(for: duration, then: SKAction.run(action))
  }
}

// MARK: - SKNode helpers

extension SKNode {
  /// Wait for a given time, then run an action
  /// - Parameters:
  ///   - duration: Number of seconds to wait
  ///   - action: `SKAction` to run
  func wait(for duration: Double, then action: SKAction) {
    run(.wait(for: duration, then: action))
  }

  /// Wait for a given time, then run a closure
  /// - Parameters:
  ///   - time: Number of seconds to wait
  ///   - action: Closure to execute after that
  func wait(for duration: Double, then action: @escaping () -> Void) {
    wait(for: duration, then: SKAction.run(action))
  }

  /// Get the physics body of a node that must have one
  /// - Returns: The physics body
  func requiredPhysicsBody() -> SKPhysicsBody {
    guard let body = physicsBody else { fatalError("Node \(name ?? "<unknown name>") is missing a physics body") }
    return body
  }
}

// MARK: - SKSpriteNode helpers

extension SKSpriteNode {
  /// Get the texture of a sprite node that must have one
  /// - Returns: The texture
  func requiredTexture() -> SKTexture {
    guard let texture else { fatalError("SpriteNode \(name ?? "<unknown name>") is missing a texture") }
    return texture
  }
}
