//
//  Hyperspace.swift
//  Asteroids
//
//  Created by David Long on 9/6/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import os.log

// MARK: Stuff for u_time

// Notes about u_time and shaders...
//
// It seems that u_time is zero when it first gets used in some shader.  All well and
// good.  When I write an effect like the hyperspace shaders, they'll do some sort of
// warping over time.  For example, going into hyperspace has the sprite unwarped at
// u_time = 0 and then start twisting as u_time increases.
//
// The problem is that when I use the shader a second time, u_time doesn't go back to
// zero.  It's like a clock that started with the first shader use, and it just keeps
// running in the background.
//
// Worse, it applies to all shaders, not just ones that I want to reuse.  So I can't
// simply create a shader that wants u_time = 0, use it, and then throw it away.
//
// What I can do is learn the offset between u_time and the time passed to update(_:
// TimeInterval).  The first time that a shader gets used (when u_time is guaranteed
// to be 0), I can save the offset.  After that, when I need to invoke a shader that
// would want u_time = 0, I instead refer to u_time - offset.  The offset can be
// passed in by a shader attribute.  That's the whole a_start_time business.
//
// The one wrinkle is that it seems that it's somehow possible for there to be a
// drift between u_time and the time passed to update().  How I don't know, but I had
// at least one occasion where I had quit the app (gone to the iPad home screen) and
// then come back to it a couple of days later.  When I did, the shader effects that
// relied on u_time - offset = 0 were screwed up.  So I needed to come up with a way
// to get whatever u_time the shaders were using.  That's done with the utimeShader
// stuff.
//
// utimeShader is a shader that encodes u_time in the three components of a pixel
// color.  I need fractions of a second, so I multiply u_time by 128 (iPad Pro
// refresh is 120 Hz) and then peel off 24 bits of precision to store in R, G, and B.
// To get that color out, I use SKView's texture(from: SKnode) method.  I take a tiny
// sprite (a 2x2 square, but 1x1 might be OK too) and then render that into a
// texture.  The texture is converted into a pixel array with the TextureBitmap
// struct.  Then readUtime takes the first pixel and reverses the encoding process to
// get the u_time that the utimeShader saw.  I reset the saved utimeOffset each time
// I do a scene transition or when the app becomes active.  The update(_:
// TimeInterval) in BasicScene calls getUtimeOffset each time through; that will do
// readUtime once and then cache the value of the offset.

/// The shader used for reading `u_time`
var utimeShader = SKShader(source:
  """
  void main() {
    uint32_t time = round(u_time * 128 + 0.5);
    // Encode u_time in RGB values
    float red = (time & 0xff) / 255.0;
    time >>= 8;
    float green = (time & 0xff) / 255.0;
    time >>= 8;
    float blue = (time & 0xff) / 255.0;
    gl_FragColor = vec4(red, green, blue, 1.0);
  }
  """
)

/// Read the `u_time` value that a shader would see
/// - Parameter view: A view used to render a test sprite
/// - Returns: The `u_time` that a shader saw
func readUtime(view: SKView) -> Double {
  // Make a little sprite that runs utimeShader and render it into a texture.
  let dotTexture = Globals.textureCache.findTexture(imageNamed: "dot")
  let sprite = SKSpriteNode(texture: dotTexture, size: dotTexture.size())
  sprite.shader = utimeShader
  guard let rendered = view.texture(from: sprite) else {
    os_log("readUtime failed to render shaded sprite", log: .app, type: .error)
    return 0
  }
  // Convert the texture into a bitmap
  let bitmap = TextureBitmap<UInt32>(texture: rendered) { $0 }
  // Decode the first pixel to reconstruct u_time
  var pixel = bitmap.pixels[0]
  var result = 0.0
  pixel >>= 8
  result += Double(pixel & 0xff)
  pixel >>= 8
  result *= 256
  result += Double(pixel & 0xff)
  pixel >>= 8
  result *= 256
  result += Double(pixel & 0xff)
  result /= 128
  os_log("u_time in shaders is %f", log: .app, type: .debug, result)
  return result
}

