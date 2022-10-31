//
//  GameTutorialScene.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import SpriteKit
import GameController
import os.log

// MARK: Game/tutorial base class

/// Things common to game and tutorial (but not in the BasicScene superclass)
///
/// This scene includes the player's ship and controls, the remaining ships display,
/// and the energy reserve display.  It also handles game pausing and
/// resuming/quitting, and the special retro mode (though retro mode never gets
/// enabled in the tutorial).
class GameTutorialScene: BasicScene {
  /// Set to true when the pause button is pressed
  var gamePaused = false
  /// The touch control to pause the game
  var pauseButton: Touchable!
  /// The button to continue the game (usually hidden)
  var continueButton: Button!
  /// The button to quit the game (usually hidden)
  var quitButton: Button!
  /// The name of the color of the player's ship
  let shipColor: String
  /// The player's spaceship
  var player: Ship!
  /// Points earned; this is in GameTutorialScene only because `hyperspaceJump()`
  /// refers to it.  See the comments there.
  var score = 0
  /// The display of the number of reserve ships
  var reservesDisplay: ReservesDisplay!
  /// How many reserve ships they have left; the current ship doesn't count in this.
  var reservesRemaining = 0
  /// The display of the player's energy reserves
  var energyBar: EnergyBar!
  /// The point of the (virtual) joystick's origin
  var joystickLocation = CGPoint.zero
  /// The (virtual) joystick's direction and magnitude relative to its origin
  /// - This is normalized so that the maximum magnitude is 1.
  var joystickDirection = CGVector.zero
  /// The touch corresponding to the virtual joystick
  /// - This is set by touchesBegan, tracked in touchesMoved, and cleared in touchesEnded.
  var joystickTouch: UITouch?
  /// A dictionary mapping possible fire and hyperspace jump touches to their staring
  /// locations.
  var fireOrWarpTouches = [UITouch: CGPoint]()
  /// `true` if touch display is enabled
  var displayingTouches = true
  /// Touches being shown (if `displayingTouches` is `true`)
  var displayedTouches = [UITouch: TouchDisplay]()
  /// `true` if the scene has been only retro mode
  var onlyRetro = false

  // MARK: - Initialization

  /// Build information and control interface elements that are common to the game
  /// and the tutorial
  func initInfo() {
    // All of the stuff in here sits above the playfield, at z == LevelZs.info.
    let info = SKNode()
    info.name = "info"
    info.setZ(.info)
    // info sits under gameArea in the hierarchy, so it's subject to whatever sort of
    // blurring effect is used when the game is paused
    gameArea.addChild(info)
    // Remaining ships in upper left
    reservesDisplay = ReservesDisplay(shipColor: shipColor)
    reservesDisplay.position = CGPoint(x: gameFrame.minX + 20, y: gameFrame.maxY - 20)
    info.addChild(reservesDisplay)
    // Energy reserves in upper right
    energyBar = EnergyBar(maxLength: 20)
    info.addChild(energyBar)
    energyBar.position = CGPoint(x: gameFrame.maxX - 20, y: gameFrame.maxY - 20)
    let pauseControls = SKNode()
    // The pause/continue/quit controls are directly under the scene in the hierarchy
    // and _not_ under gameArea, so they don't get blurred when the game pauses
    addChild(pauseControls)
    pauseControls.name = "pauseControls"
    let pauseTexture = Globals.textureCache.findTexture(imageNamed: "pause")
    pauseButton = Touchable(SKSpriteNode(texture: pauseTexture, size: pauseTexture.size()),
                            minSize: 50 * Globals.ptsToGameUnits) { [unowned self] in
      self.doPause()
    }
    // The pause icon sits just below the remaining ships and is mostly transparent.
    // When touched, it'll hide itself and show the continue/quit buttons.
    pauseButton.alpha = 0.1
    pauseButton.position = CGPoint(x: gameFrame.minX + pauseTexture.size().width / 2 + 10,
                                   y: reservesDisplay.position.y - pauseTexture.size().height / 2 - 20)
    pauseButton.setZ(.info)
    pauseControls.addChild(pauseButton)
    // Two nice big buttons in the center of the screen for continue and quit.
    // They're only unhidden when the game pauses.  Audio is disabled when these are
    // clicked, so to make a noise on continue requires re-enabling it first.
    let buttonSize = CGSize(width: 250, height: 200)
    continueButton = Button(imageNamed: "bigplaybutton", imageColor: AppAppearance.playButtonColor, size: buttonSize)
    continueButton.makeSound = false
    continueButton.action = { [unowned self] in self.doContinue() }
    continueButton.position = CGPoint(x: gameFrame.midX - 0.5 * buttonSize.width - 50, y: gameFrame.midY)
    continueButton.isHidden = true
    continueButton.setZ(.pauseControls)
    pauseControls.addChild(continueButton)
    quitButton = Button(imageNamed: "bigcancelbutton", imageColor: AppAppearance.dangerButtonColor, size: buttonSize)
    quitButton.makeSound = false
    quitButton.action = { [unowned self] in self.doQuit() }
    quitButton.position = CGPoint(x: 2 * gameFrame.midX - continueButton.position.x, y: continueButton.position.y)
    quitButton.isHidden = true
    quitButton.setZ(.pauseControls)
    pauseControls.addChild(quitButton)
  }

