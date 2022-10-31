//
//  TutorialScene.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import SpriteKit
import os.log

/// Standard game pad button aliases and the graphics that they correspond to.  E.g.,
/// the standard name for A is `"Button A"`, and to display it I want to use the
/// `"ctrl_btnA"` sprite.  `"unknown"` is special; if I don't know how to display any
/// of the aliases that have been mapped to the standard one, then ? will be shown.
private let aliasToCtrl = [
  "Button A": "btnA", "Button B": "btnB",
  "Button X": "btnX", "Button Y": "btnY",
  "Left Trigger": "ltrig", "Left Shoulder": "lshld",
  "Right Trigger": "rtrig", "Right Shoulder": "rshld",
  "Direction Pad Left": "left", "Direction Pad Right": "right",
  "Direction Pad Up": "up", "Direction Pad Down": "down",
  "Left Thumbstick Left": "left", "Left Thumbstick Right": "right",
  "Left Thumbstick Up": "up", "Left Thumbstick Down": "down",
  "unknown": "unknown"
]

// MARK: Teach the padawans, I must

/// This is for showing an image of a controller plus some of the buttons (whatever
/// they should press)
class ControllerDisplay: SKNode {
  /// The controller graphic, an outline with transparent areas where the buttons go
  let controller: SKSpriteNode!
  /// Dictionary mapping graphic names (e.g., `"ctrl_BtnA"`) to sprite nodes
  var buttons: [String: SKNode]

  required init(withButtons: Bool) {
    controller = SKSpriteNode(imageNamed: "controller")
    controller.name = "controller"
    controller.position = .zero
    buttons = [:]
    if withButtons {
      for (_, ctrl) in aliasToCtrl where buttons[ctrl] == nil {
        let ctrlNode = SKSpriteNode(imageNamed: "ctrl_" + ctrl)
        ctrlNode.position = .zero
        // Button graphics (filled areas) go just behind the controller outline
        ctrlNode.zPosition = -1
        ctrlNode.isHidden = true
        buttons[ctrl] = ctrlNode
      }
    }
    super.init()
    self.addChild(controller)
    for (_, button) in buttons {
      self.addChild(button)
    }
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by ControllerDisplay")
  }

  /// Find the physical mappings for the normal control for an action and turn on all
  /// the corresponding sprites
  ///
  /// - Parameter actionButton: The alias for the normal control (e.g., `"Button A"`)
  func showControls(for actionButton: String) {
    let aliases = Globals.controller.getMappings(for: actionButton)
    for (_, button) in buttons {
      button.isHidden = true
    }
    var anyShown = false
    for alias in aliases {
      // If I know how to display this mapping, turn on the corresponding sprite
      if let ctrl = aliasToCtrl[alias], let button = buttons[ctrl] {
        button.isHidden = false
        anyShown = true
      }
    }
    if !anyShown {
      // Hopefully something is mapped to the needed control, but I don't know how to
      // display it.  If they don't remember it, they could be stuck...
      buttons["unknown"]!.isHidden = false
    }
  }
}

/// The tutorial scene
///
/// This guides the player through the basic gestures and then has them destroy an
/// asteroid.  Awards the `rockSplat` achievement if they manage to fail...
class TutorialScene: GameTutorialScene {
  /// Amount that indicates a full-scale slide for the joystick
  ///
  /// This is a little bigger on phones
  let slideAmount = 50 + 50 * Globals.ptsToGameUnits
  /// Text attributes
  var attributes: AttrStyles!
  /// A label node in the center of the screen for various messages
  var centralLabel: SKLabelNode!
  /// Instruction labels at the top
  var instructionLabels = [SKLabelNode]()
  /// Label that tells what the gesture does, just below `instructionLabels`
  var toDoLabel: SKLabelNode!
  /// Amount of time to delay between showing instructions and showing a gesture
  let instructionDelay = 1.0
  /// Tutors for touch and controller
  var tutors = [SKNode]()
  /// Touch tutor shapes
  var touchShapes = [SKNode]()
  /// Label for the gesture that the touch tutor is showing
  var touchLabel: SKLabelNode!
  /// Controller with nothing pressed
  var inactiveController: ControllerDisplay!
  /// Controller with some appropriate buttons pressed
  var activeController: ControllerDisplay!
  /// Set to `true` after observing a hyperspace jump
  var hasJumped = false
  /// Counter for shots fired
  var shotsFired = 0
  /// `true` means that they died at least once
  var anyShipsDestroyed = false
  /// Becomes `true` if they lose the last ship
  var lastShipDestroyed = false

