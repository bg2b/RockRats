//
//  LabelStack.swift
//  Asteroids
//
//  Created by David Long on 10/31/22.
//  Copyright © 2022 David Long. All rights reserved.
//

import SpriteKit

/// Make a vertical stack of text, with the lines centered
///
/// - Parameters:
///   - lines: The lines of text, top to bottom
///   - fontColor: Color for the text
///   - fontSize: The line spacing (default 30)
/// - Returns: an SKNode for the stack.  The text is centered horizontally and
///   vertically at the node's origin.
func stackedLabels(_ lines: [String], fontColor: UIColor, fontSize: CGFloat = 30) -> SKNode {
  let stack = SKNode()
  var nextY = CGFloat(0)
  for line in lines {
    let label = SKLabelNode(fontNamed: AppAppearance.font)
    label.fontSize = fontSize
    label.fontColor = fontColor
    label.text = line
    label.horizontalAlignmentMode = .center
    label.verticalAlignmentMode = .center
    label.position = CGPoint(x: 0, y: nextY)
    nextY -= fontSize
    stack.addChild(label)
  }
  let currentMidY = stack.calculateAccumulatedFrame().midY
  stack.position = CGPoint(x: 0, y: -currentMidY)
  return stack
}
