//
//  Button.swift
//  Asteroids
//
//  Created by Daniel on 7/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// A clickable button
///
/// Shows something like an icon or some text with a frame around it.  When the user
/// touches within the frame, it shows an active state.  If the touch is released
/// while still inside the frame, the button's action triggers.
///
/// When the decorations array has more than one element, the button cycles to the
/// next one on click.  This is useful for toggles or cyclic selections.
///
/// The class also supports requiring a second confirmation touch within a few
/// seconds (when confirmDecoration is non-nil).
class Button: SKNode {
  /// The border of the button, highlighted during touch processing
  let border: SKShapeNode
  /// The labels or pictures sit inside the button; the button cycles through these
  /// upon activation
  var decorations = [SKNode]()
  /// The index of the current button decoration
  var currentDecoration = 0
  /// If this is non-`nil`, the button requires a second confirmation press;
  /// `confirmDecoration` is shown during that process.
  var confirmDecoration: SKNode? = nil
  /// The touch that the button is currently processing
  var clickTouch: UITouch? = nil
  /// A closure that will be called when the button activates
  var action: (() -> Void)? = nil

  /// Make a button whose decorations are managed separately.
  /// - Parameters:
  ///   - node: A node whose frame should be enclosed by the button
  ///   - minSize: The minimum size of the button
  ///   - borderColor: Color of the button's outline (optional, default green)
  init(around node: SKNode, minSize: CGSize, borderColor: UIColor = AppAppearance.borderColor) {
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

  /// Make a button displaying a series of images and cycling when clicked.
  /// - Parameters:
  ///   - imageNames: An array with names of the different images
  ///   - imageColor: The tint color for the images
  ///   - size: The desired (minimum) size of the button
  convenience init(imagesNamed imageNames: [String], imageColor: UIColor, size: CGSize) {
    let sprites: [SKNode] = imageNames.map {
      let sprite = SKSpriteNode(imageNamed: $0)
      sprite.name = "buttonSprite_\($0)"
      sprite.color = imageColor
      sprite.colorBlendFactor = 1
      sprite.isHidden = true
      return sprite
    }
    sprites[0].isHidden = false
    self.init(around: sprites[0], minSize: size)
    sprites.forEach { addChild($0) }
    decorations = sprites
  }

  /// Make a button displaying an image.
  /// - Parameters:
  ///   - imageName: The name of the image to be display
  ///   - imageColor: The tint color for the image
  ///   - size: The desired (minimum) size of the button
  convenience init(imageNamed imageName: String, imageColor: UIColor, size: CGSize) {
    self.init(imagesNamed: [imageName], imageColor: imageColor, size: size)
  }

  /// Make a button displaying some text.
  /// - Parameters:
  ///   - text: The text shown in the button
  ///   - fontSize: The font size (font is the app's standard font)
  ///   - size: The desired (minimum) size of the button
  convenience init(forText text: String, fontSize: CGFloat, size: CGSize) {
    let label = SKLabelNode(text: text)
    label.name = "buttonText"
    label.fontName = AppAppearance.font
    label.fontSize = fontSize
    label.fontColor = AppAppearance.textColor
    label.horizontalAlignmentMode = .center
    label.verticalAlignmentMode = .center
    self.init(around: label, minSize: size)
    addChild(label)
    decorations.append(label)
  }

  /// Make a button displaying text that requires confirmation.
  /// - Parameters:
  ///   - text: The text shown initially
  ///   - confirmText: The text shown to prompt for confirmation
  ///   - fontSize: The font size (font is the app's standard font)
  ///   - size: The desired (minimum) size of the button
  convenience init(forText text: String, confirmText: String, fontSize: CGFloat, size: CGSize) {
    self.init(forText: text, fontSize: fontSize, size: size)
    border.strokeColor = AppAppearance.dangerBorderColor
    let confirmLabel = SKLabelNode(text: confirmText)
    confirmLabel.name = "buttonConfirmText"
    confirmLabel.fontName = AppAppearance.font
    confirmLabel.fontSize = fontSize
    confirmLabel.fontColor = AppAppearance.dangerButtonColor
    confirmLabel.horizontalAlignmentMode = .center
    confirmLabel.verticalAlignmentMode = .center
    addChild(confirmLabel)
    confirmLabel.isHidden = true
    confirmDecoration = confirmLabel
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Button")
  }

  /// Used to read a cyclic button's state (the decoration index), or to set it.
  var selectedValue: Int {
    get { currentDecoration }
    set {
      decorations.forEach { $0.isHidden = true }
      decorations[newValue].isHidden = false
    }
  }

  /// `true` if the button is enabled
  var enabled: Bool { isUserInteractionEnabled }

  /// Enable the button
  func enable() {
    isUserInteractionEnabled = true
    alpha = 1
  }

  // Disable the button
  func disable() {
    isUserInteractionEnabled = false
    alpha = 0.5
  }

  /// Reset the button's touch processing
  func resetTouch() {
    clickTouch = nil
    border.glowWidth = 1
  }

  /// Switch a confirmation-required button from "Are you sure (Y/N)?" back to normal
  ///
  /// This is also used when coming back to a scene that existed already (as opposed
  /// to a newly-constructed scene).  If the scene has two buttons and both were
  /// touched (had `clickTouch` non-`nil`) and then one was released+activated, the
  /// other would still have `clickTouch` set on scene transition.  But because that
  /// button would no longer be receiving touch notifications `clickTouch` would
  /// never clear.  When coming back to the scene again later, that "active" button
  /// would be stuck.  And if the affected button is one that requires confirmation,
  /// it's also necessary to ensure that the button is in the normal
  /// not-prompting-for-confirmation state.
  func resetAndCancelConfirmation() {
    decorations[currentDecoration].isHidden = false
    confirmDecoration?.isHidden = true
    removeAllActions()
    resetTouch()
  }

  /// Did the click on a button represent a confirmation to invoke the action?
  ///
  /// For normal buttons, this always says `true`
  ///
  /// - Returns: `true` if the action is confirmed, `false` means abort the action
  func wasConfirmed() -> Bool {
    // No confirmDecoration => simple button, immediately confirmed
    guard let confirmDecoration = confirmDecoration else { return true }
    if confirmDecoration.isHidden {
      // The button requires confirmation but the confirm state hasn't been shown
      return false
    } else {
      // The action was confirmed, switch back to the regular state
      resetAndCancelConfirmation()
      return true
    }
  }

  /// Prompt for confirmation for an action
  ///
  /// For normal buttons, this just returns immediately (and `wasConfirmed` will say
  /// `true`).  Confirmation-required buttons are switched to the confirmation
  /// decoration by this routine.  They'll automatically go back to normal if left
  /// alone for a few seconds.  Or if touched again, `wasConfirmed` will return
  /// `true` on the second touch.
  func requireConfirmation() {
    // No confirmDecoration => no need for confirmation
    guard let confirmDecoration = confirmDecoration else { return }
    // Show the confirm prompt and set a timer to switch back after a bit if there's
    // no confirmation.
    decorations[currentDecoration].isHidden = true
    confirmDecoration.isHidden = false
    wait(for: 3) {
      self.resetAndCancelConfirmation()
    }
  }

  /// Rotate the button's displayed decoration (for toggle or multi-alternative buttons).
  ///
  /// This has no effect if the button has only one decoration.
  func nextDecoration() {
    guard decorations.count > 1 else { return }
    decorations[currentDecoration].isHidden = true
    currentDecoration = (currentDecoration + 1) % decorations.count
    decorations[currentDecoration].isHidden = false
  }

  /// Start touch processing for a button
  ///
  /// If the button is enabled and not yet active, then the first touch gets
  /// remembered as `clickTouch`.  The button then watches only for touch
  /// move/ended/cancelled on that one touch.
  ///
  /// - Parameters:
  ///   - touches: Some touches
  ///   - event: The event the touches belong to
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard enabled else { return }
    for touch in touches {
      if clickTouch == nil {
        clickTouch = touch
        border.glowWidth = 3
      }
    }
  }