  // MARK: - Initialization

  /// Make the stuff for the tutorial, except for the `touchShapes`
  ///
  /// See discussion in `initGestureShapes` below.
  func initTutorial() {
    let tutorialStuff = SKNode()
    tutorialStuff.name = "tutorialStuff"
    tutorialStuff.setZ(.info)
    gameArea.addChild(tutorialStuff)
    attributes = AttrStyles(fontName: AppAppearance.font, fontSize: 40)
    // Central label
    centralLabel = SKLabelNode()
    centralLabel.name = "centralLabel"
    centralLabel.position = CGPoint(x: gameFrame.midX, y: gameFrame.midY)
    centralLabel.horizontalAlignmentMode = .center
    centralLabel.verticalAlignmentMode = .center
    centralLabel.isHidden = true
    tutorialStuff.addChild(centralLabel)
    // Instructions and subinstructions at the top
    for _ in 0 ..< 2 {
      let instructionLabel = SKLabelNode()
      instructionLabel.name = "instructionLabel"
      instructionLabel.position = CGPoint(x: gameFrame.midX, y: gameFrame.maxY - attributes.fontSize)
      instructionLabel.isHidden = true
      tutorialStuff.addChild(instructionLabel)
      instructionLabels.append(instructionLabel)
    }
    toDoLabel = SKLabelNode()
    toDoLabel.name = "toDoLabel"
    toDoLabel.position = instructionLabels[0].position - CGVector(dx: 0, dy: attributes.fontSize)
    toDoLabel.isHidden = true
    tutorialStuff.addChild(toDoLabel)
    // Touch tutor
    let touchTutor = SKNode()
    touchTutor.name = "touchTutor"
    tutorialStuff.addChild(touchTutor)
    // A label for the touch tutor's gesture name (repositioned by the tutor)
    touchLabel = SKLabelNode(fontNamed: attributes.fontName)
    touchLabel.name = "touchShapeLabel"
    touchLabel.isHidden = true
    touchTutor.addChild(touchLabel)
    // Touch tutor shapes
    // I'll grab a pair from TouchDisplay which gets the right ones from the sprite
    // cache.  These will be modified but are just thrown away and not placed back in
    // the cache, so it's ok.
    let shapes = TouchDisplay(location: .zero)
    touchShapes.append(shapes.currentSprite)
    touchShapes.append(shapes.startSprite)
    for shape in touchShapes {
      shape.isHidden = true
      shape.alpha = 0.5
      shape.zPosition = 0
      touchTutor.addChild(shape)
    }
    tutors.append(touchTutor)
    // The controller tutor sets the overall transparency of the controller graphics
    // display
    let controllerTutor = SKNode()
    controllerTutor.name = "controllerTutor"
    controllerTutor.alpha = 0.5
    tutorialStuff.addChild(controllerTutor)
    // The inactive controller is just an outline
    inactiveController = ControllerDisplay(withButtons: false)
    inactiveController.name = "inactiveController"
    inactiveController.position = CGPoint(x: gameFrame.minX + inactiveController.size.width / 2 + 50,
                                          y: gameFrame.minY + inactiveController.size.height / 2 + 50)
    inactiveController.isHidden = true
    controllerTutor.addChild(inactiveController)
    // The active controller shows buttons and is flashed as appropriate when
    // prompting the user to do something
    activeController = ControllerDisplay(withButtons: true)
    activeController.name = "activeController"
    activeController.position = inactiveController.position
    activeController.isHidden = true
    controllerTutor.addChild(activeController)
    tutors.append(controllerTutor)
    // Initial visibility of tutors
    touchTutor.isHidden = Globals.controller.connected
    controllerTutor.isHidden = !touchTutor.isHidden
  }

