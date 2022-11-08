//
//  Haptics.swift
//  Asteroids
//
//  Created by David Long on 11/6/22.
//  Copyright © 2022 David Long. All rights reserved.
//

import CoreHaptics
import os.log

/// A wrapper around CoreHaptics.  This also allows delegating haptics to a separate
/// game controller.
class HapticsInterface {
  /// The current haptics engine, either `defaultEngine` or something supplied by a
  /// game controller
  var engine: CHHapticEngine?
  /// The device's haptic engine, if any
  let defaultEngine: CHHapticEngine?
  /// A haptic pattern for the player's ship being destroyed
  let explosionPattern: CHHapticPattern?

  /// Are haptics available?
  var enabled: Bool { engine != nil }

  /// Initialize the device haptics engine, if it's available.  Make any patterns
  /// that might be played.
  init() {
    // Note that even if there are no default haptics available, I still want to make
    // patterns, since the player might connect a game controller which does support
    // haptics
    if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
      do {
        try defaultEngine = CHHapticEngine()
        os_log("Created device haptics engine", log: .app, type: .debug)
      } catch {
        defaultEngine = nil
        os_log("Can't create device haptics, %{public}s",
               log: .app, type: .debug, error.localizedDescription)
      }
    } else {
      defaultEngine = nil
      os_log("No device haptics available", log: .app, type: .debug)
    }
    engine = defaultEngine
    // Make the explosion pattern
    let explosionDuration = 1.0
    let rumble = CHHapticEvent(eventType: .hapticContinuous,
                               parameters: [
                                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0)
                               ],
                               relativeTime: 0,
                               duration: explosionDuration)
    let start = CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 1)
    let end = CHHapticParameterCurve.ControlPoint(relativeTime: explosionDuration, value: 0)
    let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl,
                                       controlPoints: [start, end],
                                       relativeTime: 0)
    let bang = CHHapticEvent(eventType: .hapticTransient,
                             parameters: [
                              CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                              CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
                             ], relativeTime: 0,
                             duration: 0.1)
    do {
      try explosionPattern = CHHapticPattern(events: [rumble, bang], parameterCurves: [curve])
    } catch {
      explosionPattern = nil
      os_log("Can't create explosion haptic pattern, %{public}s",
             log: .app, type: .debug, error.localizedDescription)
    }
  }

  /// Use the haptics engine on a game controller, or reset back to the device
  /// - Parameters:
  ///   - newEngine: a haptics engine for the controller, or `nil` if none
  ///   - onController: `true` if haptics should be on the controller.
  ///     This may be `true` even if `newEngine` is `nil` if the controller is
  ///     detached, i.e., the player's holding a separate controller and there's no
  ///     point in shaking the device.
  func setEngine(_ newEngine: CHHapticEngine?, onController: Bool) {
    guard engine != newEngine else { return }
    if onController {
      engine = newEngine
      os_log("Haptics on controller", log: .app, type: .debug)
    } else if engine != defaultEngine {
      engine = defaultEngine
      os_log("Haptics reset to device", log: .app, type: .debug)
    }
  }

  func play(_ pattern: CHHapticPattern) {
    guard let engine else { return }
    do {
      try engine.start()
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: CHHapticTimeImmediate)
      engine.notifyWhenPlayersFinished { _ in return .stopEngine }
    } catch {
      os_log("Error playing haptics, %{public}s",
             log: .app, type: .debug, error.localizedDescription)
    }
  }

  func explosion() {
    guard let explosionPattern else { return }
    play(explosionPattern)
  }
}
