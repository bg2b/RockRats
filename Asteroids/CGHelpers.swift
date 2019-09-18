//
//  CGHelpers.swift
//  Asteroids
//
//  Created by David Long on 7/13/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import CoreGraphics

extension CGSize {
  func scale(by amount: CGFloat) -> CGSize {
    return CGSize(width: width * amount, height: height * amount)
  }

  func scale(to size: CGFloat) -> CGSize {
    if width > height {
      return scale(by: size / width)
    } else {
      return scale(by: size / height)
    }
  }

  func diagonal() -> CGFloat {
    return hypot(width, height)
  }
}

extension CGVector {
  init(angle: CGFloat) {
    self.init(dx: cos(angle), dy: sin(angle))
  }

  func norm2() -> CGFloat {
    return hypot(dx, dy)
  }

  func scale(by amount: CGFloat) -> CGVector {
    return CGVector(dx: dx * amount, dy: dy * amount)
  }

  func scale(by size: CGSize) -> CGVector {
    return CGVector(dx: dx * size.width, dy: dy * size.height)
  }

  func angle() -> CGFloat {
    return atan2(dy, dx)
  }

  func dotProd(_ vec2: CGVector) -> CGFloat {
    return dx * vec2.dx + dy * vec2.dy
  }

  func project(unitVector: CGVector) -> CGVector {
    return unitVector.scale(by: dotProd(unitVector))
  }

  func rotate(by angle: CGFloat) -> CGVector {
    let c = cos(angle)
    let s = sin(angle)
    return CGVector(dx: c * dx - s * dy, dy: s * dx + c * dy)
  }
}

func +(left: CGVector, right: CGVector) -> CGVector {
  return CGVector(dx: left.dx + right.dx, dy: left.dy + right.dy)
}

func -(left: CGVector, right: CGVector) -> CGVector {
  return CGVector(dx: left.dx - right.dx, dy: left.dy - right.dy)
}

extension CGPoint {
  func norm2() -> CGFloat {
    return sqrt(x * x + y * y)
  }

  func scale(by amount: CGFloat) -> CGPoint {
    return CGPoint(x: x * amount, y: y * amount)
  }
}

func +(left: CGPoint, right: CGVector) -> CGPoint {
  return CGPoint(x: left.x + right.dx, y: left.y + right.dy)
}

func +(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func -(left: CGPoint, right: CGVector) -> CGPoint {
  return CGPoint(x: left.x - right.dx, y: left.y - right.dy)
}

func -(left: CGPoint, right: CGPoint) -> CGVector {
  return CGVector(dx: left.x - right.x, dy: left.y - right.y)
}

func distanceBetween(point: CGPoint, segment: (CGPoint, CGPoint)) -> CGFloat {
  let delta = segment.1 - segment.0
  let segmentLength = delta.norm2()
  let offsetFromStart = point - segment.0
  guard segmentLength > 0 else { return offsetFromStart.norm2() }
  let along = offsetFromStart.dotProd(delta)
  if along <= 0 {
    // Closest at the starting point
    return offsetFromStart.norm2()
  } else if along >= delta.dotProd(delta) {
    // Closest at the ending point
    return (point - segment.1).norm2()
  } else {
    // Somewhere between starting and ending; return perpendicular distance
    return (abs(offsetFromStart.dotProd(delta.rotate(by: .pi / 2))) / segmentLength)
  }
}