/// The offset between `u_time` and the current game time
///
/// When about to run a shader that wants `u_time` to start from zero, add this to
/// `Globals.lastUpdateTime` and pass the result to the shader as an attribute
/// `a_start_time`.  In the shader, subtract `a_start_time` from `u_time` to get the
/// effective time from shader invocation.
var utimeOffset: Double?

/// Compute `utimeOffset` if needed, then return that value
/// - Parameter view: A view to render a sprite if `utimeOffset` needs to be calculated
/// - Returns: `utimeOffset`
func getUtimeOffset(view: SKView?) -> Double {
  if let utimeOffset = utimeOffset {
    // The view can be nil when it's guaranteed that utimeOffset will have already
    // been computed
    return utimeOffset
  }
  guard let view = view else {
    os_log("No view to set utime offset", log: .app, type: .debug)
    return 0
  }
  let newOffset = readUtime(view: view) - Globals.lastUpdateTime
  os_log("utimeOffset set to %f at time %f", log: .app, type: .debug, newOffset, Globals.lastUpdateTime)
  utimeOffset = newOffset
  return newOffset
}

/// Reset `utimeOffset` so that it'll be recomputed
///
/// Call this on scene switch or when the app transitions from background to
/// foreground state.
func resetUtimeOffset() {
  utimeOffset = nil
}

/// Set the `a_state_time` attribute for a sprite's shader
/// - Parameters:
///   - effect: The sprite that the shader is attached to
///   - view: A view for computing `utimeOffset` (`nil` is OK if `utimeOffset` has
///     already been computed)
func setStartTimeAttrib(_ effect: SKSpriteNode, view: SKView?) {
  // The view parameter can only be nil if something else has already called
  // getUtimeOffset with a real view.
  let startUtime = Globals.lastUpdateTime + getUtimeOffset(view: view)
  effect.setValue(SKAttributeValue(float: Float(startUtime)), forAttribute: "a_start_time")
}

// MARK: - Hyperspace shaders

/// The amount of time for warp effects
let warpTime = 0.5

/// A down-the-drain (or reverse of that) shader, used when the player jumps to
/// hyperspace
/// - Parameters:
///   - texture: The texture to animate
///   - inward: `true` for shrinking effect, `false` for the reverse
/// - Returns: A shader for the effect
func swirlShader(forTexture texture: SKTexture, inward: Bool) -> SKShader {
  // Be careful not to assume that the texture has v_tex_coord ranging in (0, 0) to
  // (1, 1)!  If the texture is part of a texture atlas, this is not true.  I could
  // make another attribute or uniform to pass in the textureRect info, but since I
  // only use this with a particular texture, I just pass in the texture and compile
  // in the required v_tex_coord transformations for that texture.
  //
  // I still have some residual confusion about coordinate spaces in these things.
  // If you look in the tiling shader used for the background star field, v_tex_coord
  // on input corresponded to a position in the frame that was normalized to
  // (0,0)-(1,1).  In that case I shifted and scaled only on output when the
  // coordinate was being used to index into the tiled texture.  In this case, it's a
  // texture for a sprite node that I'm warping, and the input coordinate seems to be
  // in terms of the textureRect coordinates too.  So I have to inverse transform to
  // get to (0,0)-(1,1), do my stuff, and then transform back again to textureRect.
  let rect = texture.textureRect()
  let shaderSource = """
  void main() {
    // Time goes 0-1
    float dt = min((u_time - a_start_time) / \(warpTime), 1.0);
    // Size goes 0-1 for expanding, and 1-0 for shrinking
    float size = \(inward ? "1.0 - " : "")dt;
    // The maximum rotation is about a full angular turn, and
    // the direction is reversed.  Rotation is at a maximum when the
    // sprite is smallest and is 0 when the sprite is full size.
    float max_rot = \(inward ? 6.0 : -6.0) * (1.0 - size);
    // Normalize coordinates to (0,0)-(1,1)
    v_tex_coord -= vec2(\(rect.origin.x), \(rect.origin.y));
    v_tex_coord *= vec2(\(1 / rect.size.width), \(1 / rect.size.height));
    // Compute distance from (0.5,0.5)
    float p = min(distance(v_tex_coord, vec2(0.5, 0.5)) * 2.0, 1.0);
    if (p > size) {
      // Outside the current size, clear
      gl_FragColor = vec4(0.0);
    } else {
      // Renormalize coordinates to (-1,-1)-(1,1)
      v_tex_coord -= 0.5;
      v_tex_coord *= 2.0;
      v_tex_coord /= size + 0.001;
      // Rotate
      float rot = max_rot * (1.0 - p);
      float c = cos(rot);
      float s = sin(rot);
      v_tex_coord = vec2(c * v_tex_coord.x + s * v_tex_coord.y, -s * v_tex_coord.x + c * v_tex_coord.y);
      // Switch back to (0,0)-(1,1)
      v_tex_coord /= 2.0;
      v_tex_coord += 0.5;
      // And then back to the actual coordinates for the real texture
      v_tex_coord *= vec2(\(rect.size.width), \(rect.size.height));
      v_tex_coord += vec2(\(rect.origin.x), \(rect.origin.y));
      gl_FragColor = texture2D(u_texture, v_tex_coord);
    }
  }
  """
  let shader = SKShader(source: shaderSource)
  shader.attributes = [SKAttribute(name: "a_start_time", type: .float)]
  return shader
}

