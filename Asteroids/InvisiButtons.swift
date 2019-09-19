//
//  InvisiButtons.swift
//  Asteroids
//
//  Created by Daniel on 9/17/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class InvisiButtons: SKNode {
  let size: CGSize
  var enabled: [Bool] = []
  var actions: [(() -> Void)?] = []
  
  required init(size: CGSize, actions: [(() -> Void)?]) {
    self.size = size
    self.actions = actions
    super.init()
    actions.forEach() { _ in self.enabled.append(true) }
    isUserInteractionEnabled = true
    name = "invisiButton"
    let area = SKShapeNode(rectOf: size)
    area.fillColor = .clear
    area.strokeColor = .white
    area.name = "activeArea"
    addChild(area)
  }
  
  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Button")
  }
  
  func enable(_ i: Int) {
    enabled[i] = true
  }
  
  func disable(_ i: Int) {
    enabled[i] = false
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let ypos = touch.location(in: self).y
    if ypos < 0 {
      actions[0]?()
    } else {
      actions[1]?()
    }
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
  }
  
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchesEnded(touches, with: event)
  }
}
