//
//  Logging.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import Foundation
import os.log

extension OSLog {
  static var subsystem = Bundle.main.bundleIdentifier!

  static let app = OSLog(subsystem: subsystem, category: "app")
  static let poi = OSLog(subsystem: subsystem, category: .pointsOfInterest)
}
