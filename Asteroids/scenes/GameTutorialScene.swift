//
//  GameTutorialScene.swift
//  Asteroids
//
//  Created by David Long on 9/24/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

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
  /// The player's spaceship
  var player: Ship!
  /// Points earned; this is in GameTutorialScene only because `hyperspaceJump()`
  /// refers to it.  See the comments there.
  var score = 0
  /// The display of the number of reserve ships
  var livesDisplay: ReservesDisplay!
  /// How many reserve ships they have left; the current ship doesn't count in this.
  var livesRemaining = 0
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
    livesDisplay = ReservesDisplay()
    livesDisplay.position = CGPoint(x: gameFrame.minX + 20, y: gameFrame.maxY - 20)
    info.addChild(livesDisplay)
    // Energy reserves in upper right
    energyBar = EnergyBar(maxLength: 20)
    info.addChild(energyBar)
    energyBar.position = CGPoint(x: gameFrame.maxX - 20, y: gameFrame.maxY - 20)
    let pauseControls = SKNode()
    // The pause/continue/quit controls are directly under the scene in the hierarchy
    // and _not_ under gameArea, so they don't get blurred when the game pauses
    addChild(pauseControls)
    pauseControls.name = "pauseControls"
    pauseControls.setZ(.info)
    let pauseTexture = Globals.textureCache.findTexture(imageNamed: "pause")
    pauseButton = Touchable(SKSpriteNode(texture: pauseTexture, size: pauseTexture.size())) {
      [unowned self] in self.doPause()
    }
    // The pause icon sits just below the remaining ships and is mostly transparent.
    // When touched, it'll hide itself and show the continue/quit buttons.
    pauseButton.alpha = 0.1
    pauseButton.position = CGPoint(x: gameFrame.minX + pauseTexture.size().width / 2 + 10,
                                   y: livesDisplay.position.y - pauseTexture.size().height / 2 - 20)
    pauseControls.addChild(pauseButton)
    // Two nice big buttons in the center of the screen for continue and quit.
    // They're only unhidden when the game pauses.
    let buttonSize = CGSize(width: 250, height: 200)
    continueButton = Button(imageNamed: "bigplaybutton", imageColor: AppAppearance.playButtonColor, size: buttonSize)
    continueButton.action = { [unowned self] in self.doContinue() }
    continueButton.position = CGPoint(x: gameFrame.midX - 0.5 * buttonSize.width - 50, y: gameFrame.midY)
    continueButton.isHidden = true
    pauseControls.addChild(continueButton)
    quitButton = Button(imageNamed: "bigcancelbutton", imageColor: AppAppearance.dangerButtonColor, size: buttonSize)
    quitButton.action = { [unowned self] in self.doQuit() }
    quitButton.position = CGPoint(x: 2 * gameFrame.midX - continueButton.position.x, y: continueButton.position.y)
    quitButton.isHidden = true
    pauseControls.addChild(quitButton)
  }

  /// Make a game or tutorial scene of a given size
  /// - Parameter size: The size of the scene
  override init(size: CGSize) {
    super.init(size: size)
    name = "gameTutorialScene"
    initGameArea(avoidSafeArea: true)
    initInfo()
    isUserInteractionEnabled = true
    physicsWorld.contactDelegate = self
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
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
      if location.x * (UserData.joystickOnLeft.value ? 1 : -1) > fullFrame.midX {
        // Touches on this side are for firing or warping
        fireOrWarpTouches[touch] = location
      } else if joystickTouch == nil {
        // Touches on this side are for the (virtual) joystick
        joystickLocation = location
        joystickTouch = touch
      } // Else the joystick is already active, so ignore the touch
    }
  }

  /// Returns `true` if a touch has moved enough to indicate a hyperspace jump request
  /// - Parameters:
  ///   - touch: The touch that moved
  ///   - startLocation: The location where the touch started
  func isJumpRequest(_ touch: UITouch, startLocation: CGPoint) -> Bool {
    // Normal coordinates are scaled to give 768 units vertically on the screen, but
    // for this I want to require a move of a certain physical distance on the
    // screen, so I need to convert to points.
    return (touch.location(in: self) - startLocation).length() > Globals.ptsToGameUnits * 100
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
        let delta = (location - joystickLocation).rotate(by: -.pi / 2)
        let offset = delta.length()
        // Measure the movement in terms of a certain physical distance, so convert to points
        joystickDirection = delta.scale(by: min(offset / (Globals.ptsToGameUnits * 0.5 * 100), 1.0) / offset)
      } else {
        guard let startLocation = fireOrWarpTouches[touch] else { continue }
        // Jump without waiting for a touchesEnded(), since the situation is likely a
        // bit urgent ;-)
        if isJumpRequest(touch, startLocation: startLocation) {
          fireOrWarpTouches.removeValue(forKey: touch)
          hyperspaceJump()
        }
      }
    }
  }

  /// Handle the end of touches for the ship controls
  /// - Parameters:
  ///   - touches: The touches that finished
  ///   - event: The event the touches belong to
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    // Don't guard at the beginning with gamePaused!  A touch that started while the
    // game was active should still be removed from what I'm tracking if the player
    // pauses the game and then ends the touch.
    for touch in touches {
      if touch == joystickTouch {
        // Reset the joystick as soon as they lift their finger
        joystickDirection = .zero
        joystickTouch = nil
      } else {
        guard let startLocation = fireOrWarpTouches.removeValue(forKey: touch) else { continue }
        // Now that I've removed the touch from tracking, ignore the action requests
        // if the game is paused.
        guard !gamePaused else { continue }
        if isJumpRequest(touch, startLocation: startLocation) {
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
    touchesEnded(touches, with: event)
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
  }

  /// Abort the game/tutorial immediately and go back to the main menu
  func doQuit() {
    guard beginSceneSwitch() else { fatalError("doQuit in GameTutorialScene found scene switch in progress???") }
    audio.stop()
    switchScene(to: Globals.menuScene)
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
    logging("\(name!) finished willMove from view")
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
  func updateLives(_ amount: Int) {
    livesRemaining += amount
    livesDisplay.showReserves(livesRemaining)
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
      if let filter = CIFilter(name: "CICrystallize") {
        filter.setValue(10, forKey: kCIInputRadiusKey)
        gameArea.filter = filter
        gameArea.shouldCenterFilter = true
      } else {
        gameArea.filter = nil
      }
    } else {
      if let filter = CIFilter(name: "CIGaussianBlur") {
        filter.setValue(10, forKey: kCIInputRadiusKey)
        gameArea.filter = filter
        gameArea.shouldCenterFilter = true
      } else {
        gameArea.filter = nil
      }
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
  /// - Parameter enabled: `true` to enable retro mode
  func setRetroMode(enabled: Bool) {
    setRetroFilter(enabled: enabled)
    player.setAppearance(to: enabled ? .retro : .modern)
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
    wait(for: 1) {
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
}
