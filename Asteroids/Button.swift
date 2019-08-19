//
//  Button.swift
//  Asteroids
//
//  Created by Daniel on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class Button: SKNode {
  let size: CGFloat
  let borderColor: UIColor
  let fillColor: UIColor
  var action: (() -> Void)?

  func createButton(decoration: SKNode?) {
    let button = SKShapeNode(circleOfRadius: 0.5 * size)
    button.name = "buttonShape"
    button.fillColor = fillColor
    button.strokeColor = borderColor
    button.lineWidth = 0.05 * size
    button.isAntialiased = true
    addChild(button)
    if let decoration = decoration {
      decoration.name = "buttonDecoration"
      decoration.xScale *= 0.6
      decoration.yScale *= 0.6
      decoration.zPosition = 1
      button.addChild(decoration)
    }
  }

  required init(size: CGFloat, borderColor: UIColor, fillColor: UIColor, decoration: SKNode?) {
    self.size = size
    self.borderColor = borderColor
    self.fillColor = fillColor
    self.action = nil
    super.init()
    self.isUserInteractionEnabled = true
    self.name = "button"
    createButton(decoration: decoration)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Button")
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let _ = touches.first else { return }
    action?()
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchesEnded(touches, with: event)
  }
}
