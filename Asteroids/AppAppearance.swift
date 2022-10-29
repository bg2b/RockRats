//
//  AppAppearance.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import SpriteKit

/// Return a `UIColor` from RGB values
/// - Parameters:
///   - red: Amount of red (0 to 255)
///   - green: Amount of green
///   - blue: Amount of blue
/// - Returns: The corresponding `UIColor` (with alpha = 1)
func RGB(_ red: Int, _ green: Int, _ blue: Int) -> UIColor {
  let toFrac = { (x: Int) in CGFloat(x)/255.0 }
  return UIColor(cgColor: CGColor(srgbRed: toFrac(red), green: toFrac(green), blue: toFrac(blue), alpha: 1.0))
}

/// Colors and styles and fonts used throughout the app
///
/// Put commonly-used colors and things here so that they only have to be changed in
/// one place to adjust the look.
class AppAppearance {
  /// The blue color used in the ship
  static let blue = RGB(54, 187, 245)
  /// The yellow color used in the ship
  static let yellow = RGB(255, 204, 0)
  /// The green color used in player shots
  static let green = RGB(112, 201, 54)
  /// The red color used for UFO shots
  static let red = RGB(172, 57, 57)
  /// The orange color used in the energy left bar when critical
  static let orange = RGB(222, 83, 45)
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
  /// Buttons have this color when focused
  static let focusColor = AppAppearance.yellow
  /// This color is used in the transition between scenes.
  ///
  /// Originally I had this set to AppAppearance.darkBlue, but I think it's better
  /// with more contrast between scene and transition.  This also is used for the
  /// background in the display's safe area during games, and matching the dark blue
  /// just looked a bit too low-contrast.  It's also used for the black in the retro
  /// shader.  Basically this can't just be set arbitrarily with no consequences.
  static let transitionColor = RGB(0, 0, 0)
  /// The color for normal button icons
  static let buttonColor = AppAppearance.blue
  /// The color for play/continue button icons
  static let playButtonColor = AppAppearance.green
  /// The color for cancel/quit/dangerous button icons
  static let dangerButtonColor = AppAppearance.red
  /// The name of the font used in the app
  static let font = "Asteroids"
}
