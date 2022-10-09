//
//  Touchable.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import SpriteKit

/// A wrapper around a node that makes it respond to touches
class Touchable: SKNode {
  /// The action to perform upon touch
  let action: () -> Void

  /// Create a touch wrapper node
  /// - Parameters:
  ///   - child: The node to make respond to touches
  ///   - action: The action to perform upon touch
  init(_ child: SKNode, _ action: @escaping () -> Void) {
    self.action = action
    super.init()
    name = "touchable" + (child.name ?? "")
    addChild(child)
  }

  convenience init(_ child: SKNode, minSize: CGFloat, _ action: @escaping () -> Void) {
    self.init(child, action)
    let box = SKSpriteNode()
    box.size = CGSize(width: minSize, height: minSize)
    addChild(box)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Touchable")
  }

  /// Make the wrapper handle touches
  override var isUserInteractionEnabled: Bool {
    get { return true }
    set {}
  }

  /// Perform an action when touched
  /// - Parameters:
  ///   - touches: Some random touches
  ///   - event: The event the touches belong to
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    action()
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}
}
