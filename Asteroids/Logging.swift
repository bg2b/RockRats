//
//  Logging.swift
//  Asteroids
//
//  Created by David Long on 9/19/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import Foundation

var showLogging = true
var lastLogMessage = ""
var lastLogMessageRepeated = 0

/// Prints various info as the game runs, but is smart about duplicates.  Repeated
/// calls to logging will show "(### repeats): ..." with decreasing frequency.
/// - Parameter message: The first string is used to identify repeats, the remaining
///   strings are just printed.
func logging(_ message: String...) {
  if showLogging {
    switch message.count {
    case 0:
      print("logging called with no message?!")
    case 1:
      print(message[0])
      lastLogMessage = message[0]
      lastLogMessageRepeated = 1
    default:
      if lastLogMessage == message[0] {
        lastLogMessageRepeated += 1
        if lastLogMessageRepeated & (lastLogMessageRepeated - 1) == 0 {
          // A power of 2 repeats
          var fullMessage = "\(lastLogMessageRepeated) repeats:"
          message.forEach { fullMessage += " \($0)" }
          print(fullMessage)
        }
      } else {
        var fullMessage = message[0]
        message[1...].forEach { fullMessage += " \($0)" }
        print(fullMessage)
        lastLogMessage = message[0]
        lastLogMessageRepeated = 1
      }
    }
  }
}
