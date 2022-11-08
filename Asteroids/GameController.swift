//
//  GameController.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import GameController
import os.log

// MARK: Controller changed delegate

/// A scene that wants to be notified of controller connection and disconnection
/// events should conform to this protocol and set itself as the `Controller`
/// singleton's change delegate
protocol ControllerChangedDelegate: AnyObject {

  /// This is called when the controller is changed
  func controllerChanged(connected: Bool)
}

// MARK: - Game controller interface

/// This is a wrapper around the external game controller framework.  It handles
/// connection and disconnection events from controllers, finds ones that support the
/// extended gamepad profile, provides a way to bind closures to button presses, and
/// reads joystick direction when requested.
class Controller {
  /// A button whose press handler I set
  struct BoundButton {
    weak var button: GCControllerButtonInput?
  }
  /// The selected game controller, if any
  var chosenController: GCController?
  /// The extended gamepad profile for the selected controller
  var extendedGamepad: GCExtendedGamepad?
  /// Desired bindings of buttons to actions (closures) for the current scene
  var buttonActions = [KeyPath<Controller, GCControllerButtonInput?>: () -> Void]()
  /// Buttons whose press handler was set
  var boundButtons = [BoundButton]()
  /// Who to inform if the controller changes
  weak var changedDelegate: ControllerChangedDelegate?

  // MARK: - Initialization

