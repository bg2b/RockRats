//
//  LivesDisplay.swift
//  Asteroids
//
//  Created by David Long on 8/16/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

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

class LivesDisplay: SKNode {
  let maxIcons = 5
  var lifeIcons = [SKSpriteNode]()
  let numericDisplay: SKLabelNode
  let dontDie: SKLabelNode

  override required init() {
    numericDisplay = SKLabelNode(fontNamed: AppAppearance.font)
    numericDisplay.name = "extraLives"
    numericDisplay.fontColor = AppAppearance.textColor
    numericDisplay.horizontalAlignmentMode = .left
    numericDisplay.verticalAlignmentMode = .center
    numericDisplay.isHidden = true
    dontDie = SKLabelNode(fontNamed: AppAppearance.font)
    dontDie.name = "dontDie"
    dontDie.text = dontDieMessages[0]
    dontDie.fontColor = AppAppearance.textColor
    dontDie.horizontalAlignmentMode = .left
    dontDie.verticalAlignmentMode = .center
    dontDie.isHidden = false
    super.init()
    let texture = Globals.textureCache.findTexture(imageNamed: "life_blue")
    let spacing = texture.size().width * 11 / 10
    numericDisplay.fontSize = texture.size().height
    dontDie.fontSize = numericDisplay.fontSize
    var nextX = texture.size().width / 2
    for _ in 0..<maxIcons {
      let lifeIcon = SKSpriteNode(texture: texture)
      lifeIcon.position = CGPoint(x: nextX, y: 0)
      nextX += spacing
      lifeIcon.isHidden = true
      addChild(lifeIcon)
      lifeIcons.append(lifeIcon)
    }
    numericDisplay.position = CGPoint(x: nextX - spacing / 2, y: 0)
    addChild(numericDisplay)
    addChild(dontDie)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by LivesDisplay")
  }

  func showLives(_ numLives: Int) {
    lifeIcons.enumerated().forEach() { $1.isHidden = ($0 >= numLives) }
    if numLives > maxIcons {
      numericDisplay.text = "+\(numLives - maxIcons)"
      numericDisplay.isHidden = false
    } else {
      numericDisplay.isHidden = true
    }
    dontDie.text = dontDieMessages.randomElement()!
    dontDie.isHidden = (numLives != 0)
  }
}
