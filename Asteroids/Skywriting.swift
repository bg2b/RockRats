//
//  Skywriting.swift
//  Asteroids
//
//  Created by David Long on 12/30/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import os.log

// MARK: Skywriting dimensions

/// The spacing between pixels in the character grid is this factor times the pixel
/// texture size
let skywritingGridSpacing = CGFloat(1.2)

/// The grid height for skywriting characters
///
/// The height here is not arbitrarily adjustable, since things like the number of
/// bits needed to encode the character matrix depend on it
let skywritingGridHeight = 9
/// The grid width for skywriting
///
/// Individual characters can be at most this wide, but may be less
let skywritingGridWidth = 7
/// The number of rows at the bottom of the character matrix for descenders
let skywritingDescenders = 2

// MARK: - Skywriting shader

/// Return a shader that's used for skywriting with a specified pixel texture.
///
/// Details of how this works are documented in the shader source.  To draw the
/// character there's a `skywritingGridWidth` = 7 column by `skywritingGridHeight` =
/// 9 row pixel grid.  That's 7 * 9 = 63 bits to specify a character.  Those 63 bits
/// are given by specifying a vec3 attribute `a_bits`, with 21 bits for each of the
/// vec3's x, y, and z.  The bits correspond to the pixels (on or off), and the
/// ordering of the bits is by rows, lsb-to-msb, left-to-right in a row and then
/// top-to-bottom among rows.  So the single top-left pixel set is `vec3(1, 0, 0)`
/// and the single bottom-right pixel would be `vec3(0, 0, 1<<20)`.  (This sort of
/// thing is why the grid height and width can't be arbitrarily adjusted).
///
/// It's also convenient if the sprite can have a width that's not fixed at
/// `skywritingGridWidth` columns, so there's a second attribute, the float
/// `a_width`.  The integer part of that is the number of columns.  Since there's
/// some extra info available in that float, I also use the fractional part as an
/// offset of u_time for wiggling.  Because the width varies, it's best to set the
/// sprite's anchor point is (0, ...) so that the left edge of the matrix aligns with
/// the character sprite's position.
///
/// To actually make a character, make a sprite that has the pixel as its texture and
/// has size:
///
/// `skywritingGridSpacing * texture.size() * (columns, skywritingGridHeight)`.
///
/// The grid spacing is to allow the pixel some room to wiggle inside the matrix of
/// the character.  Make the anchor point `(0, ...)`.  Set the sprite's shader, and
/// set the `a_bits` attribute according to the bit pattern of the character.  Set
/// `a_width` to `columns` (plus a random fractional part between 0 and 1 if
/// desired).
///
/// The shader depends on the pixel texture if the texture happens to be part of an
/// atlas.  The same shader can be used for all pixel textures if they're not in an
/// atlas.
///
/// - Parameter texture: The pixel texture
func skywritingShader(texture: SKTexture) -> SKShader {
  // Don't assume the texture is indexed by (0,0)-(1,1).  That's not true for
  // textures that are in an atlas.
  let rect = texture.textureRect()
  let shaderSource = """
  void main() {
    // Convert to (0,0)-(1,1)
    v_tex_coord -= vec2(\(rect.origin.x), \(rect.origin.y));
    v_tex_coord *= vec2(\(1 / rect.size.width), \(1 / rect.size.height));
    // Scale to width column by 9 row grid
    vec2 scaled = v_tex_coord * vec2(floor(a_width) - 0.001, 8.999);
    // Get row and column coordinates
    int col = int(scaled.x);
    int row = int(scaled.y);
    // Grab the appropriate bits determining the character
    // 3 * 7 = 21 bits are used per float in a_bits
    int bits = int(a_bits[row / 3]);
    // See if the bit for (col,row) is set
    int bitmask = (1 << ((7 * (row % 3)) + col));
    if ((bits & bitmask) == 0) {
      // Pixel is off at this position for the character
      gl_FragColor = vec4(0.0);
    } else {
      // Pixel is on, compute index into texture
      // This is basically fract(scaled), but I want
      // to make the pixel wiggle some too, so make
      // four random numbers in 0-1.
      int index = 9 * col + row;
      float const one64th = 1.0 / 64.0;
      float rand1 = ((index * 23) & 63) * one64th;
      float rand2 = ((index * 11) & 63) * one64th;
      float rand3 = ((index * 47) & 63) * one64th;
      float rand4 = ((index * 41) & 63) * one64th;
      // Wiggle angular frequency is something in the pi-ish range
      vec2 theta = vec2(rand1, rand2) * (2.0 * 3.14 * (u_time + fract(a_width)));
      // Allows wiggles of 1/10th of the grid spacing
      vec2 dxy = \(skywritingGridSpacing / 10) * vec2(rand3, rand4);
      vec2 wiggle = dxy * cos(theta);
      // Finally, the wiggling coordinate
      v_tex_coord = fract(scaled) + wiggle;
      // Shrink the texture a bit so that it doesn't quite
      // fill the cell
      v_tex_coord -= 0.5;
      v_tex_coord *= \(skywritingGridSpacing);
      v_tex_coord += 0.5;
      // Finally I can get the desired texture pixel
      if (v_tex_coord.x < 0.0 || v_tex_coord.x > 1.0 || v_tex_coord.y < 0.0 || v_tex_coord.y > 1.0) {
        // Outside the texture bounds
        gl_FragColor = vec4(0.0);
      } else {
        // Within texture bounds, translate (0,0)-(1,1) to textureRect
        v_tex_coord *= vec2(\(rect.size.width), \(rect.size.height));
        v_tex_coord += vec2(\(rect.origin.x), \(rect.origin.y));
        // Elementary, my dear Watson, elementary...
        gl_FragColor = texture2D(u_texture, v_tex_coord);
      }
    }
  }
  """
  let shader = SKShader(source: shaderSource)
  shader.attributes = [SKAttribute(name: "a_bits", type: .vectorFloat3),
                       SKAttribute(name: "a_width", type: .float)]
  return shader
}

