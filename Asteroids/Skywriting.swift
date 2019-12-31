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
  xxx..
  x....
  x....
  xxxxx
  """.skywritingCharacter()
  font["F"] = """
  xxxxx
  x....
  x....
  xxx..
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
  let color = ["green", "blue", "red"].randomElement()!
  let texture = Globals.textureCache.findTexture(imageNamed: "ufo_\(color)")
  let pixelSize = CGFloat(5) // CGFloat.random(in: 5 ... 10)
  let gridSpacing = 1.2 * pixelSize
  let scaling = pixelSize / texture.size().width
  let spriteSize = texture.size().scale(by: scaling)
  let path = CGMutablePath()
  path.move(to: .zero)
  let deltaY = 5 * gridSpacing
  let endPoint = CGPoint(x: -frame.width - gridSpacing, y: .random(in: -deltaY ... deltaY))
  let control1 = CGPoint(x: -frame.width / 3, y: .random(in: -deltaY ... deltaY))
  let control2 = CGPoint(x: -2 * frame.width / 3, y: endPoint.y + .random(in: -deltaY ... deltaY))
  path.addCurve(to: endPoint, control1: control1, control2: control2)
  let crossingDuration = Double.random(in: 2.5 ... 4)
  let follow = SKAction.sequence([.follow(path, asOffset: true, orientToPath: false, duration: crossingDuration),
                                  .removeFromParent()])
  let numPixelsHigh = skywritingFont["A"]!.count
  let maxY = max(abs(endPoint.y), abs(control1.y), abs(control2.y))
  writing.position = CGPoint(x: frame.maxX + 0.5 * gridSpacing,
                             y: .random(in: 0.7 * frame.minY + maxY ... 0.7 * frame.maxY - maxY) + CGFloat(numPixelsHigh / 2) * gridSpacing)
  var wigglesX = [SKAction]()
  var wigglesY = [SKAction]()
  for _ in 0 ..< 4 {
    let wiggle = 0.2 * gridSpacing
    let durationX = Double.random(in: 0.3 ... 1)
    let wiggleX = SKAction.move(by: CGVector(dx: .random(in: -wiggle ... wiggle), dy: 0), duration: durationX)
    wiggleX.timingMode = .easeInEaseOut
    let durationY = Double.random(in: 0.3 ... 1)
    wigglesX.append(.repeatForever(.sequence([wiggleX, wiggleX.reversed()])))
    let wiggleY = SKAction.move(by: CGVector(dx: 0, dy: .random(in: -wiggle ... wiggle)), duration: durationY)
    wiggleY.timingMode = .easeInEaseOut
    wigglesY.append(.repeatForever(.sequence([wiggleY, wiggleY.reversed()])))
  }
  let delayPerColumn = crossingDuration * Double(gridSpacing / abs(endPoint.x))
  var totalDelay = 0.5 * delayPerColumn
  for char in message {
    guard let pixels = skywritingFont[char] else { continue }
    for col in 0 ..< pixels[0].count {
      let column = SKNode()
      column.name = "skywritingColumn"
      for row in 0 ..< pixels.count where pixels[row][col] != "." {
        let sprite = SKSpriteNode(texture: texture, size: spriteSize)
        sprite.name = "skywritingPixel"
        sprite.position = CGPoint(x: 0, y: -CGFloat(row) * gridSpacing)
        sprite.zRotation = .random(in: 0 ... 2 * .pi)
        sprite.run(.group([wigglesX.randomElement()!, wigglesY.randomElement()!]))
        column.addChild(sprite)
      }
      column.run(.wait(for: totalDelay, then: follow))
      writing.addChild(column)
      totalDelay += delayPerColumn
    }
    totalDelay += delayPerColumn
  }
  return (writing, totalDelay + crossingDuration)
}
