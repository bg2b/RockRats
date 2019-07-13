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

extension CGPoint {
  func norm2() -> CGFloat {
    return sqrt(x * x + y * y)
  }

  func scale(by amount: CGFloat) -> CGPoint {
    return CGPoint(x: x * amount, y: y * amount)
  }
}