// MARK: - Font

/// A character matrix for skywriting
struct SkywritingCharacter {
  /// The width of the matrix (max `skywritingGridWidth`)
  let width: Int
  /// The appropriate value for the `a_bits` attribute in the shader
  let bits: SKAttributeValue
}

extension String {
  func skywritingCharacter() -> SkywritingCharacter {
    var rows = self.split(separator: "\n").map { String($0) }
    assert(rows.count <= skywritingGridHeight && rows[0].count <= skywritingGridWidth)
    // Rows don't have to be the same length for the encoding below.  This is just a
    // sanity check to make sure that I typed out the bit pattern as intended.
    assert(rows.allSatisfy { $0.count == rows[0].count })
    // Pad with empty rows to full height
    while rows.count < skywritingGridHeight {
      rows.append("")
    }
    let rowBits: [Float] = (0 ..< 3).map { rowGroup in
      var result = 0
      for groupIndex in 0 ..< 3 {
        var bitmask = 1 << (skywritingGridWidth * groupIndex)
        for char in rows[3 * rowGroup + groupIndex] {
          if char != "." {
            result |= bitmask
          }
          bitmask <<= 1
        }
      }
      return Float(result)
    }
    assert(rowBits.count == 3)
    return SkywritingCharacter(width: rows[0].count, bits: SKAttributeValue(vectorFloat3: vector_float3(rowBits)))
  }
}

/// The skywriting font
///
/// Each character should start from the top left.  The characters don't have to be
/// the same width or same height though.  Each row within a character should be the
/// same length.  And the character must fit within the `skywritingGridWidth` by
/// `skywritingGridHeight` grid.
let skywritingFont: [Character: SkywritingCharacter] = {
  var font = [Character: SkywritingCharacter]()
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
  font["^"] = """
  ..x..
  .x.x.
  x...x
  .....
  .....
  .....
  .....
  """.skywritingCharacter()
  return font
}()

// MARK: - Caches for skywriting

/// A cache for character sprites
///
/// These get recycled all at once for a message
class SkywritingCharacterCache {
  /// The texture for a pixel
  let texture: SKTexture
  /// The shader used for the pixel texture
  let shader: SKShader
  /// The spacing from pixel center to pixel center
  let gridSpacing: CGFloat
  /// All the characters that have been made
  var allCharacters = [Character: [SKNode]]()
  /// The characters that are available for use
  var availableCharacters = [Character: [SKNode]]()

  /// Create a cache
  /// - Parameter texture: The texture for the pixel
  init(_ texture: SKTexture) {
    self.texture = texture
    // I'm assume a square texture
    assert(texture.size().width == texture.size().height)
    shader = skywritingShader(texture: texture)
    gridSpacing = skywritingGridSpacing * texture.size().width
  }

  /// Reset a character that may have been previously used
  /// - Parameter charNode: The SKNode that represesents the character
  /// - Returns: The same character but cleaned up and ready for use, plus the width
  ///   in units of `gridSpacing`
  func reset(_ charNode: SKNode) -> SKNode {
    charNode.position = .zero
    // The zRotation is because I'm using the orient-to-path option in path following
    // as the letters fly along.  I'm not sure how it determines what "oriented"
    // means, but for characters moving left-to-right, it seems to want to set the
    // rotation to pi/2 or -3pi/2 (same thing).  That would result in characters
    // lying on the their side, which is hard to read.  So the characters are wrapped
    // in another SKNode whose orientation is pi/2, and the characters within that
    // have a zRotation of -pi/2 to cancel out the undesired rotation.
    charNode.zRotation = .pi / 2
    charNode.removeAllActions()
    return charNode
  }