  /// Make a game or tutorial scene of a given size
  /// - Parameter size: The size of the scene
  init(size: CGSize, shipColor: String?) {
    self.shipColor = shipColor ?? "blue"
    super.init(size: size)
    name = "gameTutorialScene"
    // Very wide aspect ratios are generally easier games.  4:3 is was the original
    // intent, but some iPads are a bit wider (1.4ish), and I want full screen on
    // those.
    initGameArea(avoidSafeArea: true, maxAspectRatio: 1.5)
    initInfo()
    isUserInteractionEnabled = true
    physicsWorld.contactDelegate = self
    player = Ship(getJoystickDirection: { [unowned self] in return self.joystick() }, color: self.shipColor, audio: audio)
  }

  required init(coder aDecoder: NSCoder) {
    self.shipColor = "blue"
    super.init(coder: aDecoder)
  }

  // MARK: - Touch display

  /// Markers for start of touch and current location of touch
  struct TouchDisplay {
    let startSprite: SKSpriteNode
    let currentSprite: SKSpriteNode

    init(location: CGPoint) {
      let touchSize = Globals.ptsToGameUnits > 1.5 ? "big" : "sm"
      startSprite = Globals.spriteCache.findSprite(imageNamed: "touchdashed\(touchSize)") {
        $0.color = AppAppearance.blue
        $0.colorBlendFactor = 1
        $0.setZ(.info)
      }
      currentSprite = Globals.spriteCache.findSprite(imageNamed: "touchsolid\(touchSize)") {
        $0.color = AppAppearance.blue
        $0.colorBlendFactor = 1
        $0.setZ(.info)
      }
      startSprite.position = location
      startSprite.isHidden = true
      currentSprite.position = location
    }
  }

  /// Show the start of a touch
  /// - Parameters:
  ///   - touch: The touch, used as a key for storing the `TouchDisplay`
  ///   - location: The location of the touch
  func displayTouchBegan(touch: UITouch, location: CGPoint) {
    guard displayingTouches else { return }
    let display = TouchDisplay(location: location)
    addChild(display.startSprite)
    addChild(display.currentSprite)
    displayedTouches[touch] = display
  }

