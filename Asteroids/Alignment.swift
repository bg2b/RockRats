//
//  Alignment.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import SpriteKit

// swiftlint:disable function_parameter_count
/// Helper function for `horizontalStack` and `verticalStack`
///
/// The closures here are for extracting/manipulating the relevant bits of the
/// geometry according to whether this is a hortizontal stack or a vertical stack.
/// Call `horizontalStack` or `verticalStack` instead of this function.
///
/// - Parameters:
///   - nodes: The nodes to stack up
///   - minSpacing: Minimum spacing between the nodes
///   - within: Desired min and max position of the stack
///   - getDimension: Closure for specifying horizontal/vertical
///   - frame: A rectangle for a node's size and position
///   - adjustPos: Closure for specifying horizontal/vertical
///   - getMid: Closure for specifying horizontal/vertical
///   - pos: A point to be adjusted
///   - newCoord: New value for one of the point's coordinates
/// - Returns: A node for the stack
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
// swiftlint:enable function_parameter_count

func horizontalStack(nodes: [SKNode], minSpacing: CGFloat, within: ClosedRange<CGFloat> = 0 ... 0) -> SKNode {
  return makeStack(nodes: nodes, minSpacing: minSpacing, within: within,
                   getDimension: { $0.width }, adjustPos: { CGPoint(x: $1, y: $0.y) }, getMid: { $0.midX })
}

func verticalStack(nodes: [SKNode], minSpacing: CGFloat, within: ClosedRange<CGFloat> = 0 ... 0) -> SKNode {
  return makeStack(nodes: nodes, minSpacing: minSpacing, within: within,
                   getDimension: { $0.height }, adjustPos: { CGPoint(x: $0.x, y: -$1) }, getMid: { $0.midY })
}