  /// Continue button touch processing
  ///
  /// Everything except `clickTouch` is ignored.  As that touch moves in and out of
  /// the button, the frame highlighting is adjusted.
  ///
  /// - Parameters:
  ///   - touches: Some touches
  ///   - event: The event that the touches belong to
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

  /// Some touches on the button ended
  ///
  /// Ignore everything but `clickTouch`.  When that touch is finally release, see if
  /// the button needs another confirmation touch, and if not, invoke the action.
  ///
  /// - Parameters:
  ///   - touches: Some touches
  ///   - event: The event that the touches belong to
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      guard touch == clickTouch else { continue }
      if border.frame.contains(touch.location(in: self)), enabled {
        if wasConfirmed() {
          // Call nextDecoration first so that the action can reference selectedValue
          // to get the button's state.
          nextDecoration()
          action?()
        } else {
          requireConfirmation()
        }
      }
      resetTouch()
    }
  }

  /// Some touches on the button were cancelled
  ///
  /// Ignore everything except `clickTouch`.  If that gets cancelled, then reset the
  /// button state without invoking the action.
  ///
  /// - Parameters:
  ///   - touches: Some touches
  ///   - event: The event that the touches belong to
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      guard touch == clickTouch else { continue }
      resetAndCancelConfirmation()
    }
  }
}