/// A shrink effect with disappearing sections
///
/// I use this for UFOs because the `swirlShader` doesn't look like much for a
/// circular shape.  This one doesn't have a reverse direction because UFOs don't
/// warp in.
///
/// - Parameters:
///   - texture: The texture to warp
/// - Returns: A shader for the effect
func fanFoldShader(forTexture texture: SKTexture) -> SKShader {
  let rect = texture.textureRect()
  let shaderSource = """
  void main() {
    // Time goes 0-1
    float dt = min((u_time - a_start_time) / \(warpTime), 1.0);
    // The sprite shrinks to size 0 at time 1
    float size = 1.0 - dt;
    // Normalize coordinates to (0,0)-(1,1)
    v_tex_coord -= vec2(\(rect.origin.x), \(rect.origin.y));
    v_tex_coord *= vec2(\(1 / rect.size.width), \(1 / rect.size.height));
    // Compute distance from (0.5,0.5)
    float p = min(distance(v_tex_coord, vec2(0.5, 0.5)) * 2.0, 1.0);
    if (p > size) {
      // Outside the current size, clear
      gl_FragColor = vec4(0.0);
    } else {
      // Normalize to (-1,-1)-(1,1)
      v_tex_coord -= 0.5;
      v_tex_coord *= 2.0;
      v_tex_coord /= size + 0.001;
      // Rotate by pi at full shrinkage and by 0 at full size,
      // so that the sprite looks normal when full size.
      float rot = 3.14159 * dt;
      float c = cos(rot);
      float s = sin(rot);
      v_tex_coord = vec2(c * v_tex_coord.x + s * v_tex_coord.y, -s * v_tex_coord.x + c * v_tex_coord.y);
      // See what angle is after rotation
      float angle = atan2(v_tex_coord.y, v_tex_coord.x);
      // The sprite gets cut by expanding "wedges" as it shrinks
      if (fract(3.0 * angle / 3.14159) < dt) {
        // Inside a wedge, clear
        gl_FragColor = vec4(0.0);
      } else {
        // Outside a wedge, normalize back to (0,0)-(1,1)
        v_tex_coord /= 2.0;
        v_tex_coord += 0.5;
        // And then to the actual texture coordinates
        v_tex_coord *= vec2(\(rect.size.width), \(rect.size.height));
        v_tex_coord += vec2(\(rect.origin.x), \(rect.origin.y));
        gl_FragColor = texture2D(u_texture, v_tex_coord);
      }
    }
  }
  """
  let shader = SKShader(source: shaderSource)
  shader.attributes = [SKAttribute(name: "a_start_time", type: .float)]
  return shader
}

