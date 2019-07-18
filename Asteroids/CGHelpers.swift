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
}

extension CGVector {
  init(angle: CGFloat) {
    self.init(dx: cos(angle), dy: sin(angle))
  }

  func norm2() -> CGFloat {
    return sqrt(dx * dx + dy * dy)
  }

  func scale(by amount: CGFloat) -> CGVector {
    return CGVector(dx: dx * amount, dy: dy * amount)
  }

  func angle() -> CGFloat {
    return atan2(dy, dx)
  }

  func dotProd(_ vec2: CGVector) -> CGFloat {
    return dx * vec2.dx + dy * vec2.dy
  }

  func project(unitVector: CGVector) -> CGVector {
    return unitVector.scale(by: self.dotProd(unitVector))
  }
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

func -(left: CGPoint, right: CGVector) -> CGPoint {
  return CGPoint(x: left.x - right.dx, y: left.y - right.dy)
}

func -(left: CGPoint, right: CGPoint) -> CGVector {
  return CGVector(dx: left.x - right.x, dy: left.y - right.y)
}
