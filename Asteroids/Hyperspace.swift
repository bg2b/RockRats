//
//  Hyperspace.swift
//  Asteroids
//
//  Created by David Long on 9/6/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

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

var firstUTimeRef: Double?

func setStartTimeAttrib(_ effect: SKSpriteNode) {
  if let firstUTimeRef = firstUTimeRef {
    // u_time in the shaders started at 0 when the global time was firstUTimeRef.
    // The global time is now Globals.lastUpdateTime.
    // Therefore u_time now is Globals.lastUpdateTime - firstUTimeRef.
    // We want set the offset a_start_time to this to shift the effective u_time to 0.
    effect.setValue(SKAttributeValue(float: Float(Globals.lastUpdateTime - firstUTimeRef)), forAttribute: "a_start_time")
  } else {
    effect.setValue(SKAttributeValue(float: 0), forAttribute: "a_start_time")
    firstUTimeRef = Globals.lastUpdateTime
  }
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
