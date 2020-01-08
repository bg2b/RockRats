//
//  FilteredTexture.swift
//  Asteroids
//
//  Created by David Long on 1/7/20.
//  Copyright © 2020 David Long. All rights reserved.
//

import SpriteKit

/// Create a texture by applying a `CIFilter` to a texture
///
/// This whole thing was precipitated by a memory leak when using filters for an
/// `SKEffectNode`.  See the discussion under `setGameAreaBlur`.
///
/// - Parameters:
///   - texture: The texture
///   - filter: The filter to apply
/// - Returns: A new texture, or the original texture if something goes wrong
func filteredTexture(texture: SKTexture, filter: CIFilter) -> SKTexture {
  let inputImage = CIImage(cgImage: texture.cgImage())
  filter.setValue(inputImage, forKey: kCIInputImageKey)
  let context = CIContext(options: nil)
  if let filteredImage = filter.outputImage {
    // The filters generally are bigger than the original image, presumably so that
    // the effect doesn't do something odd at the edges, but I want to get only
    // whatever corresponds to the original texture.
    let padding = (filteredImage.extent.size - inputImage.extent.size).scale(by: 0.5)
    let renderExtent = filteredImage.extent.insetBy(dx: padding.width, dy: padding.height)
    if let filteredCGImage = context.createCGImage(filteredImage, from: renderExtent) {
      return SKTexture(cgImage: filteredCGImage)
    }
  }
  return texture
}
