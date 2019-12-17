//
//  CGHelpers.swift
//  Asteroids
//
//  Created by David Long on 7/13/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import CoreGraphics

// MARK: CGSize helpers

extension CGSize {
  /// Scale uniformly in both direction
  /// - Parameter amount: The amount to scale by
  /// - Returns: The scaled size
  func scale(by amount: CGFloat) -> CGSize {
    return CGSize(width: width * amount, height: height * amount)
  }

  /// Scale to a maximum dimension while maintaining aspect ratio
  /// - Parameter size: The maximum desired width and/or height
  /// - Returns: The scaled size
  func scale(to size: CGFloat) -> CGSize {
    if width > height {
      return scale(by: size / width)
    } else {
      return scale(by: size / height)
    }
  }

  /// The length of the diagonal
  func diagonal() -> CGFloat {
    return hypot(width, height)
  }

  static func + (left: CGSize, right: CGSize) -> CGSize {
    return CGSize(width: left.width + right.width, height: left.height + right.height)
  }

  static func - (left: CGSize, right: CGSize) -> CGSize {
    return CGSize(width: left.width - right.width, height: left.height - right.height)
  }

  static func * (left: CGSize, right: CGSize) -> CGSize {
    return CGSize(width: left.width * right.width, height: left.height * right.height)
  }

  static func / (left: CGSize, right: CGSize) -> CGSize {
    return CGSize(width: left.width / right.width, height: left.height / right.height)
  }
}

// MARK: - CGVector helpers

extension CGVector {
  /// A unit vector at the specified angle
  /// - Parameter angle: Radians
  init(angle: CGFloat) {
    self.init(dx: cos(angle), dy: sin(angle))
  }

  /// Convert a `CGSize` to a `CGVector`
  /// - Parameter dxy: The size
  init(dxy: CGSize) {
    self.init(dx: dxy.width, dy: dxy.height)
  }

  /// The length of the vector
  func length() -> CGFloat {
    return hypot(dx, dy)
  }

  /// Scale uniformly but point in the same direction (or opposite if scaling by a
  /// negative)
  /// - Parameter amount: How much to scale by
  /// - Returns: The scaled vector
  func scale(by amount: CGFloat) -> CGVector {
    return CGVector(dx: dx * amount, dy: dy * amount)
  }

  /// Scale nonuniformly
  /// - Parameter size: A `CGSize` with the two scaling factors
  /// - Returns: The scaled vector
  func scale(by size: CGSize) -> CGVector {
    return CGVector(dx: dx * size.width, dy: dy * size.height)
  }

  func angle() -> CGFloat {
    return atan2(dy, dx)
  }

  /// Mathematical dot product with another vector
  /// - Parameter vec2: The other vector
  /// - Returns: The dot product
  func dotProd(_ vec2: CGVector) -> CGFloat {
    return dx * vec2.dx + dy * vec2.dy
  }

  /// The projection of the vector along a direction given by a second (unit) vector
  /// - Parameter unitVector: The direction to project along
  /// - Returns: The projected vector
  func project(unitVector: CGVector) -> CGVector {
    return unitVector.scale(by: dotProd(unitVector))
  }

  /// Rotate through a given angle
  /// - Parameter angle: Radians
  /// - Returns: The rotated vector
  func rotate(by angle: CGFloat) -> CGVector {
    let c = cos(angle)
    let s = sin(angle)
    return CGVector(dx: c * dx - s * dy, dy: s * dx + c * dy)
  }

  static func += (left: inout CGVector, right: CGVector) {
    left = left + right // swiftlint:disable:this shorthand_operator
  }

  static func -= (left: inout CGVector, right: CGVector) {
    left = left - right // swiftlint:disable:this shorthand_operator
  }

  static func + (left: CGVector, right: CGVector) -> CGVector {
    return CGVector(dx: left.dx + right.dx, dy: left.dy + right.dy)
  }

  static func - (left: CGVector, right: CGVector) -> CGVector {
    return CGVector(dx: left.dx - right.dx, dy: left.dy - right.dy)
  }
}

// MARK: - CGPoint helpers

extension CGPoint {
  static func += (left: inout CGPoint, right: CGVector) {
    left = left + right // swiftlint:disable:this shorthand_operator
  }

  static func + (left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x + right.dx, y: left.y + right.dy)
  }

  static func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
  }

  static func - (left: CGPoint, right: CGVector) -> CGPoint {
    return CGPoint(x: left.x - right.dx, y: left.y - right.dy)
  }

  static func - (left: CGPoint, right: CGPoint) -> CGVector {
    return CGVector(dx: left.x - right.x, dy: left.y - right.y)
  }
}

// MARK: - Geometry primitives

/// The minimum distance between a point and a line segment
///
/// The smallest of three distances:
/// 1. The distance between the point and the segment's first endpoint
/// 2. The distance between the point and the segment's second endpoint
/// 3. The perpendicular distance from the point to the line containing the segment
///
/// - Parameters:
///   - point: The point
///   - segment: The endpoints of the line segment
/// - Returns: The minimum distance
func distanceBetween(point: CGPoint, segment: (CGPoint, CGPoint)) -> CGFloat {
  let delta = segment.1 - segment.0
  let segmentLength = delta.length()
  let offsetFromStart = point - segment.0
  guard segmentLength > 0 else { return offsetFromStart.length() }
  let along = offsetFromStart.dotProd(delta)
  if along <= 0 {
    // Closest at the starting point
    return offsetFromStart.length()
  } else if along >= delta.dotProd(delta) {
    // Closest at the ending point
    return (point - segment.1).length()
  } else {
    // Somewhere between starting and ending; return perpendicular distance
    return (abs(offsetFromStart.dotProd(delta.rotate(by: .pi / 2))) / segmentLength)
  }
}
