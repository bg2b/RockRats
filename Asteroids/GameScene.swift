//
//  GameScene.swift
//  Asteroids
//
//  Created by David Long on 7/7/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import GameplayKit

class Ship: SKSpriteNode {
  convenience init() {
    self.init(imageNamed: "playerShip_blue")
  }
}

class GameScene: SKScene {

  override func didMove(to view: SKView) {
    let ship = Ship()
    ship.position = CGPoint(x: 0.0, y: 0.0)
    addChild(ship)
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
  }
    
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
  }
    
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
  }

  override func update(_ currentTime: TimeInterval) {
    // Called before each frame is rendered
  }
}
