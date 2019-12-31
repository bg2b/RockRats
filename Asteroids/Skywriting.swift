//
//  Skywriting.swift
//  Asteroids
//
//  Created by David Long on 12/30/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import os.log

// MARK: Font

extension String {
  func skywritingCharacter() -> [[Character]] {
    let result = self.split(separator: "\n")
    assert(result.allSatisfy { $0.count == result[0].count })
    return result.map { [Character]($0) }
  }
}

let skywritingFont: [Character: [[Character]]] = {
  var font = [Character: [[Character]]]()
  font["A"] = """
  ..x..
  .x.x.
  x...x
  xxxxx
  x...x
  x...x
  x...x
  """.skywritingCharacter()
  font["B"] = """
  xxxx.
  x...x
  x...x
  xxxx.
  x...x
  x...x
  xxxx.
  """.skywritingCharacter()
  font["C"] = """
  .xxx.
  x...x
  x....
  x....
  x....
  x...x
  .xxx.
  """.skywritingCharacter()
  font["D"] = """
  xxxx.
  x...x
  x...x
  x...x
  x...x
  x...x
  xxxx.
  """.skywritingCharacter()
  font["E"] = """
  xxxxx
  x....
  x....
  xxxx.
  x....
  x....
  xxxxx
  """.skywritingCharacter()
  font["F"] = """
  xxxxx
  x....
  x....
  xxxx.
  x....
  x....
  x....
  """.skywritingCharacter()
  font["G"] = """
  .xxx.
  x...x
  x....
  x....
  x..xx
  x...x
  .xxx.
  """.skywritingCharacter()
  font["H"] = """
  x...x
  x...x
  x...x
  xxxxx
  x...x
  x...x
  x...x
  """.skywritingCharacter()
  font["I"] = """
  x
  x
  x
  x
  x
  x
  x
  """.skywritingCharacter()
  font["J"] = """
  ....x
  ....x
  ....x
  ....x
  ....x
  x...x
  .xxx.
  """.skywritingCharacter()
  font["K"] = """
  x...x
  x...x
  x..x.
  xxx..
  x..x.
  x...x
  x...x
  """.skywritingCharacter()
  font["L"] = """
  x....
  x....
  x....
  x....
  x....
  x....
  xxxxx
  """.skywritingCharacter()
  font["M"] = """
  x.....x
  xx...xx
  x.x.x.x
  x..x..x
  x.....x
  x.....x
  x.....x
  """.skywritingCharacter()
  font["N"] = """
  x...x
  xx..x
  x.x.x
  x..xx
  x...x
  x...x
  x...x
  """.skywritingCharacter()
  font["O"] = """
  .xxx.
  x...x
  x...x
  x...x
  x...x
  x...x
  .xxx.
  """.skywritingCharacter()
  font["P"] = """
  xxxx.
  x...x
  x...x
  xxxx.
  x....
  x....
  x....
  """.skywritingCharacter()
  font["Q"] = """
  .xxx.
  x...x
  x...x
  x...x
  x.x.x
  x..xx
  .xxxx
  """.skywritingCharacter()
  font["R"] = """
  xxxx.
  x...x
  x...x
  xxxx.
  x...x
  x...x
  x...x
  """.skywritingCharacter()
  font["S"] = """
  .xxx.
  x...x
  x....
  .xxx.
  ....x
  x...x
  .xxx.
  """.skywritingCharacter()
  font["T"] = """
  xxxxx
  ..x..
  ..x..
  ..x..
  ..x..
  ..x..
  ..x..
  """.skywritingCharacter()
  font["U"] = """
  x...x
  x...x
  x...x
  x...x
  x...x
  x...x
  .xxx.
  """.skywritingCharacter()
  font["V"] = """
  x...x
  x...x
  x...x
  x...x
  x...x
  .x.x.
  ..x..
  """.skywritingCharacter()
  font["W"] = """
  x.....x
  x.....x
  x.....x
  x..x..x
  x.x.x.x
  xx...xx
  x.....x
  """.skywritingCharacter()
  font["X"] = """
  x...x
  x...x
  .x.x.
  ..x..
  .x.x.
  x...x
  x...x
  """.skywritingCharacter()
  font["Y"] = """
  x...x
  x...x
  .x.x.
  ..x..
  ..x..
  ..x..
  ..x..
  """.skywritingCharacter()
  font["Z"] = """
  xxxxx
  ....x
  ...x.
  ..x..
  .x...
  x....
  xxxxx
  """.skywritingCharacter()
  font[" "] = """
  ...
  ...
  ...
  ...
  ...
  ...
  ...
  """.skywritingCharacter()
  font["."] = """
  ..
  ..
  ..
  ..
  ..
  ..
  x.
  """.skywritingCharacter()
  font["!"] = """
  x.
  x.
  x.
  x.
  x.
  ..
  x.
  """.skywritingCharacter()
  font["?"] = """
  .xxx..
  x...x.
  ....x.
  ...x..
  ..x...
  ......
  ..x...
  """.skywritingCharacter()
  font[","] = """
  ..
  ..
  ..
  ..
  ..
  .x
  .x
  x.
  """.skywritingCharacter()
  font[";"] = """
  ..
  ..
  ..
  .x
  ..
  .x
  .x
  x.
  """.skywritingCharacter()
  font[":"] = """
  .
  .
  .
  x
  .
  .
  x
  """.skywritingCharacter()
  font["'"] = """
  x
  x
  .
  .
  .
  .
  .
  """.skywritingCharacter()
  font["\""] = """
  x.x
  x.x
  ...
  ...
  ...
  ...
  ...
  """.skywritingCharacter()
  font["0"] = """
  .xxx.
  x...x
  x..xx
  x.x.x
  xx..x
  x...x
  .xxx.
  """.skywritingCharacter()
  font["1"] = """
  xx.
  .x.
  .x.
  .x.
  .x.
  .x.
  xxx
  """.skywritingCharacter()
  font["2"] = """
  .xxx.
  x...x
  ....x
  .xxx.
  x....
  x....
  xxxxx
  """.skywritingCharacter()
  font["3"] = """
  .xxx.
  x...x
  ....x
  ..xx.
  ....x
  x...x
  .xxx.
  """.skywritingCharacter()
  font["4"] = """
  x...x
  x...x
  x...x
  xxxxx
  ....x
  ....x
  ....x
  """.skywritingCharacter()
  font["5"] = """
  xxxxx
  x....
  x....
  xxxx.
  ....x
  ....x
  xxxx.
  """.skywritingCharacter()
  font["6"] = """
  .xxx.
  x...x
  x....
  xxxx.
  x...x
  x...x
  .xxx.
  """.skywritingCharacter()
  font["7"] = """
  xxxxx
  ....x
  ...x.
  ..x..
  ..x..
  ..x..
  ..x..
  """.skywritingCharacter()
  font["8"] = """
  .xxx.
  x...x
  x...x
  .xxx.
  x...x
  x...x
  .xxx.
  """.skywritingCharacter()
  font["9"] = """
  .xxx.
  x...x
  x...x
  .xxxx
  ....x
  x...x
  .xxx.
  """.skywritingCharacter()
  font["a"] = """
  .....
  .....
  .xxx.
  ....x
  .xxxx
  x...x
  .xxxx
  """.skywritingCharacter()
  font["b"] = """
  x....
  x....
  xxxx.
  x...x
  x...x
  x...x
  xxxx.
  """.skywritingCharacter()
  font["c"] = """
  .....
  .....
  .xxxx
  x....
  x....
  x....
  .xxxx
  """.skywritingCharacter()
  font["d"] = """
  ....x
  ....x
  .xxxx
  x...x
  x...x
  x...x
  .xxxx
  """.skywritingCharacter()
  font["e"] = """
  .....
  .....
  .xxx.
  x...x
  xxxxx
  x....
  .xxxx
  """.skywritingCharacter()
  font["f"] = """
  ..xxx
  .x...
  .x...
  xxxxx
  .x...
  .x...
  .x...
  """.skywritingCharacter()
  font["g"] = """
  .....
  .....
  .xxxx
  x...x
  x...x
  x...x
  .xxxx
  ....x
  .xxx.
  """.skywritingCharacter()
  font["h"] = """
  x....
  x....
  xxxx.
  x...x
  x...x
  x...x
  x...x
  """.skywritingCharacter()
  font["i"] = """
  .
  x
  .
  x
  x
  x
  x
  """.skywritingCharacter()
  font["j"] = """
  ....
  ...x
  ....
  ...x
  ...x
  ...x
  ...x
  ...x
  xxx.
  """.skywritingCharacter()
  font["k"] = """
  x....
  x....
  x...x
  x..x.
  xxx..
  x..x.
  x...x
  """.skywritingCharacter()
  font["l"] = """
  xx
  .x
  .x
  .x
  .x
  .x
  .x
  """.skywritingCharacter()
  font["m"] = """
  .......
  .......
  xxx.xx.
  x..x..x
  x..x..x
  x..x..x
  x..x..x
  """.skywritingCharacter()
  font["n"] = """
  .....
  .....
  xxxx.
  x...x
  x...x
  x...x
  x...x
  """.skywritingCharacter()
  font["o"] = """
  .....
  .....
  .xxx.
  x...x
  x...x
  x...x
  .xxx.
  """.skywritingCharacter()
  font["p"] = """
  .....
  .....
  xxxx.
  x...x
  x...x
  x...x
  xxxx.
  x....
  x....
  """.skywritingCharacter()
  font["q"] = """
  .....
  .....
  .xxxx
  x...x
  x...x
  x...x
  .xxxx
  ....x
  ....x
  """.skywritingCharacter()
  font["r"] = """
  .....
  .....
  xxxx.
  x...x
  x....
  x....
  x....
  """.skywritingCharacter()
  font["s"] = """
  .....
  .....
  .xxxx
  x....
  .xxx.
  ....x
  xxxx.
  """.skywritingCharacter()
  font["t"] = """
  .x...
  .x...
  xxxxx
  .x...
  .x...
  .x...
  ..xxx
  """.skywritingCharacter()
  font["u"] = """
  .....
  .....
  x...x
  x...x
  x...x
  x...x
  .xxxx
  """.skywritingCharacter()
  font["v"] = """
  .....
  .....
  x...x
  x...x
  x...x
  .x.x.
  ..x..
  """.skywritingCharacter()
  font["w"] = """
  .......
  .......
  x.....x
  x..x..x
  x..x..x
  x..x..x
  .xx.xx.
  """.skywritingCharacter()
  font["x"] = """
  .....
  .....
  x...x
  .x.x.
  ..x..
  .x.x.
  x...x
  """.skywritingCharacter()
  font["y"] = """
  .....
  .....
  x...x
  x...x
  x...x
  x...x
  .xxxx
  ....x
  .xxx.
  """.skywritingCharacter()
  font["z"] = """
  .....
  .....
  xxxxx
  ...x.
  ..x..
  .x...
  xxxxx
  """.skywritingCharacter()
  font["+"] = """
  .....
  ..x..
  ..x..
  xxxxx
  ..x..
  ..x..
  .....
  """.skywritingCharacter()
  font["-"] = """
  .....
  .....
  .....
  xxxxx
  .....
  .....
  .....
  """.skywritingCharacter()
  font["="] = """
  .....
  .....
  xxxxx
  .....
  xxxxx
  .....
  .....
  """.skywritingCharacter()
  font[">"] = """
  .....
  xx...
  ..xx.
  ....x
  ..xx.
  xx...
  .....
  """.skywritingCharacter()
  font["%"] = """
  xx...
  xx..x
  ...x.
  ..x..
  .x...
  x..xx
  ...xx
  """.skywritingCharacter()
  font["/"] = """
  .....
  ....x
  ...x.
  ..x..
  .x...
  x....
  .....
  """.skywritingCharacter()
  return font
}()

