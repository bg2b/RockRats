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
  let deadZone: CGFloat
  let borderColor: UIColor
  let fillColor: UIColor
  let stick: SKNode
  var touchOffset: CGVector!

  func createBase() {
    let ring = SKShapeNode(circleOfRadius: 0.5 * size)
    ring.name = "joystickBase"
    ring.fillColor = fillColor
    ring.strokeColor = borderColor
    ring.lineWidth = 0.05 * size
    ring.isAntialiased = true
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
      sprite.zPosition = 1
      stick.addChild(sprite)
    }
  }

  required init(size: CGFloat, borderColor: UIColor, fillColor: UIColor, texture: SKTexture?) {
    self.size = size
    // If the stick is within deadZone of the origin, it's treated as inactive for queries
    self.deadZone = 0.5 * 0.33 * size
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

  func getDirection() -> CGVector {
    let delta = CGVector(dx: stick.position.x, dy: stick.position.y)
    let offset = delta.norm2()
    if offset <= deadZone {
      return .zero
    }
    return delta.scale(by: min((offset - deadZone) / (0.5 * size - deadZone), 1.0) / offset)
  }

  func touched(at position: CGPoint) {
    var newStickPos = position - touchOffset
    let distMoved = newStickPos.norm2()
    if distMoved > 0.5 * size {
      newStickPos = newStickPos.scale(by: 0.5 * size / distMoved)
    }
    stick.position = newStickPos
  }

  func released() {
    stick.position = .zero
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let position = touch.location(in: self)
    touchOffset = position - .zero
    touched(at: position)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    // Gradually drop any offset
    touchOffset = touchOffset.scale(by: 0.9)
    touched(at: touch.location(in: self))
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    released()
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    touchesEnded(touches, with: event)
  }
}
