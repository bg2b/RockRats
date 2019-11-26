//
//  AppAppearance.swift
//  Asteroids
//
//  Created by David Long on 9/21/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// Return a `UIColor` from RGB values
/// - Parameters:
///   - red: Amount of red (0 to 255)
///   - green: Amount of green
///   - blue: Amount of blue
/// - Returns: The corresponding `UIColor` (with alpha = 1)
func RGB(_ red: Int, _ green: Int, _ blue: Int) -> UIColor {
  return UIColor(red: CGFloat(red)/255.0, green: CGFloat(green)/255.0, blue: CGFloat(blue)/255.0, alpha: 1.0)
}

/// Colors and styles and fonts used throughout the app
///
/// Put commonly-used colors and things here so that they only have to be changed in
/// one place to adjust the look.
class AppAppearance {
  /// The blue color used in the ship
  static let blue = RGB(101, 185, 240)
  /// The yellow color used in the ship
  static let yellow = RGB(246, 205, 68)
  /// The green color used in player shots
  static let green = RGB(137, 198, 79)
  /// The red color used for UFO shots
  static let red = RGB(157, 66, 61)
  /// The orange color used in the energy left bar when critical
  static let orange = RGB(203, 94, 57)
  /// This color is from the background star field.  I also have it set in the
  /// LaunchScreen.storyboard, though I don't know of an automatic way to make what's
  /// here match what's there.
  static let darkBlue = RGB(43, 45, 50)
  /// Normal text uses this color
  static let textColor = AppAppearance.blue
  /// Highlighted text uses this color
  static let highlightTextColor = AppAppearance.yellow
  /// Normal button outlines use this color
  static let borderColor = AppAppearance.green
  /// Dangerous button outlines that require confirmation use this color
  static let dangerBorderColor = AppAppearance.red
  /// This color is used in the transition between scenes
  static let transitionColor = AppAppearance.darkBlue
  /// The color for normal button icons
  static let buttonColor = AppAppearance.blue
  /// The color for play/continue button icons
  static let playButtonColor = AppAppearance.green
  /// The color for cancel/quit/dangerous button icons
  static let dangerButtonColor = AppAppearance.red
  /// The name of the font used in the app
  static let font = "Asteroids"
}