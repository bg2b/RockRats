//
//  Alignment.swift
//  Asteroids
//
//  Created by David Long on 12/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

func makeStack(nodes: [SKNode], minSpacing: CGFloat, within: ClosedRange<CGFloat>,
               getDimension: (_ frame: CGRect) -> CGFloat,
               adjustPos: (_ pos: CGPoint, _ newCoord: CGFloat) -> CGPoint,
               getMid: (_ frame: CGRect) -> CGFloat) -> SKNode {
  let stack = SKNode()
  stack.name = "stack"
  if nodes.count == 1 {
    stack.addChild(nodes[0])
  } else if nodes.count > 1 {
    var sizes = [CGFloat]()
    for node in nodes {
      sizes.append(getDimension(node.calculateAccumulatedFrame()))
    }
    let totalSize = sizes.reduce(0) { $0 + $1 }
    let maxSize = within.upperBound - within.lowerBound
    let spacing = max(minSpacing, (maxSize - totalSize) / CGFloat(nodes.count - 1))
    var coord = CGFloat(0)
    for node in nodes {
      node.position = adjustPos(node.position, coord)
      coord += getDimension(node.calculateAccumulatedFrame()) + spacing
      stack.addChild(node)
    }
  }
  stack.position = .zero
  let midCoord = 0.5 * (within.lowerBound + within.upperBound)
  stack.position = adjustPos(stack.position, midCoord - getMid(stack.calculateAccumulatedFrame()))
  return stack
}

func horizontalStack(nodes: [SKNode], minSpacing: CGFloat, within: ClosedRange<CGFloat> = 0 ... 0) -> SKNode {
  return makeStack(nodes: nodes, minSpacing: minSpacing, within: within,
                   getDimension: { $0.width }, adjustPos: { CGPoint(x: $1, y: $0.y) }, getMid: { $0.midX })
}

func verticalStack(nodes: [SKNode], minSpacing: CGFloat, within: ClosedRange<CGFloat> = 0 ... 0) -> SKNode {
  return makeStack(nodes: nodes, minSpacing: minSpacing, within: within,
                   getDimension: { $0.height }, adjustPos: { CGPoint(x: $0.x, y: -$1) }, getMid: { $0.midY })
}
