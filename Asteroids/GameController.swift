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
  /// If the controller has a home button, this holds it
  var homeButton: GCControllerButtonInput?
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
  var connected: Bool { chosenController != nil}

  /// Scan currently attached controllers, find one that's suitable, and bind to it
  @objc func findController() {
    // Remember the current binding
    let oldController = chosenController
    // Scan for suitable controllers
    chosenController = nil
    extendedGamepad = nil
    let controllers = GCController.controllers()
    for controller in controllers where controller.extendedGamepad != nil {
      // I can only use extended gamepad controllers
      if controller.isAttachedToDevice {
        // Always prefer a controller that's physically attached
        chosenController = controller
      } else {
        // Otherwise just pick whatever comes first.  If the player doesn't want to
        // use that, they can cut it off ;-)
        chosenController = chosenController ?? controller
      }
    }
    extendedGamepad = chosenController?.extendedGamepad
    if chosenController != oldController {
      unbindActions()
      if let controller = chosenController {
        os_log("Found %{public}s", log: .app, type: .debug, controller.vendorName ?? "unknown game controller")
      } else {
        os_log("No game controller found", log: .app, type: .debug)
      }
      // There's no home button field on the extended gamepad profile, so if the
      // controller has one, I have to find it on my own.  I do that by watching all
      // the controller events and grabbing the home button if the player presses it.
      homeButton = nil
      // I can only test this home button hack for controllers that I have.  Right
      // now that's Playstation and Xbox controllers, but probably those will be the
      // only common controllers anyway.
      let vendor = chosenController?.vendorName ?? "unknown"
      if vendor.hasPrefix("DUALSHOCK 4") || vendor.hasPrefix("Xbox") {
        // Playstation and Xbox controllers have a home button, so watch for it
        chosenController?.extendedGamepad?.valueChangedHandler = { [weak self] _, controllerElement in
          self?.findHomeButton(controllerElement)
        }
      }
      // Bind button press events to actions for the current controller
      bindActions()
      changedDelegate?.controllerChanged(connected: connected)
    }
    // If the controller supports the active LED mechanism, indicate the selected one
    for controller in controllers {
      if controller == chosenController {
        controller.playerIndex = .index1
      } else {
        controller.playerIndex = .indexUnset
      }
    }
  }

  /// A hack to find the controller's home button, if any
  ///
  /// This gets called from the controller's `valueChangedHandler` and watches
  /// everything to see if there's a home button event
  ///
  /// - Parameter element: The element that was just activated on the controller
  func findHomeButton(_ element: GCControllerElement) {
    // This shouldn't be called if the home button has already been found, but whatevs
    guard homeButton == nil else { return }
    // Here is my very sophisticated code to determine if the element that was just
    // activated is the home button...
    if "\(element)".hasPrefix("Home Button") {
      // Found it, no need to watch anymore
      extendedGamepad?.valueChangedHandler = nil
      homeButton = element as? GCControllerButtonInput
      // Re-bind so that the later home button presses will automatically trigger the
      // desired action
      bindActions()
      if let homeButton = homeButton, homeButton.isPressed {
        // If the home button was just discovered then the binding wasn't set up
        // before, so manually trigger whatever action is now bound to the home
        // button
        homeButton.pressedChangedHandler?(homeButton, 1, true)
      }
    }
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

  // MARK: - Joystick handling

  /// Convert a direction pad state into a `CGVector` as used by the game
  func asJoystick(_ extendedGamepad: GCExtendedGamepad,
                  _ path: KeyPath<GCExtendedGamepad, GCControllerDirectionPad>) -> CGVector {
    let stick = extendedGamepad[keyPath: path]
    if UserData.buttonThrust.value {
      // User preference for A/B buttons to thrust
      let thrust = CGFloat(extendedGamepad.buttonA.value - extendedGamepad.buttonB.value)
      return CGVector(dx: CGFloat(stick.xAxis.value), dy: thrust)
    } else {
      // User preference for y-axis of stick to thrust
      return CGVector(dx: CGFloat(stick.xAxis.value), dy: CGFloat(stick.yAxis.value))
    }
  }

  /// Read the current joystick state
  /// - Returns: The direction of the stick, x-axis is rotation, positive y is forward thrust
  func joystick() -> CGVector {
    guard let extendedGamepad = extendedGamepad else { return .zero }
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
}

extension Globals {
  /// The interface to game controllers
  static let controller = Controller()
}
