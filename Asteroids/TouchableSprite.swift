//
//  TouchableSprite.swift
//  Asteroids
//
//  Created by David Long on 10/5/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// An `SKSpriteNode` that also responds to touches
class TouchableSprite: SKSpriteNode {
  /// The action to run upon touch
  var action: (() -> Void)? = nil

  /// Make the sprite react to touches
  override var isUserInteractionEnabled: Bool {
    get { return true }
    set {}
  }

  /// Handle touches for the sprite
  /// - Parameters:
  ///   - touches: Some touches
  ///   - event: An event that the touches belong to
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    action?()
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}
}