  /// Return a sprite for the character
  /// - Parameter char: The character
  /// - Returns: A node that will display the (animated) character, and the width of the
  ///   character in units of `gridSpacing`
  func getCharacter(_ char: Character) -> SKNode {
    if allCharacters[char] == nil {
      allCharacters[char] = []
      availableCharacters[char] = []
    }
    if let charNode = availableCharacters[char]?.popLast() {
      return reset(charNode)
    } else {
      let charNode = SKNode()
      charNode.name = "skywritingCharacter"
      guard let charInfo = skywritingFont[char] else { fatalError("Skywriting font is missing character \(char)") }
      let spriteSize = CGSize(width: CGFloat(charInfo.width) * gridSpacing, height: 9 * gridSpacing)
      let sprite = SKSpriteNode(texture: texture, size: spriteSize)
      sprite.shader = shader
      sprite.setValue(charInfo.bits, forAttribute: "a_bits")
      let width = Float(charInfo.width) + .random(in: 0 ... 1)
      sprite.setValue(SKAttributeValue(float: width), forAttribute: "a_width")
      // Cancel out undesired effect from orient-to-path (see remark above)
      sprite.zRotation = -.pi / 2
      // Align characters by their left edge and top
      sprite.anchorPoint = CGPoint(x: 0, y: 1)
      charNode.addChild(sprite)
      allCharacters[char]!.append(charNode)
      return reset(charNode)
    }
  }

  /// Make all characters available
  func recycle() {
    availableCharacters = allCharacters
  }

  /// Display some meaningless statistics for debugging
  func stats() {
    var totalChars = 0
    for (_, chars) in allCharacters {
      totalChars += chars.count
    }
    os_log("Skywriting character cache has %d entries", log: .app, type: .debug, totalChars)
  }
}

/// Character caches for the different colors
let skywritingCharacterCaches: [SkywritingCharacterCache] = {
  var result = [SkywritingCharacterCache]()
  for color in ["red", "green", "blue"] {
    let texture = Globals.textureCache.findTexture(imageNamed: "pixel_\(color)")
    result.append(SkywritingCharacterCache(texture))
  }
  return result
}()

/// Load skywriting column caches with most of what will be needed
func preloadSkywritingCaches() {
  for cache in skywritingCharacterCaches {
    // One of everything
    for (char, _) in skywritingFont {
      _ = cache.getCharacter(char)
    }
    // Extra letters, plus common ones more than once
    let letters = "AAABCCDDEEEEFGHIIJKLLMMNNOOPPQRRRSSSTTTTUUVWXYZ"
    for char in letters {
      _ = cache.getCharacter(char)
    }
    for char in letters.lowercased() {
      _ = cache.getCharacter(char)
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
  let cache = skywritingCharacterCaches.randomElement()!
  cache.recycle()
  let gridSpacing = cache.gridSpacing
  let path = CGMutablePath()
  path.move(to: .zero)
  let deltaY = 5 * gridSpacing
  // The endpoint x for the path needs to be far enough off the screen that the
  // entirety of the widest characters will be completely hidden when they reach the
  // end of the path.
  let endPoint = CGPoint(x: -frame.width - CGFloat(skywritingGridWidth + 1) * gridSpacing, y: .random(in: -deltaY ... deltaY))
  let control1 = CGPoint(x: -frame.width / 3, y: .random(in: -deltaY ... deltaY))
  let control2 = CGPoint(x: -2 * frame.width / 3, y: endPoint.y + .random(in: -deltaY ... deltaY))
  path.addCurve(to: endPoint, control1: control1, control2: control2)
  let crossingDuration = Double.random(in: 3.5 ... 5)
  let delayPerColumn = crossingDuration * Double(gridSpacing / abs(endPoint.x))
  let follow = SKAction.sequence([.follow(path, duration: crossingDuration),
                                  .removeFromParent()])
  // The tops of the character cells are aligned at their 0.  I want to put the
  // middle of the uppercase letters on what's conceptually the centerline.  So if
  // the y for writing is supposed to be at 0, then I want the characters to be
  // shifted up by half of the uppercase height.
  let numPixelsHigh = skywritingGridHeight - skywritingDescenders
  let maxY = max(abs(endPoint.y), abs(control1.y), abs(control2.y))
  writing.position = CGPoint(x: frame.maxX + 0.5 * gridSpacing,
                             y: .random(in: 0.7 * frame.minY + maxY ... 0.7 * frame.maxY - maxY) + CGFloat(numPixelsHigh / 2) * gridSpacing)
  var totalDelay = 0.5 * delayPerColumn
  for char in message {
    guard let charInfo = skywritingFont[char] else {
      os_log("Missing character %{public}s in skywriting font", log: .app, type: .error, String(char))
      continue
    }
    let charNode = cache.getCharacter(char)
    charNode.run(.wait(for: totalDelay, then: follow))
    writing.addChild(charNode)
    totalDelay += Double(charInfo.width + 1) * delayPerColumn
  }
  return (writing, totalDelay + crossingDuration)
}