  /// Create a tutorial scene
  /// - Parameters:
  ///   - size: The size of the scene
  init(size: CGSize) {
    os_log("TutorialScene init", log: .app, type: .debug)
    super.init(size: size, shipColor: nil)
    name = "tutorialScene"
    initTutorial()
    // This is needed to set the pausing blur shader
    setRetroMode(enabled: false)
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  deinit {
    os_log("TutorialScene deinit %{public}s", log: .app, type: .debug, "\(self.hash)")
  }

  // MARK: - Messages

  func attributedText(_ text: String) -> NSAttributedString {
    return makeAttributed(text: text, until: text.endIndex, attributes: attributes)
  }

  /// Display a message in the central label, then perform an action
  /// - Parameters:
  ///   - message: What to show
  ///   - delay: Amount of time to wait
  ///   - action: What to do afterwards
  func showMessage(_ message: String, delay: Double, then action: @escaping () -> Void) {
    centralLabel.attributedText = attributedText(message)
    centralLabel.alpha = 0
    centralLabel.run(.sequence([
      .wait(forDuration: 0.25),
      .unhide(),
      .fadeIn(withDuration: 0.25),
      .wait(forDuration: delay),
      .fadeOut(withDuration: 0.5),
      .hide(),
      .wait(forDuration: 0.5)
    ]), completion: action)
  }

  /// Hide the instructions if needed, then do something
  /// - Parameter action: What to do afterwards
  func hideInstructions(then action: @escaping () -> Void) {
    let duration = 0.25
    if !toDoLabel.isHidden {
      toDoLabel.run(.sequence([.fadeOut(withDuration: duration), .hide()]))
    }
    var allWereHidden = true
    for instructionLabel in instructionLabels where !instructionLabel.isHidden {
      instructionLabel.run(.sequence([.fadeOut(withDuration: duration), .hide()]), completion: action)
      allWereHidden = false
    }
    if allWereHidden {
      action()
    }
  }

  /// Display something in the instructions field, then do an action
  /// - Parameters:
  ///   - instructions: The messages to show, first for touch, second for controller
  ///   - toDo: An optional message for the second line below
  ///   - delay: Amount to wait after the instructions appear
  ///   - action: What to do afterwards
  func showInstructions(_ instructions: [String], toDo: String?, delay: Double, then action: @escaping () -> Void) {
    if !instructionLabels.allSatisfy({ $0.isHidden }) {
      // If something is visible, fade it out first
      hideInstructions { self.showInstructions(instructions, toDo: toDo, delay: delay, then: action) }
    } else {
      let duration = 0.25
      toDoLabel.alpha = 0
      if let toDo = toDo {
        toDoLabel.attributedText = attributedText(toDo)
        toDoLabel.isHidden = false
        toDoLabel.run(.fadeIn(withDuration: duration))
      } else {
        toDoLabel.isHidden = true
      }
      let fadeInAction = SKAction.sequence([.fadeIn(withDuration: duration), .wait(forDuration: delay)])
      let visibleIndex = Globals.controller.connected ? 1 : 0
      for index in 0 ..< 2 {
        let instructionLabel = instructionLabels[index]
        instructionLabel.alpha = 0
        instructionLabel.attributedText = attributedText(instructions[index])
        if index == visibleIndex {
          instructionLabel.isHidden = false
          instructionLabel.run(fadeInAction, completion: action)
        } else {
          instructionLabel.isHidden = true
          instructionLabel.run(fadeInAction)
        }
      }
    }
  }

  // MARK: - Game controller handling

  /// Handle controller connection and disconnection events by pausing and switching instructions
  /// - Parameter connected: `true` if a controller has just connected
  override func controllerChanged(connected: Bool) {
    if !gamePaused {
      doPause()
    }
    let newIndex = connected ? 1 : 0
    let oldIndex = 1 - newIndex
    if !instructionLabels[oldIndex].isHidden {
      instructionLabels[newIndex].isHidden = false
      instructionLabels[oldIndex].isHidden = true
    }
    tutors[oldIndex].isHidden = true
    tutors[newIndex].isHidden = false
  }

  // MARK: - Player spawning and death

  /// Spawn the player
  func spawnPlayer(position: CGPoint) {
    if !isSafe(point: position, forDuration: Globals.gameConfig.safeTime) {
      let spawnRegion = gameFrame.insetBy(dx: 100, dy: 100)
      let otherPosition = CGPoint(x: .random(in: spawnRegion.minX ... spawnRegion.maxX),
                                  y: .random(in: spawnRegion.minY ... spawnRegion.maxY))
      wait(for: 0.25) { self.spawnPlayer(position: otherPosition) }
    } else {
      energyBar.fill()
      player.reset()
      player.warpIn(to: position, atAngle: player.zRotation, addTo: playfield)
      audio.soundEffect(.warpIn, at: position)
      updateReserves(-1)
    }
  }

  func showMessageAndSpawn() {
    assert(reservesRemaining > 0)
    let spawnMessages = [
      "That'll buff right out",
      "Oops",
      "Training begins!"
    ]
    showMessage(spawnMessages[reservesRemaining - 1], delay: 2) {
      self.spawnPlayer(position: CGPoint(x: self.gameFrame.midX, y: self.gameFrame.midY))
    }
  }

  /// Boom...
  func destroyPlayer() {
    anyShipsDestroyed = true
    let pieces = player.explode()
    addToPlayfield(pieces)
    audio.soundEffect(.playerExplosion)
    if reservesRemaining > 0 {
      if asteroids.isEmpty {
        // They destroyed the last asteroid by ramming, don't bother to respawn
      } else {
        showMessageAndSpawn()
      }
    } else {
      allLivesLost()
    }
  }

  // MARK: - Touch tutor

  /// Stops the tutor once the player has done something successfully
  func hideTutor() {
    for shape in touchShapes {
      shape.removeAllActions()
      shape.isHidden = true
    }
    touchLabel.isHidden = true
    inactiveController.isHidden = true
    activeController.removeAllActions()
    activeController.isHidden = true
  }

  /// Show a success message, then perform an action after a short delay
  /// - Parameter action: What to do after the delay
  func reportSuccess(then action: @escaping () -> Void) {
    // Originally I just had this set a flag that would be observed by some action at
    // the end of the gesture's repeat, and that action would do the hideTutor part.
    // That was intended to have the effect of not cutting off the gesture in the
    // middle.  Unforunately it seemed to be quite flaky for some unknown reason.
    // Fairly often it would do the initial action in the repeating sequence despite
    // the repeat nominally having been nuked by removeAllActions.  I wound up trying
    // to split the ending delay into parts, calling the check for the flag at
    // various points, etc.  Finally I just decided it's not worth the headache.
    hideTutor()
    // When this is being called from observeAsteroids after the last bit of asteroid has
    // been destroyed but they've lost some lives, don't be quite so effusive in the praise.
    let message = anyShipsDestroyed ? "Could have been better..." : "@Good!@"
    showInstructions([message, message], toDo: nil, delay: 3, then: action)
  }

  /// Make the touch tutor show a slide-and-hold gesture
  /// - Parameters:
  ///   - position: Where to show the slide
  ///   - displacement: The amount of the slide
  func showSlideAndHold(position: CGPoint, moveBy displacement: CGVector) {
    let start = position - displacement.scale(by: 0.5)
    for shape in touchShapes {
      shape.isHidden = true
      shape.position = start
    }
    touchLabel.isHidden = false
    touchLabel.numberOfLines = 2
    let shapeSize = touchShapes[0].frame.width
    if displacement.dx != 0 {
      // Put the label above
      touchLabel.position = position + CGVector(dx: 0, dy: 0.75 * shapeSize)
      touchLabel.horizontalAlignmentMode = .center
      touchLabel.verticalAlignmentMode = .bottom
      // Poor man's centering...
      touchLabel.attributedText = attributedText("    @Slide@\nand @hold@")
    } else {
      // Put the label to the right
      touchLabel.position = position + CGVector(dx: 0.75 * shapeSize, dy: 0)
      touchLabel.horizontalAlignmentMode = .left
      touchLabel.attributedText = attributedText("@Slide@\nand @hold@")
      touchLabel.verticalAlignmentMode = .center
    }
    let initialDelay = 0.25
    let moveTime = 0.5
    let holdTime = 3.0
    let betweenDelay = 0.5
    touchShapes[0].run(.repeatForever(.sequence([
      .unhide(),
      .run { self.touchShapes[1].isHidden = false },
      .wait(forDuration: initialDelay),
      .move(by: displacement, duration: moveTime),
      .wait(forDuration: holdTime),
      .hide(),
      .run { self.touchShapes[1].isHidden = true },
      .move(to: start, duration: 0),
      .wait(forDuration: betweenDelay)
    ])))
  }

  /// Calculate where the touch tutor should show ship movements
  func movementPosition() -> CGPoint {
    // Initial offset from the corner
    var cornerOffset = CGVector(dx: 50, dy: 50)
    // Add clearance for the touch shapes
    cornerOffset += CGVector(dx: 0.5 * touchShapes[0].frame.width, dy: 0.5 * touchShapes[0].frame.height)
    // Add an amount for a slide
    cornerOffset += CGVector(dx: 0.5 * 1.25 * slideAmount, dy: 0.5 * 1.25 * slideAmount)
    // Final start point
    return CGPoint(x: gameFrame.minX, y: gameFrame.minY) + cornerOffset
  }

  /// Make the touch tutor show a tap-tap-tap gesture
  /// - Parameter position: Where to show the taps
  func showTaps(position: CGPoint) {
    for shape in touchShapes {
      shape.isHidden = true
      shape.position = position
    }
    touchLabel.isHidden = false
    touchLabel.numberOfLines = 1
    // Label above
    let shapeSize = touchShapes[0].frame.width
    touchLabel.position = position + CGVector(dx: 0, dy: 0.75 * shapeSize)
    touchLabel.horizontalAlignmentMode = .center
    touchLabel.verticalAlignmentMode = .bottom
    touchLabel.attributedText = attributedText("@Tap@")
    let tapTime = 0.15
    let betweenTapTime = 0.15
    let betweenDelay = 1.0
    touchShapes[0].run(.repeatForever(.sequence([
      .repeat(.sequence([
        .unhide(),
        .wait(forDuration: tapTime),
        .hide(),
        .wait(forDuration: betweenTapTime)]),
              count: 3),
      .wait(forDuration: betweenDelay)
    ])))
  }

  /// Make the touch tutor show a swipe gesture
  /// - Parameters:
  ///   - position: Where to show the swipe
  ///   - moveBy: The amount the swipe moves
  func showSwipe(position: CGPoint, moveBy displacement: CGVector) {
    let start = position - displacement.scale(by: 0.5)
    for shape in touchShapes {
      shape.isHidden = true
      shape.position = start
    }
    touchLabel.isHidden = false
    touchLabel.numberOfLines = 1
    let shapeSize = touchShapes[0].frame.width
    // Label to the left
    touchLabel.position = position + CGVector(dx: -0.75 * shapeSize, dy: 0)
    touchLabel.horizontalAlignmentMode = .right
    touchLabel.verticalAlignmentMode = .center
    touchLabel.attributedText = attributedText("@Swipe@")
    let initialDelay = 0.1
    let moveTime = 0.25
    let holdTime = 0.1
    let betweenDelay = 1.0
    touchShapes[0].run(.repeatForever(.sequence([
      .unhide(),
      .run { self.touchShapes[1].isHidden = false },
      .wait(forDuration: initialDelay),
      .move(by: displacement, duration: moveTime),
      .wait(forDuration: holdTime),
      .hide(),
      .run { self.touchShapes[1].isHidden = true },
      .move(to: start, duration: 0),
      .wait(forDuration: betweenDelay)
    ])))
  }

  /// The position for the touch tutor to show shooting and jumping gestures
  func shootAndJumpPosition() -> CGPoint {
    let pos = movementPosition()
    return CGPoint(x: -pos.x, y: pos.y)
  }

  // MARK: - Controller tutor

  /// Swap the active and inactive controller visibilities to show buttons being
  /// pressed and released
  func flipControllerAction() {
    inactiveController.isHidden = !inactiveController.isHidden
    activeController.isHidden = !inactiveController.isHidden
  }

  /// Display an action on the game controller
  /// - Parameters:
  ///   - actionButton: The normal control for the action (e.g., "Button A")
  ///   - durations: The lengths of time between inactive/active flips
  func showControllerAction(actionButton: String, durations: [Double]) {
    inactiveController.isHidden = false
    // Turn on the buttons in the active controller to show whatever physical things
    // map to the action
    activeController.showControls(for: actionButton)
    let doFlip = SKAction.run { self.flipControllerAction() }
    var flips = [SKAction]()
    for duration in durations {
      flips.append(.wait(forDuration: duration))
      flips.append(doFlip)
    }
    activeController.run(.repeatForever(.sequence(flips)))
  }

  // MARK: - Observing actions

  /// Do a hyperspace jump, but set a flag when it happens
  override func hyperspaceJump() {
    hasJumped = true
    super.hyperspaceJump()
  }

  /// Fire and count laser shots
  override func fireLaser() -> Bool {
    if super.fireLaser() {
      shotsFired += 1
      return true
    } else {
      return false
    }
  }

  /// Observe the joystick to see if the player is doing the desired gesture
  ///
  /// After a string of successful observations, reports success and then executes an
  /// action
  ///
  /// - Parameters:
  ///   - direction: The desired direction of the stick
  ///   - successes: The number of consecutive successful observations
  ///   - action: What to do afterward
  func observeStick(direction: CGVector, successes: Int, then action: @escaping () -> Void) {
    let samplingTime = 0.1
    if successes == 15 {
      // They've held the gesture for sufficient time to see the effect
      reportSuccess(then: action)
    } else if hasJumped || player.parent == nil {
      // Reset if they've jumped or haven't yet come back after entering hyperspace
      hasJumped = false
      wait(for: samplingTime) { self.observeStick(direction: direction, successes: 0, then: action) }
    } else {
      if joystick().dotProd(direction) > 0.75 {
        // The stick is in the right direction
        wait(for: samplingTime) { self.observeStick(direction: direction, successes: successes + 1, then: action) }
      } else {
        // The stick is not moved or is moved in an incorrect direction
        wait(for: samplingTime) { self.observeStick(direction: direction, successes: 0, then: action) }
      }
    }
  }

  /// Observe to see if they're firing the lasers
  ///
  /// After a few shots are fired, reports success and then executes an action
  ///
  /// - Parameter action: What to do afterward
  func observeShooting(then action: @escaping () -> Void) {
    if shotsFired >= 5 {
      reportSuccess(then: action)
    } else {
      wait(for: 0.1) { self.observeShooting(then: action) }
    }
  }

  /// Observe to see if they make a hyperspace jump
  ///
  /// After a jump, reports success and then executes an action
  ///
  /// - Parameter action: What to do afterward
  func observeHyperspace(then action: @escaping () -> Void) {
    if hasJumped && player.parent != nil {
      reportSuccess(then: action)
    } else {
      wait(for: 0.1) { self.observeHyperspace(then: action) }
    }
  }

  /// Observe to see if they've destroyed the asteroid
  ///
  /// Execute an action after the asteroid is gone
  ///
  /// - Parameter action: What to do afterward
  func observeAsteroid(then action: @escaping () -> Void) {
    // If they've managed to destroy all the ships (by ramming), then let allLivesLost
    // deal with things
    guard !lastShipDestroyed else { return }
    if asteroids.isEmpty {
      reportSuccess(then: action)
    } else {
      wait(for: 0.5) { self.observeAsteroid(then: action) }
    }
  }

  // MARK: - Training steps

  /// Rotate left training
  func training1() {
    showInstructions(["@Slide@ and @hold@", "Use the @dpad/stick@"], toDo: "to @rotate left@", delay: instructionDelay) {
      let delta = CGVector(dx: -1.25 * self.slideAmount, dy: 0)
      self.showSlideAndHold(position: self.movementPosition(), moveBy: delta)
      self.showControllerAction(actionButton: "Direction Pad Left", durations: [0.5, 3])
      self.observeStick(direction: CGVector(dx: -1, dy: 0), successes: 0, then: self.training2)
    }
  }

  /// Rotate right training
  func training2() {
    showInstructions(["@Slide@ and @hold@", "Use the @dpad/stick@"], toDo: "to @rotate right@", delay: instructionDelay) {
      let delta = CGVector(dx: 1.25 * self.slideAmount, dy: 0)
      self.showSlideAndHold(position: self.movementPosition(), moveBy: delta)
      self.showControllerAction(actionButton: "Direction Pad Right", durations: [0.5, 3])
      self.observeStick(direction: CGVector(dx: 1, dy: 0), successes: 0, then: self.training3)
    }
  }

  /// Thrust training
  func training3() {
    let controllerMsg = UserData.buttonThrust.value ? "@Press the button@ to" : "Use the @dpad/stick@ to"
    showInstructions(["@Slide@ and @hold@ to", controllerMsg], toDo: "@thrust forwards@", delay: instructionDelay) {
      let delta = CGVector(dx: 0, dy: 1.25 * self.slideAmount)
      self.showSlideAndHold(position: self.movementPosition(), moveBy: delta)
      let controllerAction = UserData.buttonThrust.value ? "Left Trigger" : "Direction Pad Up"
      self.showControllerAction(actionButton: controllerAction, durations: [0.5, 3])
      self.observeStick(direction: CGVector(dx: 0, dy: 1), successes: 0, then: self.training4)
    }
  }

  /// Reverse thrust training
  func training4() {
    let controllerMsg = UserData.buttonThrust.value ? "@Press the button@ to" : "Use the @dpad/stick@ to"
    showInstructions(["@Slide@ and @hold@ to", controllerMsg], toDo: "@thrust backwards@", delay: instructionDelay) {
      let delta = CGVector(dx: 0, dy: -1.25 * self.slideAmount)
      self.showSlideAndHold(position: self.movementPosition(), moveBy: delta)
      let controllerAction = UserData.buttonThrust.value ? "Right Trigger" : "Direction Pad Down"
      self.showControllerAction(actionButton: controllerAction, durations: [0.5, 3])
      self.observeStick(direction: CGVector(dx: 0, dy: -1), successes: 0, then: self.training5)
    }
  }

  /// Fire laser training
  func training5() {
    showInstructions(["@Tap@ to", "@Press the button@ to"], toDo: "@fire lasers@", delay: instructionDelay) {
      self.showTaps(position: self.shootAndJumpPosition())
      self.showControllerAction(actionButton: "Button A", durations: [1, 0.1, 0.1, 0.1, 0.1, 0.1])
      self.shotsFired = 0
      self.observeShooting(then: self.training6)
    }
  }

  /// Hyperspace jump training
  func training6() {
    showInstructions(["@Swipe@ to", "@Press the button@ to"], toDo: "@jump to hyperspace@", delay: instructionDelay) {
      self.showSwipe(position: self.shootAndJumpPosition(), moveBy: CGVector(dx: 0, dy: 1.25 * self.slideAmount))
      self.showControllerAction(actionButton: "Button B", durations: [1, 0.25])
      self.hasJumped = false
      self.observeHyperspace(then: self.training7)
    }
  }

  /// Destroy an asteroid training
  func training7() {
    let msg = "@Shoot@ lasers to"
    showInstructions([msg, msg], toDo: "@destroy the asteroid@", delay: instructionDelay) {
      self.spawnAsteroid(size: .huge)
      self.observeAsteroid(then: self.trainingComplete)
    }
  }

  // MARK: - End of training

  /// End of tutorial, go back to the menu
  func trainingComplete() {
    disablePause()
    guard beginSceneSwitch() else { fatalError("trainingComplete in TutorialScene found scene switch in progress???") }
    hideInstructions {
      self.showMessage("Training complete", delay: 3) {
        // Switch back to the main menu
        self.switchWhenQuiescent { Globals.menuScene }
      }
    }
  }

  /// They've worked hard at crashing
  func allLivesLost() {
    lastShipDestroyed = true
    reservesDisplay.isHidden = true
    hideInstructions {
      let message: String
      if self.asteroids.isEmpty {
        message = "That's doing it the hard way"
      } else {
        message = "Rock Rat? @Rock SPLAT!@"
        reportAchievement(achievement: .rockSplat)
      }
      self.showMessage(message, delay: 2, then: self.trainingComplete)
    }
  }

  // MARK: - Contact handling

  /// One of the player's shots hit an asteroid
  /// - Parameters:
  ///   - laser: The shot
  ///   - asteroid: The asteroid that it hit
  func laserHit(laser: SKNode, asteroid: SKNode) {
    removeLaser(laser as! SKSpriteNode)
    splitAsteroid(asteroid as! SKSpriteNode)
  }

  /// The player ran into an asteroid
  /// - Parameter asteroid: The asteroid
  func playerCollided(asteroid: SKNode) {
    splitAsteroid(asteroid as! SKSpriteNode)
    destroyPlayer()
  }

  /// Handles all the possible physics engine contact notifications
  /// - Parameter contact: What contacted what
  func didBegin(_ contact: SKPhysicsContact) {
    when(contact, isBetween: .playerShot, and: .asteroid) { laserHit(laser: $0, asteroid: $1) }
    when(contact, isBetween: .player, and: .asteroid) { playerCollided(asteroid: $1) }
  }

  // MARK: - Running the tutorial

  /// Start the tutorial
  /// - Parameter view: The view that will present the scene
  override func didMove(to view: SKView) {
    super.didMove(to: view)
    Globals.gameConfig = loadGameConfig(forMode: "normal")
    Globals.gameConfig.currentWaveNumber = 1
    reservesRemaining = Globals.gameConfig.initialLives
    updateReserves(0)
    energyBar.fill()
    replenishEnergy()
    wait(for: 1, then: showMessageAndSpawn)
    wait(for: 5, then: training1)
  }

  /// Main update loop
  /// - Parameter currentTime: The game time
  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    player.fly()
    playfield.wrapCoordinates()
    audio.update()
    endOfUpdate()
  }
}