  /// Show a touch that's moved
  /// - Parameters:
  ///   - touch: The touch
  ///   - location: Where the touch has moved to
  /// - Returns: `true` if the touch has moved significantly
  func displayTouchMoved(touch: UITouch, location: CGPoint) -> Bool {
    guard displayingTouches else { return true }
    guard let display = displayedTouches[touch] else {
      os_log("Display not found for moved touch", log: .app, type: .error)
      return true
    }
    let displacement = location - display.startSprite.position
    if displacement.length() > 15 {
      // If the touch has moved a lot, show both initial and current position
      display.currentSprite.position = location
      display.startSprite.isHidden = false
      return true
    } else {
      // If not much movement, snap to the initial position
      display.currentSprite.position = display.startSprite.position
      display.startSprite.isHidden = true
      return false
    }
  }

  /// Display an ending (or canceled) touch
  /// - Parameter touch: The touch
  func displayTouchEnded(touch: UITouch) {
    guard displayingTouches else { return }
    guard let display = displayedTouches.removeValue(forKey: touch) else {
      os_log("Display not found for ended touch", log: .app, type: .error)
      return
    }
    Globals.spriteCache.recycleSprite(display.startSprite)
    Globals.spriteCache.recycleSprite(display.currentSprite)
  }

  // MARK: - Touch handling

