//
//  Button.swift
//  Asteroids
//
//  Created by Daniel on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class Button: SKNode {
  let border: SKShapeNode
  var enabled = true
  var clickTouch: UITouch? = nil
  var action: (() -> Void)? = nil

  init(around node: SKNode, minSize: CGSize) {
    // This one is for managing the label separately.  For example during the
    // tutorial we show some instructions using a type-in effect, and that requires
    // more label gymnastics than we deal with here.  Note that the label is not a
    // child of the button.  If you're going to move the label, the border showing
    // the button doesn't move along with it.  And once you've made the button, the
    // border size is fixed.  If you want to change the text, you'll probably need to
    // throw the button away and make a new one.
    let nodeSize = node.frame.size
    // Padding is total amount for both sides, so 20 = 10 points on each
    let padding = CGFloat(20)
    let size = CGSize(width: max(nodeSize.width + padding, minSize.width), height: max(nodeSize.height + padding, minSize.height))
    let buttonBorder = SKShapeNode(rectOf: size, cornerRadius: 0.5 * padding)
    buttonBorder.name = "buttonBorder"
    buttonBorder.fillColor = .clear
    buttonBorder.strokeColor = AppColors.green
    buttonBorder.lineWidth = 2
    buttonBorder.glowWidth = 1
    buttonBorder.isAntialiased = true
    buttonBorder.position = .zero
    self.border = buttonBorder
    super.init()
    addChild(buttonBorder)
    name = "button"
    isUserInteractionEnabled = true
  }

  convenience init(forText text: String, size: CGSize, fontName: String) {
    // The size here means minWidth x fontSize.  The actual button will probably be a
    // bit taller because of padding, but maybe not depending on the font?
    let label = SKLabelNode(text: text)
    label.name = "buttonText"
    label.fontName = fontName
    label.fontSize = size.height
    label.fontColor = AppColors.textColor
    label.horizontalAlignmentMode = .center
    label.verticalAlignmentMode = .center
    self.init(around: label, minSize: size)
    addChild(label)
  }

  convenience init(imageNamed imageName: String, imageColor: UIColor, size: CGSize) {
    let sprite = SKSpriteNode(imageNamed: imageName)
    sprite.name = "buttonSprite"
    sprite.color = imageColor
    sprite.colorBlendFactor = 1
    self.init(around: sprite, minSize: size)
    addChild(sprite)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Button")
  }

  func enable() {
    enabled = true
  }

  func disable() {
    enabled = false
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard enabled else { return }
    for touch in touches {
      if clickTouch == nil {
        clickTouch = touch
        border.glowWidth = 3
      }
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      guard touch == clickTouch else { continue }
      if border.frame.contains(touch.location(in: self)) {
        border.glowWidth = 3
      } else {
        border.glowWidth = 1
      }
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      guard touch == clickTouch else { continue }
      if border.frame.contains(touch.location(in: self)), enabled {
        action?()
      }
      border.glowWidth = 1
      clickTouch = nil
    }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      guard touch == clickTouch else { continue }
      clickTouch = nil
      border.glowWidth = 1
    }
  }
}
