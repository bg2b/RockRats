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
  let border: SKShapeNode
  var enabled = true
  var clicked = false
  var action: (() -> Void)? = nil

  required init(withChild child: SKNode, border: SKShapeNode) {
    self.child = child
    self.border = border
    super.init()
    name = "button"
    addChild(child)
    isUserInteractionEnabled = true
  }

  convenience init(forText text: String, size: CGSize, fontName: String) {
    let buttonShape = SKNode()
    buttonShape.name = "buttonShape"
    let buttonBorder = SKShapeNode(rectOf: size, cornerRadius: 0.1 * min(size.width, size.height  / 0.9))
    buttonBorder.name = "buttonBorder"
    buttonBorder.fillColor = .clear
    buttonBorder.strokeColor = AppColors.green
    buttonBorder.lineWidth = 2
    buttonBorder.glowWidth = 1
    buttonBorder.isAntialiased = true
    buttonShape.addChild(buttonBorder)
    let label = SKLabelNode(text: text)
    label.name = "buttonText"
    label.fontName = fontName
    label.fontSize = size.height
    label.fontColor = AppColors.textColor
    label.horizontalAlignmentMode = .center
    label.verticalAlignmentMode = .center
    buttonShape.addChild(label)
    self.init(withChild: buttonShape, border: buttonBorder)
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
    clicked = true
    border.glowWidth = 3
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let _ = touches.first else { return }
    if enabled && clicked {
      action?()
      border.glowWidth = 1
      clicked = false
    }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
  }
}
