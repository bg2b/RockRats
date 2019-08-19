//
//  Explosions.swift
//  Asteroids
//
//  Created by David Long on 7/28/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

// We have a texture that is the full thing that's supposed to explode, like a
// spaceship or whatever.  We're going to make an emitter node whose particles have
// this texture.  We want it to look like the thing is flying to pieces.  So we
// conceptually chop the full texture up into a grid of pieces.  Each piece will be
// scaled down so that it is about the right size for a piece of the full texture.
// Now the tricky part: we have to arrange so that each particle only draws some
// random bit of the full texture.  What we do is have the emitter assign each
// particle a random "color".  A custom fragment shader will use this color to figure
// out which part of the full texture to render.

// The texture will be chopped into an explosionSplits * explosionSplits grid.  Max
// is 16 so that a single random color component (8 bits) can index a single piece in
// the grid.
let explosionSplits = 8

// Here's the actual shader code.  We get the grid index from v_color_mix.r which
// will be randomly initialized by the emitter for each individual particle.
let explosionShader = SKShader(source :
  """
  void main() {
    int index = v_color_mix.r * \(explosionSplits * explosionSplits);
    int row = index % \(explosionSplits);
    int col = index / \(explosionSplits);
    v_tex_coord /= \(explosionSplits);
    v_tex_coord.y += row * \(1.0 / Double(explosionSplits));
    v_tex_coord.x += col * \(1.0 / Double(explosionSplits));
    gl_FragColor = texture2D(u_texture, v_tex_coord);
  }
  """)

func makeExplosion(texture: SKTexture, at position: CGPoint) -> Array<SKSpriteNode> {
  var pieces = [SKSpriteNode]()
  for x in 0...explosionSplits{
    for y in 0...explosionSplits{
      let rect = CGRect(x: CGFloat(x), y: CGFloat(y), width: texture.size().width/CGFloat(explosionSplits), height: texture.size().height/CGFloat(explosionSplits))
      let piece = SKSpriteNode(texture: SKTexture(rect: rect, in: texture))
      piece.physicsBody = SKPhysicsBody(rectangleOf: rect.size)
      pieces.append(piece)
    }
  }
  return pieces
}
