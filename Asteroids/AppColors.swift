//
//  AppColors.swift
//  Asteroids
//
//  Created by David Long on 9/21/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

func RGB(_ red: Int, _ green: Int, _ blue: Int) -> UIColor {
  return UIColor(red: CGFloat(red)/255.0, green: CGFloat(green)/255.0, blue: CGFloat(blue)/255.0, alpha: 1.0)
}

class AppColors {
  // These are the colors used in the various sprites (ships and lasers).
  static let blue = RGB(101, 185, 240)
  static let yellow = RGB(246, 205, 68)
  static let green = RGB(137, 198, 79)
  static let red = RGB(157, 66, 61)
  static let orange = RGB(203, 94, 57)
  // This one is the background star field.  We also have it set in the
  // LaunchScreen.storyboard, though I don't know of an automatic way to make what's
  // here match what's there.
  static let darkBlue = RGB(43, 45, 50)
  // Mappings of these colors to various UI elements
  static let textColor = AppColors.blue
  static let highlightTextColor = AppColors.yellow
  static let buttonColor = AppColors.green
  static let transitionColor = AppColors.darkBlue

  static let font = "Kenney Future Narrow"
}
