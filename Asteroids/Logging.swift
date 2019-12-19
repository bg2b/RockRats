//
//  Logging.swift
//  Asteroids
//
//  Created by David Long on 9/19/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import Foundation
import os.log

extension OSLog {
  static var subsystem = Bundle.main.bundleIdentifier!

  static let app = OSLog(subsystem: subsystem, category: "app")
  static let poi = OSLog(subsystem: subsystem, category: .pointsOfInterest)
}
