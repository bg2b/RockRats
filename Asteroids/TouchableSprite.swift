//
//  TouchableSprite.swift
//  Asteroids
//
//  Created by David Long on 10/5/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class TouchableSprite: SKSpriteNode {
  var action: (() -> Void)? = nil

  override var isUserInteractionEnabled: Bool {
    get { return true }
    set { }
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    action?()
  }
}
