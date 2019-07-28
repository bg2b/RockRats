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

func makeExplosion(texture: SKTexture, at position: CGPoint) -> SKEmitterNode {
  let emitter = SKEmitterNode()
  emitter.particleTexture = texture
  let textureSize = hypot(texture.size().width, texture.size().height)
  let explosionDuration = CGFloat(1.0)
  // Since fragments are chosen randomly, do some extra to mostly cover everything
  emitter.numParticlesToEmit = explosionSplits * explosionSplits * 4 / 3
  // Desired size of the final explosion
  let radius = 2.5 * textureSize
  emitter.particleLifetime = explosionDuration
  emitter.particleLifetimeRange = 0.75 * explosionDuration
  emitter.particleScale = 1.0 / CGFloat(explosionSplits)
  emitter.particleScaleRange = 0.5 * emitter.particleScale
  emitter.particleBirthRate = CGFloat(emitter.numParticlesToEmit) / (0.25 * explosionDuration)
  emitter.particleSpeed = radius / explosionDuration
  emitter.particleSpeedRange = 0.25 * emitter.particleSpeed
  emitter.particlePosition = .zero
  emitter.particlePositionRange = CGVector(dx: textureSize, dy: textureSize).scale(by: 0.25)
  emitter.emissionAngle = 0
  emitter.emissionAngleRange = 2 * .pi
  emitter.particleRotation = 0
  emitter.particleRotationRange = 2 * .pi
  emitter.particleRotationSpeed = 4 * .pi / explosionDuration
  // Here's the magic part...
  emitter.particleColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
  emitter.particleColorRedRange = 1.0
  // The blend factor must have a nonzero value, otherwise v_color_mix doesn't get set
  // appropriately for the shader.
  emitter.particleColorBlendFactor = 1.0
  emitter.shader = explosionShader
  emitter.position = position
  return emitter
}
