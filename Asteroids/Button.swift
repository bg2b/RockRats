//
//  Button.swift
//  Asteroids
//
//  Created by Daniel on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// A basic clickable button
///
/// Shows something like an icon or some text with a frame around it.  When the user
/// touches within the frame, it shows an active state.  If the touch is released
/// while still inside the frame, the button's action triggers.
class Button: SKNode {
  let border: SKShapeNode
  var decoration: SKNode? = nil
  var confirmDecoration: SKNode? = nil
  var clickTouch: UITouch? = nil
  var action: (() -> Void)? = nil

  init(around node: SKNode, minSize: CGSize, borderColor: UIColor = AppColors.green) {
    // This one is for managing whatever is inside the button separately.  For
    // example during the tutorial we show some instructions using a type-in effect,
    // and that requires more label gymnastics than we deal with here.  Note that
    // node is not added as a child of the button by this method, and once you've
    // made the button, the border size is fixed.
    let nodeSize = node.frame.size
    // Padding is total amount for both sides, so 20 = 10 points on each
    let padding = CGFloat(20)
    let size = CGSize(width: max(nodeSize.width + padding, minSize.width), height: max(nodeSize.height + padding, minSize.height))
    let buttonBorder = SKShapeNode(rectOf: size, cornerRadius: 0.5 * padding)
    buttonBorder.name = "buttonBorder"
    buttonBorder.fillColor = .clear
    buttonBorder.strokeColor = borderColor
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

  convenience init(imageNamed imageName: String, imageColor: UIColor, size: CGSize) {
    let sprite = SKSpriteNode(imageNamed: imageName)
    sprite.name = "buttonSprite"
    sprite.color = imageColor
    sprite.colorBlendFactor = 1
    self.init(around: sprite, minSize: size)
    addChild(sprite)
    decoration = sprite
  }

  convenience init(forText text: String, fontSize: CGFloat, size: CGSize) {
    let label = SKLabelNode(text: text)
    label.name = "buttonText"
    label.fontName = AppColors.font
    label.fontSize = fontSize
    label.fontColor = AppColors.textColor
    label.horizontalAlignmentMode = .center
    label.verticalAlignmentMode = .center
    self.init(around: label, minSize: size)
    addChild(label)
    decoration = label
  }

  convenience init(forText text: String, confirmText: String, fontSize: CGFloat, size: CGSize) {
    self.init(forText: text, fontSize: fontSize, size: size)
    border.strokeColor = AppColors.red
    let confirmLabel = SKLabelNode(text: confirmText)
    confirmLabel.name = "buttonConfirmText"
    confirmLabel.fontName = AppColors.font
    confirmLabel.fontSize = fontSize
    confirmLabel.fontColor = AppColors.red
    confirmLabel.horizontalAlignmentMode = .center
    confirmLabel.verticalAlignmentMode = .center
    addChild(confirmLabel)
    confirmLabel.isHidden = true
    confirmDecoration = confirmLabel
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Button")
  }

  var enabled: Bool { isUserInteractionEnabled }

  func enable() {
    isUserInteractionEnabled = true
    alpha = 1
  }

  func disable() {
    isUserInteractionEnabled = false
    alpha = 0.5
  }

  func resetTouch() {
    clickTouch = nil
    border.glowWidth = 1
  }

  func cancelConfirmation() {
    decoration?.isHidden = false
    confirmDecoration?.isHidden = true
    removeAllActions()
    resetTouch()
  }

  func wasConfirmed() -> Bool {
    // No confirmDecoration => simple button, immediately confirmed
    guard let confirmDecoration = confirmDecoration else { return true }
    if confirmDecoration.isHidden {
      // The button requires confirmation but the confirm state hasn't been shown
      return false
    } else {
      // The action was confirmed, switch back to the regular state
      cancelConfirmation()
      return true
    }
  }

  func requireConfirmation() {
    // No confirmDecoration => no need for confirmation
    guard let confirmDecoration = confirmDecoration else { return }
    // Show the confirm prompt and set a timer to switch back after a bit if there's
    // no confirmation.
    decoration?.isHidden = true
    confirmDecoration.isHidden = false
    wait(for: 5) {
      self.cancelConfirmation()
    }
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
        if wasConfirmed() {
          action?()
        } else {
          requireConfirmation()
        }
      }
      resetTouch()
    }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      guard touch == clickTouch else { continue }
      resetTouch()
    }
  }
}
