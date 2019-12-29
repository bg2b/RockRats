//
//  ConvexHull.swift
//  Asteroids
//
//  Created by David Long on 10/1/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import os.log

// TextureBitmap is declared in Hyperspace.swift
typealias ImageMask = TextureBitmap<Bool>

extension ImageMask {
  /// Create a mask from a texture indicating where the texture is opaque
  /// - Parameters:
  ///   - texture: The texture
  ///   - alphaThreshold: The mask will be true when a pixel's alpha exceeds this
  ///     value (0 - 1)
  init(texture: SKTexture, alphaThreshold: CGFloat) {
    self.init(texture: texture) { pixel in
      let alpha = pixel & 0xff
      return CGFloat(alpha) >= alphaThreshold * 256
    }
  }

  /// Indexes into the mask, returns `false` for coordinates outside the edges
  subscript(x: Int, y: Int) -> Bool {
    if x < 0 || x >= width || y < 0 || y >= height {
      return false
    } else {
      return pixels[x + y * width]
    }
  }

  /// Is a pixel in the interior (surround by opaque pixels)?
  /// - Parameters:
  ///   - x: x coordinate
  ///   - y: y coordinate
  /// - Returns: `true` for iterior pixels
  func isInterior(_ x: Int, _ y: Int) -> Bool {
    for dx in [-1, 0, 1] {
      for dy in [-1, 0, 1] {
        if !self[x + dx, y + dy] {
          return false
        }
      }
    }
    return true
  }

  /// Get a list of boundary pixels
  /// - Returns: A list of all pixels that are opaque but not interior
  func boundary() -> [(Int, Int)] {
    var result = [(Int, Int)]()
    for x in 0 ..< width {
      for y in 0 ..< height {
        if self[x, y] && !isInterior(x, y) {
          result.append((x, y))
        }
      }
    }
    return result
  }

  /// Print the mask, for debugging
  func show() {
    for y in -1 ... height {
      var line = ""
      for x in -1 ... width {
        if self[x, y] {
          line += "@"
        } else {
          line += "."
        }
      }
      print(line)
    }
  }

  /// Compute the orientation of three points
  ///
  /// The sign of the result indicates how you turn going from point `a` to `b` to
  /// `c`.  Positive means counterclockwise, negative means clockwise, zero means
  /// colinear
  ///
  /// - Parameters:
  ///   - a: A pair of integers, the coordinates of the first point
  ///   - b: The second point
  ///   - c: The third point
  /// - Returns: An integer whose sign indicates the orientation
  func orient(_ a: (Int, Int), _ b: (Int, Int), _ c: (Int, Int)) -> Int {
    let acx = a.0 - c.0
    let acy = a.1 - c.1
    let bcx = b.0 - c.0
    let bcy = b.1 - c.1
    return acx * bcy - acy * bcx
  }

  /// The squared distance between points
  /// - Parameters:
  ///   - a: A pair of integers, the coordinates of the first point
  ///   - b: The second point
  /// - Returns: The square of the Euclidean distance
  func distance(_ a: (Int, Int), _ b: (Int, Int)) -> Int {
    let dx = b.0 - a.0
    let dy = b.1 - a.1
    return dx * dx + dy * dy
  }

  /// Convert an integer coordinate to a texture coordinate
  ///
  /// This assumes that the texture is intended to be centered on the
  /// `SKSpriteNode`'s origin.  The conversion involves a shift to the center of the
  /// image mask and a flip of the y-axis to match SpriteKit's conventions.
  ///
  /// - Parameter a: The integer coordinates
  /// - Returns: The coordinates in the original texture
  func asPoint(_ a: (Int, Int)) -> CGPoint {
    let w = CGFloat(width)
    let h = CGFloat(height)
    return CGPoint(x: (CGFloat(a.0) - 0.5 * w) / w * textureSize.width,
                   y: (0.5 * h - CGFloat(a.1)) / h * textureSize.height)
  }

