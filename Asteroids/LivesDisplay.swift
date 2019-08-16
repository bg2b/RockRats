//
//  LivesDisplay.swift
//  Asteroids
//
//  Created by David Long on 8/16/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class LivesDisplay: SKNode {
  let maxIcons = 5
  var lifeIcons = [SKSpriteNode]()
  let numericDisplay: SKLabelNode

  required init(extraColor: UIColor) {
    numericDisplay = SKLabelNode(fontNamed: "KenVector Future")
    numericDisplay.name = "extraLives"
    numericDisplay.fontColor = extraColor
    numericDisplay.horizontalAlignmentMode = .left
    numericDisplay.verticalAlignmentMode = .center
    numericDisplay.isHidden = true
    super.init()
    let texture = Globals.textureCache.findTexture(imageNamed: "life_blue")
    let spacing = texture.size().width * 11 / 10
    numericDisplay.fontSize = texture.size().height
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
  }
}
