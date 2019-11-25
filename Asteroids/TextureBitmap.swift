//
//  TextureBitmap.swift
//  Asteroids
//
//  Created by David Long on 11/25/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// A bitmap (of some variable type) for a texture
///
/// The texture's pixels get converted to the required type by a user-specified closure.
struct TextureBitmap<T> {
  /// The texture's size (in points)
  let textureSize: CGSize
  /// The width of the underlying image (in pixels)
  let width: Int
  /// The height of the underlying image (in pixels)
  let height: Int
  /// Pixel data, width*height
  let pixels: [T]

  /// Create a bitmap from a texture
  ///
  /// - Note: This is generally broken in iOS 13.2 (and maybe some later versions, I
  ///   haven't checked) for textures that are in atlases.
  ///
  /// - Parameters:
  ///   - texture: The texture
  ///   - getPixelInfo: A closure that converts `UInt32` to `T` in the desired way
  ///   - pixel: a 32-bit pixel value, in RGBA format with alpha pre-multiplied
  init(texture: SKTexture, getPixelInfo: (_ pixel: UInt32) -> T) {
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
