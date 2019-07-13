//
//  Joystick.swift
//  Asteroids
//
//  Created by David Long on 7/11/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class Joystick: SKNode {
  let size: CGFloat
  let borderColor: UIColor
  let fillColor: UIColor
  let stick: SKNode

  func createBase() {
    let ring = SKShapeNode(circleOfRadius: 0.5 * size)
    ring.name = "joystickBase"
    ring.fillColor = fillColor
    ring.strokeColor = borderColor
    ring.lineWidth = 0.05 * size
    ring.isAntialiased = true
    ring.zPosition = -1
    addChild(ring)
  }

  func createStick(texture: SKTexture?) {
    stick.name = "joystickStick"
    addChild(stick)
    let knob = SKShapeNode(circleOfRadius: 0.35 * size)
    knob.name = "joystickKnob"
    knob.fillColor = .clear
    knob.strokeColor = borderColor
    knob.lineWidth = 0.05 * size
    knob.isAntialiased = true
    knob.zPosition = 1
    stick.addChild(knob)
    if let texture = texture {
      let sprite = SKSpriteNode(texture: texture, size: texture.size().scale(to: 0.5 * size))
      sprite.name = "joystickKnobDecoration"
      sprite.zPosition = 2
      stick.addChild(sprite)
    }
  }

  required init(size: CGFloat, borderColor: UIColor, fillColor: UIColor, texture: SKTexture?) {
    self.size = size
    self.borderColor = borderColor
    self.fillColor = fillColor
    self.stick = SKNode()
    super.init()
    self.isUserInteractionEnabled = true
    self.name = "joystick"
    createBase()
    createStick(texture: texture)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Joystick")
  }

  func touched(at position: CGPoint) {
    var newStickPos = position
    let distMoved = newStickPos.norm2()
    if distMoved > 0.5 * size {
      newStickPos = newStickPos.scale(by: 0.5 * size / distMoved)
    }
    stick.position = newStickPos
  }

  func released() {
    stick.position = CGPoint.zero
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    touched(at: touch.location(in: self))
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchesBegan(touches, with: event)
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    released()
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchesEnded(touches, with: event)
  }
}