// MARK: - Caches for columns of pixels

/// A cache with columns of sprites
///
/// A column in the skywriting display is specified by an integer whose bits
/// correspond to the set pixels.  The lowest bit represents the topmost pixel.
class ColumnCache {
  /// The texture for a pixel
  let texture: SKTexture
  /// The spacing from pixel center to pixel center
  let gridSpacing: CGFloat
  /// The action that the pixels execute
  let rotate: SKAction
  /// All the columns of pixels that have been made
  var allColumns = [Int: [SKNode]]()
  /// The columns that are available for use
  var availableColumns = [Int: [SKNode]]()

  /// Create a cache
  /// - Parameter texture: The texture for the pixel
  init(_ texture: SKTexture) {
    self.texture = texture
    gridSpacing = 1.2 * texture.size().width
    rotate = .repeatForever(.rotate(byAngle: .pi, duration: 1))
  }

  /// Reset a column that may have been previously used
  /// - Parameter column: The potentially-used column
  /// - Returns: The same column but cleaned up and ready for use
  func reset(_ column: SKNode) -> SKNode {
    column.position = .zero
    column.zRotation = -3 * .pi / 2
    column.removeAllActions()
    return column
  }

  /// Return a column for the specified pixels
  /// - Parameter bits: `(bits & (1 << k)) != 0` means pixel `k` (from the top) is set
  /// - Returns: A node with appropriately-positioned pixel sprites as children
  func getColumn(_ bits: Int) -> SKNode {
    if allColumns[bits] == nil {
      allColumns[bits] = []
      availableColumns[bits] = []
    }
    if let column = availableColumns[bits]?.popLast() {
      return reset(column)
    } else {
      let column = SKNode()
      column.name = "skywritingColumn"
      var y = CGFloat(0)
      var remainingBits = bits
      while remainingBits != 0 {
        if (remainingBits & 1) != 0 {
          let sprite = SKSpriteNode(texture: texture)
          sprite.anchorPoint = CGPoint(x: 0.5, y: .random(in: 0.35 ... 0.65))
          sprite.name = "skywritingPixel"
          // The column will run an action to follow a path from right to
          // left. Because I'm using the orient-to-path functionality, the columns
          // zRotation will be set, and it seems to be -3 pi / 2 for whatever
          // reason. Anyway, given that orientation, I have to set the position of
          // the pixel so that when the column gets flipped, the pixel is in the
          // right spot.
          sprite.position = CGPoint(x: y, y: 0)
          sprite.speed = .random(in: 1 ... 3)
          sprite.run(rotate)
          column.addChild(sprite)
        }
        remainingBits >>= 1
        y -= gridSpacing
      }
      allColumns[bits]!.append(column)
      return reset(column)
    }
  }