  /// Create the game controller interface
  ///
  /// This should be a singleton
  init() {
    // Look for suitable controllers that are currently attached
    findController()
    // Re-scan on controller connection/disconnection events
    NotificationCenter.default.addObserver(self, selector: #selector(findController),
                                           name: NSNotification.Name.GCControllerDidConnect, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(findController),
                                           name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
  }

  // MARK: - Controller discovery

  /// `true` when a controller is connected
  var connected: Bool { chosenController != nil }

  /// Scan currently attached controllers, find one that's suitable, and bind to it
  @objc func findController() {
    // Remember the current binding
    let oldController = chosenController
    chosenController = GCController.current
    extendedGamepad = chosenController?.extendedGamepad
    if chosenController != oldController {
      unbindActions()
      if let chosenController {
        os_log("Found %{public}s", log: .app, type: .debug, chosenController.vendorName ?? "unknown game controller")
      } else {
        os_log("No game controller found", log: .app, type: .debug)
      }
      // Bind button press events to actions for the current controller
      bindActions()
      changedDelegate?.controllerChanged(connected: connected)
    }
    // If the controller supports the active LED mechanism, indicate the selected one
    for controller in GCController.controllers() {
      controller.playerIndex = .indexUnset
    }
    chosenController?.playerIndex = .index1
    // Set a default color if there's a light
    setColor("ship")
    // Haptics may get taken over by the controller
    setHaptics()
  }

  // MARK: - Button actions

  /// Remove all button bindings
  func clearActions() {
    unbindActions()
    buttonActions.removeAll()
  }

  /// Set the binding for a button
  ///
  /// This uses the keypath mechanism to indicate buttons so that if the bindings are
  /// automatically installed if the controller changes.  Something like if the
  /// player started a game, realized that their controller was off, paused the game,
  /// and then turned on the controller.
  ///
  /// Be sure to use weak references in the actions so that a discarded scene won't
  /// get accidentally retained.
  ///
  /// - Parameters:
  ///   - keypath: A path to the desired button
  ///   - action: A closure to be called when the button is pressed
  func setAction(_ keypath: KeyPath<Controller, GCControllerButtonInput?>, action: @escaping () -> Void) {
    buttonActions[keypath] = action
    bindActions()
  }

  /// Bind buttons on the current controller to the desired actions
  func bindActions() {
    unbindActions()
    for (path, action) in buttonActions {
      if let buttonInput = self[keyPath: path] {
        // I only care about changes in the pressed state for this, and only do the
        // action on press, not on release
        buttonInput.pressedChangedHandler = { _, _, pressed in if pressed { action() } }
        boundButtons.append(BoundButton(button: buttonInput))
      }
    }
  }

  /// Remove bindings to the current controller and clear the desired bindings
  func unbindActions() {
    for boundButton in boundButtons {
      boundButton.button?.pressedChangedHandler = nil
    }
    boundButtons.removeAll()
  }

  /// Find the physical buttons that are mapped to our standard controls
  ///
  /// The old button-based thrust controls used A and B for thrust, but now I've
  /// switched to the left and right triggers.  If the user prefers the old setup,
  /// they should configure the game controller in settings to map A to left trigger
  /// and B to right trigger, plus put the fire button and hyperspace button
  /// (normally A and B) on something else, say the shoulder buttons.  During the
  /// tutorial I want to show whatever they should actually press, so I need to know
  /// what physical buttons correspond to the standard action buttons.  E.g., if A
  /// has been mapped to the left trigger (thrust forward) and the right shoulder has
  /// been mapped to A (fire), then calling `getMappings(for: "Button A")` will
  /// return a set containing `"Right Shoulder"`.  Note that there can be more than
  /// one physical button mapped to the desired action.  The tutorial should show all
  /// the possibilities.
  ///
  /// - Parameter button: The standard button for an action
  /// - Returns: The set of physical buttons that will perform the action
  func getMappings(for button: String) -> Set<String> {
    guard let extendedGamepad else { return Set([button]) }
    guard extendedGamepad.elements[button] != nil else {
      fatalError("No element for button name \(button)")
    }
    return extendedGamepad.mappedPhysicalInputNames(forElementAlias: button)
  }

  // MARK: - Joystick handling

  /// Convert a direction pad state into a `CGVector` as used by the game
  func asJoystick(_ extendedGamepad: GCExtendedGamepad,
                  _ path: KeyPath<GCExtendedGamepad, GCControllerDirectionPad>) -> CGVector {
    let stick = extendedGamepad[keyPath: path]
    if UserData.buttonThrust.value {
      // User preference for triggers to thrust
      let thrust = CGFloat(extendedGamepad.leftTrigger.value - extendedGamepad.rightTrigger.value)
      return CGVector(dx: CGFloat(stick.xAxis.value), dy: thrust)
    } else {
      // User preference for y-axis of stick to thrust
      return CGVector(dx: CGFloat(stick.xAxis.value), dy: CGFloat(stick.yAxis.value))
    }
  }

  /// Read the current joystick state
  /// - Returns: The direction of the stick, x-axis is rotation, positive y is forward thrust
  func joystick() -> CGVector {
    guard let extendedGamepad else { return .zero }
    // I read both thumbstick and dpad so that the player can use whichever is most
    // comfortable for them.  Whichever one is moved is the one that gets returned
    let stick1 = asJoystick(extendedGamepad, \GCExtendedGamepad.dpad)
    let stick2 = asJoystick(extendedGamepad, \GCExtendedGamepad.leftThumbstick)
    if stick2.length() > stick1.length() {
      return stick2
    } else {
      return stick1
    }
  }

  // MARK: - Color

  /// Set the light on the chosen controller (if it exists) to a color.  I based this
  /// on a Dual Shock 4 light.  Nominally the controller's light can be set to some
  /// RGB value, but trying to match `AppAppearance` colors is pointless.  I've
  /// instead just picked very saturated colors according to some names.
  /// - Parameter color: The desired color name
  func setColor(_ color: String) {
    guard let light = chosenController?.light else { return }
    switch color {
    case "blue":
      light.color = GCColor(red: 0, green: 0, blue: 1)
    case "green":
      light.color = GCColor(red: 0, green: 1, blue: 0)
    case "red":
      light.color = GCColor(red: 1, green: 0, blue: 0)
    case "orange":
      light.color = GCColor(red: 1, green: 0.3, blue: 0)
    case "yellow":
      light.color = GCColor(red: 1, green: 1, blue: 0)
    case "white":
      light.color = GCColor(red: 1, green: 1, blue: 1)
    case "ship":
      // Choose based on ship color selection preference
      if UserData.retroMode.value {
        setColor("white")
      } else {
        setColor(UserData.shipColor.value)
      }
    default:
      light.color = GCColor(red: 0, green: 0, blue: 1)
    }
  }

  // MARK: - Haptics
  func setHaptics() {
    if let chosenController {
      let engine = chosenController.haptics?.createEngine(withLocality: .default)
      let onController = engine != nil || !chosenController.isAttachedToDevice
      // If the controller has haptics, it takes over.  If it does not have haptics,
      // then it still takes over if it's not attached to the device.  For an
      // attached controller, I'll leave the device haptics enabled and hopefully
      // they can still be felt.
      Globals.haptics.setEngine(engine, onController: onController)
    } else {
      Globals.haptics.setEngine(nil, onController: false)
    }
  }
}

extension Globals {
  /// The interface to game controllers
  static let controller = Controller()
}
