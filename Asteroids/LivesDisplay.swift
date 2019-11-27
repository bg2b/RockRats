//
//  LivesDisplay.swift
//  Asteroids
//
//  Created by David Long on 8/16/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// A display of the reserve ships
///
/// This consists of a row of small ship icons, plus a counter in case they happen to
/// have too many reserves for the icons to be convenient.  Things are oriented so
/// that the left edge of this display will align naturally with the left edge of the
/// screen.
class LivesDisplay: SKNode {
  /// Maximum number of icons to show
  let maxIcons = 5
  /// A row of icons
  var lifeIcons = [SKSpriteNode]()
  /// A numeric display at the end of the icons for extras
  let numericDisplay: SKLabelNode
  /// Possible messages to show where there are no more reserves
  let dontDieMessages = [
    "Don't die",
    "Livin' on a prayer",
    "Hold on, baby, hold on",
    "Standing on the brink",
    "Who wants to live forever?",
    "Nothin' left to lose",
    "Nothing lasts forever",
    "Never say die",
    "Die another day",
    "I'm not dead yet"
  ]
  /// A label that's shown when there are no more reserves
  let dontDie: SKLabelNode

  /// Make the lives display
  override required init() {
    // The numeric display
    numericDisplay = SKLabelNode(fontNamed: AppAppearance.font)
    numericDisplay.name = "extraLives"
    numericDisplay.fontColor = AppAppearance.textColor
    numericDisplay.horizontalAlignmentMode = .left
    numericDisplay.verticalAlignmentMode = .center
    numericDisplay.isHidden = true
    // The "Don't die" messages when there are no reserve ships left
    dontDie = SKLabelNode(fontNamed: AppAppearance.font)
    dontDie.name = "dontDie"
    dontDie.text = dontDieMessages[0]
    dontDie.fontColor = AppAppearance.textColor
    dontDie.horizontalAlignmentMode = .left
    dontDie.verticalAlignmentMode = .center
    dontDie.isHidden = false
    super.init()
    name = "livesDisplay"
    // A line of sprites for the icons
    let texture = Globals.textureCache.findTexture(imageNamed: "life_blue")
    let spacing = texture.size().width * 11 / 10
    numericDisplay.fontSize = texture.size().height
    dontDie.fontSize = numericDisplay.fontSize
    var nextX = texture.size().width / 2
    for _ in 0 ..< maxIcons {
      let lifeIcon = SKSpriteNode(texture: texture)
      lifeIcon.position = CGPoint(x: nextX, y: 0)
      nextX += spacing
      lifeIcon.isHidden = true
      addChild(lifeIcon)
      lifeIcons.append(lifeIcon)
    }
    // Put the numeric display after the last icon
    numericDisplay.position = CGPoint(x: nextX - spacing / 2, y: 0)
    addChild(numericDisplay)
    // The "Don't die" label sits at the left and is the only thing shown when there
    // are no more reserves
    addChild(dontDie)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by LivesDisplay")
  }

  /// Update the display of reserves
  /// - Parameter numLives: The number of reserves to show
  func showLives(_ numLives: Int) {
    // Hide icons beyond numLives
    lifeIcons.enumerated().forEach() { $1.isHidden = ($0 >= numLives) }
    if numLives > maxIcons {
      // If too many lives, show the numeric display for extras
      numericDisplay.text = "+\(numLives - maxIcons)"
      numericDisplay.isHidden = false
    } else {
      numericDisplay.isHidden = true
    }
    // Pick a random choice for "Don't die" and show that if there are no more reserves
    dontDie.text = dontDieMessages.randomElement()!
    dontDie.isHidden = (numLives != 0)
  }
}
