//
//  Hyperspace.swift
//  Asteroids
//
//  Created by David Long on 9/6/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

struct TextureBitmap<T> {
  let textureSize: CGSize
  let width: Int
  let height: Int
  let pixels: [T]

  init(texture: SKTexture, getPixelInfo: (UInt32) -> T) {
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
    pixels = (0 ..< width * height).map {
      return getPixelInfo((data + 4 * $0).load(as: UInt32.self))
    }
  }
}

// Notes about u_time...
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
// to be 0), we can save the offset.  After that, when we need to invoke a shader
// that would want u_time = 0, we instead refer to u_time - offset.  The offset can
// be passed in by a shader attribute.  That's the whole a_start_time business.
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
// To get that color out, I use SKView's texture(from: SKnode) method.  I make a tiny
// sprite (a 2x2 square, but 1x1 might be OK too) and then render that into a
// texture.  The texture is converted into a pixel array with the TextureBitmap
// struct.  Then readUtime takes the first pixel and reverses the encoding process to
// get the u_time that the utimeShader saw.  We reset the saved utimeOffset each time
// we do a scene transition or when the app becomes active.  The update(_:
// TimeInterval) in BasicScene calls getUtimeOffset each time through; that will do
// readUtime once and then cache the value of the offset.

var utimeShader = SKShader(source:
  """
  void main() {
    uint32_t time = round(u_time * 128 + 0.5);
    float red = (time & 0xff) / 255.0;
    time >>= 8;
    float green = (time & 0xff) / 255.0;
    time >>= 8;
    float blue = (time & 0xff) / 255.0;
    gl_FragColor = vec4(red, green, blue, 1.0);
  }
  """
)

func readUtime(view: SKView) -> Double {
  let dotTexture = Globals.textureCache.findTexture(imageNamed: "dot")
  let sprite = SKSpriteNode(texture: dotTexture, size: dotTexture.size())
  sprite.shader = utimeShader
  guard let rendered = view.texture(from: sprite) else {
    logging("readUtime failed to render shaded sprite")
    return 0
  }
  let bitmap = TextureBitmap<UInt32>(texture: rendered) { $0 }
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
  logging("u_time in shaders is \(result)")
  return result
}

var utimeOffset: Double?

func getUtimeOffset(view: SKView?) -> Double {
  if let utimeOffset = utimeOffset {
    return utimeOffset
  }
  guard let view = view else {
    logging("No view to set utime offset")
    return 0
  }
  let newOffset = readUtime(view: view) - Globals.lastUpdateTime
  logging("utimeOffset set to \(newOffset) at time \(Globals.lastUpdateTime)")
  utimeOffset = newOffset
  return newOffset
}

func resetUtimeOffset() {
  utimeOffset = nil
}

func setStartTimeAttrib(_ effect: SKSpriteNode, view: SKView?) {
  // The view parameter can only be nil if something else has already called
  // getUtimeOffset with a real view.
  let startUtime = Globals.lastUpdateTime + getUtimeOffset(view: view)
  effect.setValue(SKAttributeValue(float: Float(startUtime)), forAttribute: "a_start_time")
}

func swirlShader(forTexture texture: SKTexture, inward: Bool, warpTime: Double) -> SKShader {
  // This one is a sort of down-the-drain effect (or the reverse of it).
  //
  // The a_start_time ugliness is because u_time starts from 0 when a shader first
  // references it, but after that it just keeps counting up.  We have to be able to
  // shift it so that it effectively starts from 0 each time we use a shader.
  //
  // Also be careful not to assume that the texture has v_tex_coord ranging in (0, 0)
  // to (1, 1)!  If the texture is part of a texture atlas, this is not true.  We
  // could make another attribute or uniform to pass in the textureRect info, but
  // since we only use this with a particular texture, we just pass in the texture
  // and compile in the required v_tex_coord transformations for that texture.
  //
  // I still have some residual confusion about coordinate spaces in these things.
  // If you look in the tiling shader used for the background star field, v_tex_coord
  // on input corresponded to a position in the frame that was normalized to
  // (0,0)-(1,1).  In that case we shifted and scaled only on output when the
  // coordinate was being used to index into the tiled texture.  In this case, it's a
  // texture for a sprite node that we're warping, and the input coordinate seems to
  // be in terms of the textureRect coordinates too.  So we have to inverse transform
  // to get to (0,0)-(1,1), do our stuff, and then transform back again to
  // textureRect.
  let rect = texture.textureRect()
  let shaderSource = """
  void main() {
    float dt = min((u_time - a_start_time) / \(warpTime), 1.0);
    float size = \(inward ? "1.0 - " : "")dt;
    float max_rot = \(inward ? 6.0 : -6.0) * (1.0 - size);
    v_tex_coord -= vec2(\(rect.origin.x), \(rect.origin.y));
    v_tex_coord *= vec2(\(1 / rect.size.width), \(1 / rect.size.height));
    float p = min(distance(v_tex_coord, vec2(0.5, 0.5)) * 2.0, 1.0);
    if (p > size) {
      gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
      v_tex_coord -= 0.5;
      v_tex_coord *= 2.0;
      v_tex_coord /= size + 0.001;
      float rot = max_rot * (1.0 - p);
      float c = cos(rot);
      float s = sin(rot);
      v_tex_coord = vec2(c * v_tex_coord.x + s * v_tex_coord.y, -s * v_tex_coord.x + c * v_tex_coord.y);
      v_tex_coord /= 2.0;
      v_tex_coord += 0.5;
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

func fanFoldShader(forTexture texture: SKTexture, warpTime: Double) -> SKShader {
  // This one is a shrink but also sections disappear.  We use it for UFOs because
  // the swirl effect doesn't look like much when the shape is mostly circular.
  let rect = texture.textureRect()
  let shaderSource = """
  void main() {
    float dt = min((u_time - a_start_time) / \(warpTime), 1.0);
    float size = 1.0 - dt;
    v_tex_coord -= vec2(\(rect.origin.x), \(rect.origin.y));
    v_tex_coord *= vec2(\(1 / rect.size.width), \(1 / rect.size.height));
    float p = min(distance(v_tex_coord, vec2(0.5, 0.5)) * 2.0, 1.0);
    if (p > size) {
      gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
      v_tex_coord -= 0.5;
      v_tex_coord *= 2.0;
      v_tex_coord /= size + 0.001;
      float rot = 3.14159 * dt;
      float c = cos(rot);
      float s = sin(rot);
      v_tex_coord = vec2(c * v_tex_coord.x + s * v_tex_coord.y, -s * v_tex_coord.x + c * v_tex_coord.y);
      float angle = atan2(v_tex_coord.y, v_tex_coord.x);
      if (fract(3.0 * angle / 3.14159) < dt) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
      } else {
        v_tex_coord /= 2.0;
        v_tex_coord += 0.5;
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

func starBlink(at position: CGPoint, throughAngle angle: CGFloat, duration: Double) -> SKSpriteNode {
  let star = SKSpriteNode(imageNamed: "star1")
  star.position = position
  star.scale(to: CGSize(width: 0, height: 0))
  star.run(SKAction.sequence([
    SKAction.group([
      SKAction.sequence([
        SKAction.scale(to: 2, duration: 0.5 * duration),
        SKAction.scale(to: 0, duration: 0.5 * duration)
        ]),
      SKAction.rotate(byAngle: angle, duration: duration),
      ]),
    SKAction.removeFromParent()
    ]))
  return star
}
