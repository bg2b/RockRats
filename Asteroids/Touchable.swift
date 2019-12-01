//
//  Touchable.swift
//  Asteroids
//
//  Created by David Long on 11/28/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// A wrapper around a node that makes it respond to touches
class Touchable: SKNode {
  let action: () -> Void

  init(_ child: SKNode, _ action: @escaping () -> Void) {
    self.action = action
    super.init()
    name = "touchable" + (child.name ?? "")
    addChild(child)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Touchable")
  }

  override var isUserInteractionEnabled: Bool {
    get { return true }
    set {}
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    action()
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}
}