  /// Handle the start of touches to control the ship
  /// - Parameters:
  ///   - touches: The new touches
  ///   - event: The event the touches belong to
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    // Ignore new touches when the game is paused
    guard !gamePaused else { return }
    for touch in touches {
      let location = touch.location(in: self)
      if location.x > fullFrame.midX {
        // Touches on this side are for firing or warping
        fireOrWarpTouches[touch] = location
        displayTouchBegan(touch: touch, location: location)
      } else if joystickTouch == nil {
        // Touches on this side are for the (virtual) joystick
        joystickLocation = location
        joystickTouch = touch
        displayTouchBegan(touch: touch, location: location)
      } // Else the joystick is already active, so ignore the touch
    }
  }

  /// Returns `true` if a touch has moved enough to indicate a hyperspace jump request
  /// - Parameters:
  ///   - location: The current location of the touch
  ///   - startLocation: The location where the touch started
  func isJumpRequest(_ location: CGPoint, startLocation: CGPoint) -> Bool {
    // Normal coordinates are scaled to give 768 units vertically on the screen, but
    // for this I want to require a move of a certain physical distance on the
    // screen, so I need to convert to points.
    return (location - startLocation).length() > Globals.ptsToGameUnits * 100
  }

  /// Handle moving touches for the ship controls
  /// - Parameters:
  ///   - touches: The touches that moved
  ///   - event: The event the touches belong to
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    // Ignore any touch movements when the game is paused.
    guard !gamePaused else { return }
    for touch in touches {
      if touch == joystickTouch {
        // This is a movement of the joystick
        let location = touch.location(in: self)
        let delta = location - joystickLocation
        let offset = delta.length()
        // Measure the movement in terms of a certain physical distance, so convert
        // to points, then scale to 0 - 1
        joystickDirection = delta.scale(by: min(offset / (Globals.ptsToGameUnits * 75), 1.0) / offset)
        if !displayTouchMoved(touch: touch, location: location) {
          // Touch hasn't moved significantly
          joystickDirection = .zero
        }
      } else {
        guard let startLocation = fireOrWarpTouches[touch] else { continue }
        let location = touch.location(in: self)
        // Jump without waiting for a touchesEnded(), since the situation is likely a
        // bit urgent ;-)
        if isJumpRequest(location, startLocation: startLocation) {
          fireOrWarpTouches.removeValue(forKey: touch)
          displayTouchEnded(touch: touch)
          hyperspaceJump()
        } else {
          _ = displayTouchMoved(touch: touch, location: location)
        }
      }
    }
  }

  /// Handle the end of touches for the ship controls
  /// - Parameters:
  ///   - touches: The touches that finished
  ///   - event: The event the touches belong to
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      if touch == joystickTouch {
        // Reset the joystick as soon as they lift their finger
        joystickDirection = .zero
        joystickTouch = nil
        displayTouchEnded(touch: touch)
      } else {
        guard let startLocation = fireOrWarpTouches.removeValue(forKey: touch) else { continue }
        displayTouchEnded(touch: touch)
        // gamePaused should never be true here now that cancelAllTouches is called
        // upon pause, but I'll leave this just for safety in case I ever change
        // things back
        guard !gamePaused else { continue }
        if isJumpRequest(touch.location(in: self), startLocation: startLocation) {
          hyperspaceJump()
        } else {
          _ = fireLaser()
        }
      }
    }
  }

  /// Handle touches interrupted by something like a phone call
  /// - Parameters:
  ///   - touches: The touches to be cancelled
  ///   - event: The event the touches belong to
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    os_log("Touches cancelled", log: .app, type: .debug)
    for touch in touches {
      if touch == joystickTouch {
        joystickDirection = .zero
        joystickTouch = nil
        displayTouchEnded(touch: touch)
      } else if fireOrWarpTouches.removeValue(forKey: touch) != nil {
        displayTouchEnded(touch: touch)
      }
    }
  }

  /// Drop all active touches (used when pausing the game)
  func cancelAllTouches() {
    if let touch = joystickTouch {
      joystickTouch = nil
      joystickDirection = .zero
      displayTouchEnded(touch: touch)
    }
    for (touch, _) in fireOrWarpTouches {
      displayTouchEnded(touch: touch)
    }
    fireOrWarpTouches.removeAll()
  }

  // MARK: - Game controller handling

  /// Action for the fire button
  /// - Parameter canUnpause: `true` if the button can also act as continue when the game is paused
  /// - Returns: `true` if a shot was fired
  func fireButton(canUnpause: Bool = false) -> Bool {
    if gamePaused {
      if canUnpause {
        doContinue()
      }
      return false
    } else {
      return fireLaser()
    }
  }

  /// Action for the hyperspace button
  /// - Parameter canQuit: `true` if the button can also act as quit when the game is paused
  func hyperspaceButton(canQuit: Bool = false) {
    if gamePaused {
      if canQuit {
        doQuit()
      }
    } else {
      hyperspaceJump()
    }
  }

  /// Action for a button to pause or continue the game
  func pauseContinueButton() {
    if gamePaused {
      doContinue()
    } else {
      doPause()
    }
  }

  /// Action for continuing when the game is paused
  func continueIfPaused() {
    if gamePaused {
      doContinue()
    }
  }

  /// Action for quitting when the game is paused
  func quitIfPaused() {
    if gamePaused {
      doQuit()
    }
  }

  /// Handle controller connection and disconnection events by pausing
  /// - Parameter connected: `true` if a controller has just connected
  override func controllerChanged(connected: Bool) {
    if !gamePaused {
      doPause()
    }
  }

  /// Bind controller buttons to actions
  ///
  /// Normal controls are left stick or dpad to turn and thrust, A to fire, B for
  /// hyperspace.  There's an option to use the left and right triggers for thrust
  /// instead of the dpad.  The menu button pauses and unpauses, and for easier
  /// pressing X also does that.  When paused, A continues and B quits.  To remap
  /// controls, the iOS game controller settings should be customized.
  func bindControllerPlayButtons() {
    Globals.controller.clearActions()
    // Button A = fire and continue after pause
    Globals.controller.setAction(\Controller.extendedGamepad?.buttonA) { [weak self] in _ = self?.fireButton(canUnpause: true) }
    // Button B = hyperspace and quit after pause
    Globals.controller.setAction(\Controller.extendedGamepad?.buttonB) { [weak self] in self?.hyperspaceButton(canQuit: true) }
    // The menu button pauses and unpauses.  I'll also throw in button X because I
    // think that's easier to hit when in the middle of playing.
    Globals.controller.setAction(\Controller.extendedGamepad?.buttonX) { [weak self] in self?.pauseContinueButton() }
    Globals.controller.setAction(\Controller.extendedGamepad?.buttonMenu) { [weak self] in self?.pauseContinueButton() }
    Globals.controller.changedDelegate = self
  }

  /// Read the joystick direction
  ///
  /// This merges the results of on-screen touches with the joystick from the
  /// controller by just taking whichever is active.
  ///
  /// - Returns: A vector representing the joystick, x-axis = rotation, y-axis = thrust
  func joystick() -> CGVector {
    let controllerDirection = Globals.controller.joystick()
    if controllerDirection.length() > joystickDirection.length() {
      return controllerDirection
    } else {
      return joystickDirection
    }
  }

  // MARK: - Pause, continue, and quit

  /// Enforce pausing when gamePaused is true so that SpriteKit's
  /// auto-pausing/unpausing doesn't mess us up
  override var forcePause: Bool { gamePaused }

  /// Pause the game, blur the playing area, hide the pause button, show the
  /// continue/quit buttons
  func doPause() {
    pauseButton.isHidden = true
    continueButton.isHidden = false
    quitButton.isHidden = false
    setGameAreaBlur(true)
    gamePaused = true
    isPaused = true
    audio.pause()
    cancelAllTouches()
  }

  /// Undo the effects of doPause and resume play
  func doContinue() {
    pauseButton.isHidden = false
    continueButton.isHidden = true
    quitButton.isHidden = true
    setGameAreaBlur(false)
    gamePaused = false
    isPaused = false
    audio.resume()
    // The continue button didn't make a noise because audio was disabled when it was
    // clicked
    continueButton.clickSound()
  }

  /// Abort the game/tutorial immediately and go back to the main menu
  func doQuit() {
    guard beginSceneSwitch() else { fatalError("doQuit in GameTutorialScene found scene switch in progress???") }
    audio.stop()
    continueButton.isHidden = true
    quitButton.isHidden = true
    // Don't call the normal switchScene or switchWhenQuiescent.  Those make an
    // outgoing transition and won't work with paused outgoing scenes.
    switchScene(withFade: true) { Globals.menuScene }
  }

  /// Disallow pausing
  ///
  /// Used at the end of a game when preparing to transition out to another scene and
  /// the `doQuit` should not be called
  func disablePause() {
    assert(continueButton.isHidden && quitButton.isHidden)
    pauseButton.isUserInteractionEnabled = false
    pauseButton.run(.sequence([.fadeOut(withDuration: 0.25), .hide()]))
  }

  /// Clean up a game or tutorial scene
  ///
  /// The scene is leaving its view and will be destroyed in a moment.  If this is
  /// happening because of doQuit, then the scene may be in a complicated state that
  /// I can't easily characterize.  So I force things into a state where the scene
  /// can get garbage collected cleanly.
  ///
  /// - Parameter view: The view that the scene is leaving
  override func willMove(from view: SKView) {
    super.willMove(from: view)
    cleanup()
  }

  // MARK: - Spawning

  /// Determine if a potential spawn point is safe from an asteroid track, accounting
  /// for possible wrapping
  /// - Parameters:
  ///   - point: Candidate spawn
  ///   - pathStart: Start of asteroid track
  ///   - pathEnd: End of asteroid track
  ///   - clearance: How much clearance is needed between the point and the track
  /// - Returns: `true` if there's sufficient clearance from the track
  func isSafe(point: CGPoint, pathStart: CGPoint, pathEnd: CGPoint, clearance: CGFloat) -> Bool {
    // Method: generate "image" points in wrapped positions and make sure that all
    // clear the segment.  This seems easier than trying to simulate the wrapping of
    // the segment.
    var dxs = [CGFloat(0)]
    if pathEnd.x < gameFrame.minX { dxs.append(-gameFrame.width) }
    if pathEnd.x > gameFrame.maxX { dxs.append(gameFrame.width) }
    var dys = [CGFloat(0)]
    if pathEnd.y < gameFrame.minY { dys.append(-gameFrame.height) }
    if pathEnd.y > gameFrame.maxY { dys.append(gameFrame.height) }
    for dx in dxs {
      for dy in dys {
        let p = CGPoint(x: point.x + dx, y: point.y + dy)
        if distanceBetween(point: p, segment: (pathStart, pathEnd)) < clearance {
          return false
        }
      }
    }
    return true
  }

  /// Determine if a potential spawn point is safe for a given amount of time,
  /// accounting for asteroid wrapping
  /// - Parameters:
  ///   - point: Candidate spawn
  ///   - time: Desired amount of safe time
  /// - Returns: `true` if the player won't get creamed by an asteroid within that
  ///   amount of time
  func isSafe(point: CGPoint, forDuration time: CGFloat) -> Bool {
    // time == 0 means I've tried and tried to find a safe spot, but there are just
    // way too many asteroids.  In that case, say that the point is safe and let them
    // trust to luck.
    if time > 0 {
      let playerRadius = 0.5 * player.shipTexture.size().diagonal()
      for asteroid in asteroids {
        // Don't check safety for spawning asteroids!  They're off the screen, so the
        // image-ship method that I use for safety could wind up thinking that the
        // center of the screen isn't safe.
        let asteroidBody = asteroid.requiredPhysicsBody()
        guard asteroidBody.isOnScreen else { continue }
        let asteroidRadius = 0.5 * asteroid.requiredTexture().size().diagonal()
        let pathStart = asteroid.position
        let pathEnd = asteroid.position + asteroidBody.velocity.scale(by: time)
        if !isSafe(point: point, pathStart: pathStart, pathEnd: pathEnd, clearance: asteroidRadius + playerRadius) {
          return false
        }
      }
    }
    return true
  }

  /// Update the reserve ships
  /// - Parameter amount: The amount by which to change the number of reserves
  func updateReserves(_ amount: Int) {
    reservesRemaining += amount
    reservesDisplay.showReserves(reservesRemaining)
  }

  // MARK: - Player lasers

  /// Handle the player's request to shoot
  ///
  /// Doesn't actually shoot if they have insufficient energy or too many shots
  /// in-flight
  ///
  /// - Returns: `true` if a shot was fired
  func fireLaser() -> Bool {
    guard player.canShoot(energyBar) else { return false }
    let laser = Globals.spriteCache.findSprite(imageNamed: "lasersmall_green") { sprite in
      let texture = sprite.requiredTexture()
      // The physics body is just a little circle at the front end of the laser,
      // since that's likely to be the first and only thing that will hit an object
      // anyway.
      let ht = texture.size().height
      let body = SKPhysicsBody(circleOfRadius: 0.5 * ht,
                               center: CGPoint(x: 0.5 * (texture.size().width - ht), y: 0))
      body.allowsRotation = false
      body.linearDamping = 0
      body.categoryBitMask = ObjectCategories.playerShot.rawValue
      body.collisionBitMask = 0
      body.contactTestBitMask = setOf([.asteroid, .ufo])
      sprite.physicsBody = body
    }
    laser.wait(for: 0.9) { self.laserExpired(laser) }
    playfield.addWithScaling(laser)
    player.shoot(laser: laser)
    audio.soundEffect(.playerShot, at: player.position)
    return true
  }

  /// Remove a laser; recycles the sprite and tells the player's ship so that it can
  /// update its shots-in-flight count
  func removeLaser(_ laser: SKSpriteNode) {
    assert(laser.name == "lasersmall_green")
    Globals.spriteCache.recycleSprite(laser)
    player.laserDestroyed()
  }

  /// This is called as a laser's end-of-life action.  It removes the laser, plus
  /// subclasses can override this if they need to do some extra processing.
  func laserExpired(_ laser: SKSpriteNode) {
    removeLaser(laser)
  }

  // MARK: - Hyperspace jumps

  /// Turn on/off the scene's special retro effects shader
  ///
  /// Turning on retro also changes the filter used in the game area when the scene
  /// is paused, since the standard Gaussian blur doesn't work well with retro mode's
  /// edge-detect shader.
  ///
  /// - Parameter enabled: `true` to enable retro mode
  func setRetroFilter(enabled: Bool) {
    if enabled {
      gameArea.shader = BasicScene.pauseShaderRetro
    } else {
      gameArea.shader = BasicScene.pauseShaderModern
    }
    shouldEnableEffects = enabled
  }

  /// Turn on/off retro mode
  ///
  /// Retro mode happens when the player jumps to hyperspace while on a score that
  /// ends in 79 (in honor of the 1979 release of the original Asteroids game).
  /// Retro mode involves two changes:
  /// 1. The ship is changed to look something like the original Asteroids game.
  /// 2. The scene's shader is turned on, which switches to a black-and-white edge
  /// detect filter that tries to mimic the look of the original game.
  ///
  /// Once retro mode has been discovered, it can be enabled by default in the
  /// settings.  Playing a whole game in retro mode earns the auldLangSyne
  /// achievement.
  ///
  /// - Parameter enabled: `true` to enable retro mode
  func setRetroMode(enabled: Bool) {
    setRetroFilter(enabled: enabled)
    player.setAppearance(to: enabled ? .retro : .modern)
    reservesDisplay.retroMode = enabled
    if !enabled {
      onlyRetro = false
    }
  }

  /// Handle the player's jump request
  ///
  /// They still need sufficient energy or they're not going anywhere
  func hyperspaceJump() {
    guard player.canJump(energyBar) else {
      if player.parent != nil {
        // They didn't jump due to lack of energy
        audio.soundEffect(.warpFail, at: player.position)
      }
      return
    }
    // I have the achievement checking and retro effect enabling/disabling here just
    // because it's convenient.  The tutorial always has score == 0, so those parts
    // are not active in the tutorial.
    let blastFromThePast = (score % 100 == 79)
    let backToTheFuture = (score % 100 == 88)
    addToPlayfield(player.warpOut())
    audio.soundEffect(.warpOut, at: player.position)
    // Don't stick them at the very edge of the screen since it looks odd
    let jumpRegion = gameFrame.insetBy(dx: 0.05 * gameFrame.width, dy: 0.05 * gameFrame.height)
    let jumpPosition = CGPoint(x: .random(in: jumpRegion.minX ... jumpRegion.maxX),
                               y: .random(in: jumpRegion.minY ... jumpRegion.maxY))
    wait(for: 1) { [weak self] in
      // Be a little paranoid in this one, since it's possible for the player to warp
      // and then pause and force-quit the scene (or for the tutorial scene to exit
      // automatically at the end).  I'm pretty sure everything would be OK even
      // without the weak self, but better safe than sorry.
      guard let self else { return }
      if blastFromThePast && !self.shouldEnableEffects {
        // Warping at a score ending in 79 (to honor Asteroid's 1979 release) turns
        // on retro mode
        self.setRetroMode(enabled: true)
        reportAchievement(achievement: .blastFromThePast)
      } else if backToTheFuture && self.shouldEnableEffects {
        // Warping at a score ending in 88 (MPH) when in retro mode deactivates retro
        // and goes Back to the Future
        self.setRetroMode(enabled: false)
        reportAchievement(achievement: .backToTheFuture)
      }
      self.audio.soundEffect(.warpIn, at: jumpPosition)
      self.player.warpIn(to: jumpPosition, atAngle: .random(in: 0 ... 2 * .pi), addTo: self.playfield)
    }
  }

  // MARK: - Energy regeneration

  /// Add a bit to the player's energy reserves and then reschedule `replenishEnergy`
  func replenishEnergy() {
    if player.parent != nil {
      energyBar.addToLevel(5)
    }
    wait(for: 0.5, then: replenishEnergy)
  }

  /// Subclasses override this, but be sure to call super to set up button bindings
  override func didMove(to view: SKView) {
    super.didMove(to: view)
    bindControllerPlayButtons()
  }
}
