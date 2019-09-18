//
//  Button.swift
//  Asteroids
//
//  Created by Daniel on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class Button: SKNode {
  let child: SKNode
  var enabled = true
  var action: (() -> Void)? = nil

  required init(withChild child: SKNode) {
    self.child = child
    super.init()
    name = "button"
    addChild(child)
    isUserInteractionEnabled = true
  }

  convenience init(circleOfSize size: CGFloat, borderColor: UIColor, fillColor: UIColor, texture: SKTexture?) {
    let buttonShape = SKNode()
    buttonShape.name = "buttonShape"
    let buttonBorder = SKShapeNode(circleOfRadius: 0.5 * size)
    buttonBorder.name = "buttonBorder"
    buttonBorder.fillColor = fillColor
    buttonBorder.strokeColor = borderColor
    buttonBorder.lineWidth = 0.05 * size
    buttonBorder.isAntialiased = true
    buttonShape.addChild(buttonBorder)
    if let texture = texture {
      let sprite = SKSpriteNode(texture: texture, size: texture.size().scale(to: 0.6 * size))
      sprite.name = "buttonTexture"
      sprite.zPosition = 1
      buttonShape.addChild(sprite)
    }
    self.init(withChild: buttonShape)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Button")
  }

  func enable() {
    enabled = true
    alpha = 1.0
  }

  func disable() {
    enabled = false
    alpha = 0.5
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let _ = touches.first else { return }
    if enabled {
      action?()
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchesEnded(touches, with: event)
  }
}
