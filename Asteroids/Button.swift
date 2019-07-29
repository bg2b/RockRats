//
//  Button.swift
//  Asteroids
//
//  Created by Daniel on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

let buttonHeldTime = 0.1

class Button: SKNode {
  let size: CGFloat
  let borderColor: UIColor
  let fillColor: UIColor
  var touched = false
  var held = false
  var action: (() -> Void)?

  func createButton(texture: SKTexture?) {
    let button = SKShapeNode(circleOfRadius: 0.5 * size)
    button.name = "buttonShape"
    button.fillColor = fillColor
    button.strokeColor = borderColor
    button.lineWidth = 0.05 * size
    button.isAntialiased = true
    addChild(button)
    if let texture = texture {
      let sprite = SKSpriteNode(texture: texture, size: texture.size().scale(to: 0.6 * size))
      sprite.name = "buttonTexture"
      sprite.zPosition = 1
      button.addChild(sprite)
    }
  }

  required init(size: CGFloat, borderColor: UIColor, fillColor: UIColor, texture: SKTexture?) {
    self.size = size
    self.borderColor = borderColor
    self.fillColor = fillColor
    self.action = nil
    super.init()
    self.isUserInteractionEnabled = true
    self.name = "button"
    createButton(texture: texture)
  }

  func isActive() -> Bool { return touched }

  func isHeld() -> Bool { return held }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Button")
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let _ = touches.first else { return }
    touched = true
    wait(for: buttonHeldTime) { self.held = true }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    removeAllActions()
    if !held {
      action?()
    }
    touched = false
    held = false
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    removeAllActions()
    held = false
  }
}
