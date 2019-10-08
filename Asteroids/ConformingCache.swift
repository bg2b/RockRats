//
//  ConvexHull.swift
//  Asteroids
//
//  Created by David Long on 10/1/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

struct ImageMask {
  let textureSize: CGSize
  let width: Int
  let height: Int
  let mask: [Bool]

  init(texture: SKTexture, alphaThreshold: CGFloat) {
    textureSize = texture.size()
    let image = texture.cgImage()
    width = image.width
    height = image.height
    let cgContext = CGContext(data: nil,
                              width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 4 * width,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                                CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let context = cgContext else { fatalError("Could not create graphics context") }
    context.draw(image, in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
    guard let data = context.data else { fatalError("Graphics context has no data") }
    mask = (0 ..< width * height).map {
      let pixel = (data + 4 * $0).load(as: UInt32.self)
      let alpha = pixel & 0xff
      return CGFloat(alpha) >= alphaThreshold * 256
    }
  }

  subscript(x: Int, y: Int) -> Bool {
    if x < 0 || x >= width || y < 0 || y >= height {
      return false
    } else {
      return mask[x + y * width]
    }
  }

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

  func orient(_ a: (Int, Int), _ b: (Int, Int), _ c: (Int, Int)) -> Int {
    // Positive = ccw, negative = cw, zero = colinear
    let acx = a.0 - c.0
    let acy = a.1 - c.1
    let bcx = b.0 - c.0
    let bcy = b.1 - c.1
    return acx * bcy - acy * bcx
  }

  func distance(_ a: (Int, Int), _ b: (Int, Int)) -> Int {
    let dx = b.0 - a.0
    let dy = b.1 - a.1
    return dx * dx + dy * dy
  }

  func asPoint(_ a: (Int, Int)) -> CGPoint {
    let w = CGFloat(width)
    let h = CGFloat(height)
    return CGPoint(x: (CGFloat(a.0) - 0.5 * w) / w * textureSize.width,
                   y: (0.5 * h - CGFloat(a.1)) / h * textureSize.height)
  }

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
        let _ = hull.removeLast()
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

class ConformingPhysicsCache {
  var bodies = [SKTexture: SKPhysicsBody]()
  var made = 0
  var unique = 0

  func makeBody(texture: SKTexture) -> SKPhysicsBody {
    made += 1
    if let body = bodies[texture] {
      return body.copy() as! SKPhysicsBody
    } else {
      unique += 1
      let os = ProcessInfo().operatingSystemVersion
      if os.majorVersion != 13 {
        let body = SKPhysicsBody(texture: texture, size: texture.size())
        bodies[texture] = body
        return body.copy() as! SKPhysicsBody
      } else {
        // iOS 13 has some bugs with creation from a texture
        let body = ImageMask(texture: texture, alphaThreshold: 0.5).convexHull()
        bodies[texture] = body
        return body.copy() as! SKPhysicsBody
      }
    }
  }

  func preload() {
    // Make the main conforming physics bodies.  Things would get created on the fly
    // anyway, but may as well try to reduce any lags.
    let conformingTextures = [
      "ship_blue", "retroship",
      "meteorbig1", "meteorbig2", "meteorbig3",
      "meteorhuge1", "meteorhuge2",
    ]
    for textureName in conformingTextures {
      let _ = makeBody(texture: Globals.textureCache.findTexture(imageNamed: textureName))
    }
  }

  func stats() {
    logging("Conforming physics cache made \(made) physicsBodies, \(unique) are unique")
  }
}

extension Globals {
  static var conformingPhysicsCache = ConformingPhysicsCache()
}
