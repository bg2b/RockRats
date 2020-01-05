//
//  Shaders.swift
//  Asteroids
//
//  Created by David Long on 1/5/20.
//  Copyright © 2020 David Long. All rights reserved.
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

/// Recompute `utimeOffset` using a view
///
/// This gets called during scene switches when I've got a view available.
///
/// - Parameter view: The view to use
func resetUtimeOffset(view: SKView) {
  resetUtimeOffset()
  _ = getUtimeOffset(view: view)
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