/// A twinkle sort of effect with a growing-then-shrinking-while-twirling star
/// - Parameters:
///   - position: The position where the effect should happen
///   - angle: Amount to twirl in radians
/// - Returns: A sprite that animates the effect
func starBlink(at position: CGPoint, throughAngle angle: CGFloat, duration: Double) -> SKSpriteNode {
  let star = SKSpriteNode(imageNamed: "star1")
  star.position = position
  star.scale(to: CGSize(width: 0, height: 0))
  star.run(.sequence([.group([.sequence([.scale(to: 2, duration: 0.5 * duration),
                                         .scale(to: 0, duration: 0.5 * duration)]),
                              .rotate(byAngle: angle, duration: duration)]),
                      .removeFromParent()]))
  return star
}

// MARK: - Shader caches

/// A cache for various types of texture-dependent shaders
class ShaderCache {
  /// The function that makes the shader for a given texture
  let builder: (_ texture: SKTexture) -> SKShader
  /// A dictionary holding the constructed shaders
  var shaders = [SKTexture: SKShader]()

  /// Create a new shader cache
  /// - Parameter builder: A closure that constructs the shader for a given texture
  init(builder: @escaping (_ texture: SKTexture) -> SKShader) {
    self.builder = builder
  }

  /// Get the shader for a texture if it exists
  /// - Parameter texture: The texture
  /// - Returns: The shader if it exists, else `nil`
  func findShader(texture: SKTexture) -> SKShader? {
    return shaders[texture]
  }

  /// Get the shader corresponding to a texture
  /// - Parameter texture: The texture
  /// - Returns: The shader for effect specialized to the texture
  func getShader(texture: SKTexture) -> SKShader {
    if let result = shaders[texture] {
      return result
    }
    let result = builder(texture)
    shaders[texture] = result
    return result
  }
}

extension Globals {
  static let swirlInShaders = ShaderCache { swirlShader(forTexture: $0, inward: true) }
  static let swirlOutShaders = ShaderCache { swirlShader(forTexture: $0, inward: false) }
  static let fanFoldShaders = ShaderCache { fanFoldShader(forTexture: $0) }
}

func precompileShaders() {
  for imageName in ["ship_blue", "ship_green", "ship_red", "ship_orange", "retroship"] {
    let texture = Globals.textureCache.findTexture(imageNamed: imageName)
    _ = Globals.swirlInShaders.getShader(texture: texture)
    _ = Globals.swirlOutShaders.getShader(texture: texture)
  }
  for imageName in ["ufo_green", "ufo_blue", "ufo_red"] {
    let texture = Globals.textureCache.findTexture(imageNamed: imageName)
    _ = Globals.fanFoldShaders.getShader(texture: texture)
  }
}

// MARK: - Create hyperspace effects

func warpOutEffect(texture: SKTexture, position: CGPoint, rotation: CGFloat) -> [SKNode] {
  let shader = Globals.swirlInShaders.findShader(texture: texture) ?? Globals.fanFoldShaders.getShader(texture: texture)
  let effect = SKSpriteNode(texture: texture)
  effect.name = "warpOutEffect"
  effect.position = position
  effect.zRotation = rotation
  effect.shader = shader
  setStartTimeAttrib(effect, view: nil)
  effect.run(.wait(for: warpTime, then: .removeFromParent()))
  let star = starBlink(at: position, throughAngle: .pi, duration: 2 * warpTime)
  return [effect, star]
}

func warpInEffect(texture: SKTexture, position: CGPoint, rotation: CGFloat, whenDone: @escaping () -> Void) -> SKNode {
  let shader = Globals.swirlOutShaders.getShader(texture: texture)
  let effect = SKSpriteNode(texture: texture)
  effect.name = "warpInEffect"
  effect.position = position
  effect.zRotation = rotation
  effect.shader = shader
  setStartTimeAttrib(effect, view: nil)
  effect.run(.wait(for: warpTime, then: .removeFromParent()), completion: whenDone)
  return effect
}