  /// Return the columns to make up a character
  /// - Parameter char: The character to represent
  /// - Returns: An array of columns that together make a picture of the character
  func columnsForCharacter(_ char: Character) -> [SKNode] {
    var result = [SKNode]()
    if let pixels = skywritingFont[char] {
      for col in 0 ..< pixels[0].count {
        var bits = 0
        for row in 0 ..< pixels.count where pixels[row][col] != "." {
          bits |= 1 << row
        }
        result.append(getColumn(bits))
      }
    }
    return result
  }

  /// Make all columns available for reuse
  func recycle() {
    availableColumns = allColumns
  }

  /// Display some meaningless statistics for debugging
  func stats() {
    var totalColumns = 0
    var totalPixels = 0
    for (_, columns) in allColumns {
      for column in columns {
        totalColumns += 1
        totalPixels += column.children.count
      }
    }
    os_log("Column cache has %d sprites in %d columns", log: .app, type: .debug, totalPixels, totalColumns)
  }
}

/// Column caches for the different colors
let columnCaches: [ColumnCache] = {
  var result = [ColumnCache]()
  for color in ["red", "green", "blue"] {
    let texture = Globals.textureCache.findTexture(imageNamed: "pixel_\(color)")
    result.append(ColumnCache(texture))
  }
  return result
}()

