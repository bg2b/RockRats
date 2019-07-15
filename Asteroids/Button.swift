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

  func createButton(texture: SKTexture?) {
    let button = SKShapeNode(circleOfRadius: 0.5 * size)
    button.name = "buttonShape"
    button.fillColor = fillColor
    button.strokeColor = borderColor
    button.lineWidth = 0.05 * size
    button.isAntialiased = true
    addChild(button)
    if let texture = texture {
      let sprite = SKSpriteNode(texture: texture, size: texture.size().scale(to: 0.75 * size))
      sprite.name = "buttonTexture"
      sprite.zPosition = 1
      button.addChild(sprite)
    }
  }

  required init(size: CGFloat, borderColor: UIColor, fillColor: UIColor, texture: SKTexture?) {
    self.size = size
    self.borderColor = borderColor
    self.fillColor = fillColor
    super.init()
    self.isUserInteractionEnabled = true
    self.name = "button"
    createButton(texture: texture)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Button")
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let position = touch.location(in: self)
    print("Button touched at \(position)")
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchesEnded(touches, with: event)
  }
}
