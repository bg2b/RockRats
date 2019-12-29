//
//  TutorialScene.swift
//  Asteroids
//
//  Created by David Long on 9/24/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import os.log

// MARK: Teach the padawans, I must

/// The tutorial scene
///
/// This guides the player through the basic gestures and then has them destroy an
/// asteroid.  Awards the `rockSplat` achievement if they manage to fail...
class TutorialScene: GameTutorialScene {
  /// Amount that indicates a full-scale slide for the joystick
  let slideAmount = CGFloat(100)
  /// Text attributes
  var attributes: AttrStyles!
  /// A label node in the center of the screen for various messages
  var centralLabel: SKLabelNode!
  /// Instruction label at the top
  var instructionLabel: SKLabelNode!
  /// Label that tells what the gesture does, just below `instructionLabel`
  var toDoLabel: SKLabelNode!
  /// Amount of time to delay between showing instructions and showing a gesture
  let instructionDelay = 1.0
  /// Touch tutor shapes
  var touchShapes: [SKNode]!
  /// Label for the gesture that the tutor is showing
  var touchLabel: SKLabelNode!
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
    instructionLabel = SKLabelNode()
    instructionLabel.name = "instructionLabel"
    instructionLabel.position = CGPoint(x: gameFrame.midX, y: gameFrame.maxY - attributes.fontSize)
    instructionLabel.isHidden = true
    tutorialStuff.addChild(instructionLabel)
    toDoLabel = SKLabelNode()
    toDoLabel.name = "toDoLabel"
    toDoLabel.position = instructionLabel.position - CGVector(dx: 0, dy: attributes.fontSize)
    toDoLabel.isHidden = true
    tutorialStuff.addChild(toDoLabel)
    // A label for the touch tutor's gesture name (repositioned by the tutor)
    touchLabel = SKLabelNode(fontNamed: attributes.fontName)
    touchLabel.name = "touchShapeLabel"
    touchLabel.fontSize = attributes.fontSize
    touchLabel.fontColor = AppAppearance.textColor
    touchLabel.isHidden = true
    tutorialStuff.addChild(touchLabel)
  }

  /// Make shapes for the touch tutor
  ///
  /// The reason this stuff isn't directly in `initTutorial` is because shape nodes
  /// with stroke shaders don't seem to antialias.  As a result, the dashed shape
  /// node that indicates where a touch started is somewhat ugly.  This routine does
  /// a poor man's antialiasing by rendering an enlarged dashed shape node into a
  /// texture, then adding a scaled down sprite node based on that texture instead.
  /// Doing the rendering requires a view however, so this has to be called from
  /// `didMove(to:)` instead of from the scene's constructor.
  func initGestureShapes() {
    guard let parent = centralLabel.parent, touchShapes == nil else { return }
    touchShapes = [SKNode]()
    let touchRadius = 0.5 * slideAmount
    let touchWidth = touchRadius / 10
    for dashed in [false, true] {
      let antialiasFactor = dashed ? CGFloat(4) : 1
      let shape = SKShapeNode(circleOfRadius: antialiasFactor * touchRadius)
      shape.fillColor = .clear
      shape.strokeColor = AppAppearance.yellow
      shape.lineWidth = (dashed ? 0.5 : 1) * antialiasFactor * touchWidth
      shape.isAntialiased = true
      let shader: SKShader?
      if dashed {
        let rgba = shape.strokeColor.cgColor.components!
        shader = SKShader(source: """
          void main() {
            int h = int((v_path_distance / u_path_length + 0.5) * 20) % 2;
            if (h == 0) {
              gl_FragColor = float4(0);
            } else {
              gl_FragColor = float4(\(rgba[0]), \(rgba[1]), \(rgba[2]), 1);
            }
          }
          """)
      } else {
        shader = nil
      }
      shape.strokeShader = shader
      shape.name = "touchShape\(dashed ? "Dashed" : "")"
      if dashed, let texture = view?.texture(from: shape) {
        let sprite = SKSpriteNode(texture: texture, size: texture.size().scale(by: 1 / antialiasFactor))
        sprite.name = shape.name
        touchShapes.append(sprite)
      } else {
        // If for some reason, it wasn't possible to render the node into a texture
        // just save the scaled shape node
        shape.setScale(1 / antialiasFactor)
        touchShapes.append(shape)
      }
    }
    for shape in touchShapes {
      shape.isHidden = true
      parent.addChild(shape)
    }
  }

  /// Create a tutorial scene
  /// - Parameters:
  ///   - size: The size of the scene
  init(size: CGSize) {
    os_log("TutorialScene init", log: .app, type: .debug)
    super.init(size: size, shipColor: nil)
    name = "tutorialScene"
    initTutorial()
    // This is needed to set the pausing blur filter
    setRetroMode(enabled: false)
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  deinit {
    os_log("TutorialScene deinit %{public}s", log: .app, type: .debug, "\(self.hash)")
  }

  // MARK: - Messages

  /// Display a message in the central label, then perform an action
  /// - Parameters:
  ///   - message: What to show
  ///   - delay: Amount of time to wait
  ///   - action: What to do afterwards
  func showMessage(_ message: String, delay: Double, then action: @escaping () -> Void) {
    centralLabel.attributedText = makeAttributed(text: message, until: message.endIndex, attributes: attributes)
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
    if !instructionLabel.isHidden {
      instructionLabel.run(.sequence([.fadeOut(withDuration: duration), .hide()]), completion: action)
    } else {
      action()
    }
  }

  /// Display something in the instructions field, then do an action
  /// - Parameters:
  ///   - instructions: The message to show
  ///   - toDo: An optional message for the second line below
  ///   - delay: Amount to wait after the instructions appear
  ///   - action: What to do afterwards
  func showInstructions(_ instructions: String, toDo: String?, delay: Double, then action: @escaping () -> Void) {
    if !instructionLabel.isHidden {
      // If something is visible, fade it out first
      hideInstructions { self.showInstructions(instructions, toDo: toDo, delay: delay, then: action) }
    } else {
      let duration = 0.25
      if let toDo = toDo {
        instructionLabel.alpha = 0
        toDoLabel.attributedText = makeAttributed(text: toDo, until: toDo.endIndex, attributes: attributes)
        toDoLabel.isHidden = false
        toDoLabel.run(.fadeIn(withDuration: duration))
      } else {
        toDoLabel.isHidden = true
      }
      toDoLabel.alpha = 0
      instructionLabel.attributedText = makeAttributed(text: instructions, until: instructions.endIndex, attributes: attributes)
      instructionLabel.isHidden = false
      instructionLabel.run(.sequence([.fadeIn(withDuration: duration), .wait(forDuration: delay)]), completion: action)
    }
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
    showInstructions(message, toDo: nil, delay: 3, then: action)
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
      touchLabel.text = "    Slide\nand hold"
    } else {
      if UserData.joystickOnLeft.value {
        // Put the label to the right
        touchLabel.position = position + CGVector(dx: 0.75 * shapeSize, dy: 0)
        touchLabel.horizontalAlignmentMode = .left
        touchLabel.text = "Slide\nand hold"
      } else {
        // Put the label to the left
        touchLabel.position = position + CGVector(dx: -0.75 * shapeSize, dy: 0)
        touchLabel.horizontalAlignmentMode = .right
        // Poor man's right justification
        touchLabel.text = "        Slide\nand hold"
      }
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
    let onLeft = CGPoint(x: gameFrame.minX, y: gameFrame.minY) + cornerOffset
    return UserData.joystickOnLeft.value ? onLeft : CGPoint(x: -onLeft.x, y: onLeft.y)
  }

  /// Make the touch tutor show a tap-tap-tap gesture
  /// - Parameters
  ///   - position: Where to show the taps
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
    touchLabel.text = "Tap"
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
    if UserData.joystickOnLeft.value {
      // Label to the left
      touchLabel.position = position + CGVector(dx: -0.75 * shapeSize, dy: 0)
      touchLabel.horizontalAlignmentMode = .right
    } else {
      // Label to the right
      touchLabel.position = position + CGVector(dx: 0.75 * shapeSize, dy: 0)
      touchLabel.horizontalAlignmentMode = .left
    }
    touchLabel.verticalAlignmentMode = .center
    touchLabel.text = "Swipe"
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
      if joystickDirection.dotProd(direction) > 0.75 {
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

  func training1() {
    showInstructions("@Slide@ and @hold@", toDo: "to @rotate left@", delay: instructionDelay) {
      let delta = CGVector(dx: -1.25 * self.slideAmount, dy: 0)
      self.showSlideAndHold(position: self.movementPosition(), moveBy: delta)
      self.observeStick(direction: CGVector(dx: 0, dy: 1), successes: 0, then: self.training2)
    }
  }

  func training2() {
    showInstructions("@Slide@ and @hold@", toDo: "to @rotate right@", delay: instructionDelay) {
      let delta = CGVector(dx: 1.25 * self.slideAmount, dy: 0)
      self.showSlideAndHold(position: self.movementPosition(), moveBy: delta)
      self.observeStick(direction: CGVector(dx: 0, dy: -1), successes: 0, then: self.training3)
    }
  }

  func training3() {
    showInstructions("@Slide@ and @hold@ to", toDo: "@thrust forwards@", delay: instructionDelay) {
      let delta = CGVector(dx: 0, dy: 1.25 * self.slideAmount)
      self.showSlideAndHold(position: self.movementPosition(), moveBy: delta)
      self.observeStick(direction: CGVector(dx: 1, dy: 0), successes: 0, then: self.training4)
    }
  }

  func training4() {
    showInstructions("@Slide@ and @hold@ to", toDo: "@thrust backwards@", delay: instructionDelay) {
      let delta = CGVector(dx: 0, dy: -1.25 * self.slideAmount)
      self.showSlideAndHold(position: self.movementPosition(), moveBy: delta)
      self.observeStick(direction: CGVector(dx: -1, dy: 0), successes: 0, then: self.training5)
    }
  }

  func training5() {
    showInstructions("@Tap@ to", toDo: "@fire lasers@", delay: instructionDelay) {
      self.showTaps(position: self.shootAndJumpPosition())
      self.shotsFired = 0
      self.observeShooting(then: self.training6)
    }
  }

  func training6() {
    showInstructions("@Swipe@ to", toDo: "@jump to hyperspace@", delay: instructionDelay) {
      self.showSwipe(position: self.shootAndJumpPosition(), moveBy: CGVector(dx: 0, dy: 1.25 * self.slideAmount))
      self.hasJumped = false
      self.observeHyperspace(then: self.training7)
    }
  }

  func training7() {
    showInstructions("@Shoot@ lasers to", toDo: "@destroy the asteroid@", delay: instructionDelay) {
      self.spawnAsteroid(size: "huge")
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
        self.showWhenQuiescent(Globals.menuScene)
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
    initGestureShapes()
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
  }
}