/// Load skywriting column caches with most of what will be needed
func preloadColumnCaches() {
  for cache in columnCaches {
    for (char, _) in skywritingFont {
      _ = cache.columnsForCharacter(char)
    }
    let longFortune = """
    It seems that perfection is reached not when there is nothing left to add, but when there is nothing left to take away.
    """
    for char in longFortune {
      _ = cache.columnsForCharacter(char)
    }
    cache.stats()
  }
}

// MARK: - Skywriting

/// Make some skywriting (or spacewriting) UFOs
///
/// The resulting node is set up so that the message will scroll in from just to the
/// right of the frame (presumably off-screen) and move across until frame left
/// (again, presumably off-screen).
///
/// - Parameters:
///   - message: The message to spell out
///   - frame: The area that should be traversed
/// - Returns: A node for the skywriting and the total time it will take
func skywriting(message: String, frame: CGRect) -> (SKNode, Double) {
  let writing = SKNode()
  writing.name = "skywriting"
  let cache = columnCaches.randomElement()!
  cache.recycle()
  let gridSpacing = cache.gridSpacing
  let path = CGMutablePath()
  path.move(to: .zero)
  let deltaY = 5 * gridSpacing
  let endPoint = CGPoint(x: -frame.width - gridSpacing, y: .random(in: -deltaY ... deltaY))
  let control1 = CGPoint(x: -frame.width / 3, y: .random(in: -deltaY ... deltaY))
  let control2 = CGPoint(x: -2 * frame.width / 3, y: endPoint.y + .random(in: -deltaY ... deltaY))
  path.addCurve(to: endPoint, control1: control1, control2: control2)
  let crossingDuration = Double.random(in: 2.5 ... 4)
  let follow = SKAction.sequence([.follow(path, duration: crossingDuration),
                                  .removeFromParent()])
  let numPixelsHigh = skywritingFont["A"]!.count
  let maxY = max(abs(endPoint.y), abs(control1.y), abs(control2.y))
  writing.position = CGPoint(x: frame.maxX + 0.5 * gridSpacing,
                             y: .random(in: 0.7 * frame.minY + maxY ... 0.7 * frame.maxY - maxY) + CGFloat(numPixelsHigh / 2) * gridSpacing)
  let delayPerColumn = crossingDuration * Double(gridSpacing / abs(endPoint.x))
  var totalDelay = 0.5 * delayPerColumn
  for char in message {
    for column in cache.columnsForCharacter(char) {
      column.run(.wait(for: totalDelay, then: follow))
      writing.addChild(column)
      totalDelay += delayPerColumn
    }
    // One extra column for the spacing between characters
    totalDelay += delayPerColumn
  }
  return (writing, totalDelay + crossingDuration)
}