  /// Compute the convex hull of the opaque parts of a texture and represent it as an
  /// `SKPhysicsBody`
  ///
  /// Constructs the boundary points of the mask, runs a Graham scan to compute the
  /// convex hull, and converts the hull to a polygon-based physics body.
  ///
  /// - Returns: The physics body
  func convexHull() -> SKPhysicsBody {
    let b = boundary()
    guard let initial = b.first else { fatalError("No points for convex hull") }
    let rest = b.dropFirst().sorted { p1, p2 in
      let o = orient(initial, p1, p2)
      if o > 0 { return true }
      if o < 0 { return false }
      return distance(initial, p1) < distance(initial, p2)
    }
    var hull = [initial]
    for p in rest {
      while hull.count >= 2 {
        let q1 = hull[hull.count - 2]
        let q2 = hull[hull.count - 1]
        if orient(q1, q2, p) > 0 { break }
        _ = hull.removeLast()
      }
      hull.append(p)
    }
    guard hull.count >= 3 else { fatalError("Too few points for convex hull") }
    let points = hull.map { asPoint($0) }
    let path = CGMutablePath()
    path.addLines(between: points)
    path.closeSubpath()
    return SKPhysicsBody(polygonFrom: path)
  }
}

/// A cache holding physics bodies for those objects that aren't sufficiently circular
///
/// This ugliness is all caused by iOS 13 breaking the creation of phyiscs bodies
/// from textures in various ways.
class ConformingPhysicsCache {
  /// A dictionary with physics bodies for all non-circular textures
  var bodies = [SKTexture: SKPhysicsBody]()
  /// The number of physics bodies created
  var made = 0
  /// The number of unique physics bodies
  var unique = 0

  /// Create a physics body for a non-circular texture
  ///
  /// This ugliness is all caused by iOS 13 breaking
  ///
  /// - Parameters:
  ///   - texture: The texture
  ///   - preloadName: The name of the image used for the texture
  /// - Returns: The physics body
  func makeBody(texture: SKTexture, preloadName: String = "") -> SKPhysicsBody {
    made += 1
    if let body = bodies[texture] {
      // Already computed a body for this texture, just make a copy
      return body.copy() as! SKPhysicsBody
    } else {
      unique += 1
      let os = ProcessInfo().operatingSystemVersion
      if os.majorVersion == 13 {
        if os.minorVersion < 2 {
          // iOS 13.0 and 13.1 had some bugs with creation from a texture and would
          // just totally screw it up, so use the convex hull
          let body = ImageMask(texture: texture, alphaThreshold: 0.5).convexHull()
          bodies[texture] = body
          return body.copy() as! SKPhysicsBody
        } else {
          // 13.2 can make bodies from textures, but not if they're in an atlas.  And
          // I need textures in an atlas since otherwise it blow SpriteKit's draw
          // count.  I get around the issue by having duplicates of all the
          // non-circular textures that are named "nonatlas_..." :-(
          //
          // I was tempted to just use the convex hull in all cases with iOS 13, but
          // it turns out that when they "fixed" the bug, except for the in-an-atlas
          // case, they simultaneously broke the stuff that converts textures to
          // CGImages.  As a result, my convex hull computation (which relied on
          // that) went out the window.
          let preloadTexture = SKTexture(imageNamed: "nonatlas_" + preloadName)
          let body = SKPhysicsBody(texture: preloadTexture, size: preloadTexture.size())
          bodies[texture] = body
          return body.copy() as! SKPhysicsBody
        }
      } else {
        /// This is a non-broken version of SpriteKit, so I can just use its
        /// standard constructor.
        let body = SKPhysicsBody(texture: texture, size: texture.size())
        bodies[texture] = body
        return body.copy() as! SKPhysicsBody
      }
    }
  }

  /// Preload the cache with the main conforming physics bodies
  ///
  /// Things would get created on the fly anyway, but may as well call this at the
  /// start to reduce any lags.
  func preload() {
    let conformingTextures = [
      "ship_blue", "ship_green", "ship_red", "ship_orange", "retroship",
      "meteorbig1", "meteorbig2", "meteorbig3",
      "meteorhuge1", "meteorhuge2"
    ]
    for textureName in conformingTextures {
      _ = makeBody(texture: Globals.textureCache.findTexture(imageNamed: textureName), preloadName: textureName)
    }
  }

  func stats() {
    os_log("Conforming physics cache made %d physicsBodies, %d unique", log: .app, type: .debug, made, unique)
  }
}

extension Globals {
  static var conformingPhysicsCache = ConformingPhysicsCache()
}
