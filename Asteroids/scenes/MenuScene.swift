//
//  MenuScene.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import SpriteKit
import GameKit
import StoreKit
import os.log

// MARK: Main menu

/// The main menu scene
///
/// There's only one of these, created at start on app launch and stored in
/// `Globals.menuScene`.  It dispatches to the other important scenes (settings, high
/// scores, and starting a new game).
///
/// This scene is the one that handles Game Center authentication in case the player
/// is not already logged in when the app launches.
///
/// There's a little asteroid + UFO animation that plays in the background.  Tapping
/// on objects destroys them, and there's a hidden `tooMuchTime` achievement if they
/// sit around and tap enough in one go.
class MenuScene: BasicScene {
  /// A count of how many shots have been fired by a UFO; they don't warp out until
  /// they've fired a few shots.
  var shotsToFire = [UFO: Int]()
  /// Becomes `true` before a scene transition, stops UFO spawning and shooting
  var getRidOfUFOs = false
  /// How many UFOs or asteroids the player has tapped on
  var bubblesPopped = 0
  /// A label showing the top local score
  var highScore: SKLabelNode!
  /// When Game Center authentication is needed, Game Center will pass a view
  /// controller that is stored here.
  ///
  /// The next time the menu is displayed, this will be presented.  `nil` means
  /// either Game Center is successfully authenticated or that it's given up.
  weak var gameCenterAuthVC: UIViewController?
  /// `true` when `gameCenterAuthVC` is being shown
  var presentingGCAuth = false

  // MARK: - Initialization

  /// Build all the stuff in the menu
  func initMenu() {
    let menu = SKNode()
    menu.name = "menu"
    menu.setZ(.info)
    addChild(menu)
    // Title mostly centered
    let title = SKLabelNode(fontNamed: AppAppearance.font)
    title.fontSize = 125
    title.fontColor = AppAppearance.highlightTextColor
    title.text = "ROCK RATS"
    title.verticalAlignmentMode = .center
    title.position = CGPoint(x: fullFrame.midX, y: 0.875 * fullFrame.midY + 0.125 * fullFrame.maxY)
    menu.addChild(title)
    // High score below the title
    highScore = SKLabelNode(fontNamed: AppAppearance.font)
    highScore.fontSize = 50
    highScore.fontColor = AppAppearance.highlightTextColor
    highScore.verticalAlignmentMode = .center
    highScore.position = CGPoint(x: fullFrame.midX, y: 0.75 * fullFrame.midY + 0.125 * fullFrame.minY)
    menu.addChild(highScore)
    // Buttons at the bottom
    let buttonSize = CGSize(width: 150, height: 100)
    let buttonSpacing = CGFloat(20)
    // New game
    let playButton = Button(imageNamed: "playbutton", imageColor: AppAppearance.playButtonColor, size: buttonSize)
    playButton.action = { [unowned self] in self.startGame() }
    // High scores
    let highScoresButton = Button(imageNamed: "highscoresbutton", imageColor: AppAppearance.buttonColor, size: buttonSize)
    highScoresButton.action = { [unowned self] in self.showHighScores() }
    // Settings
    let settingsButton = Button(imageNamed: "settingsbutton", imageColor: AppAppearance.buttonColor, size: buttonSize)
    settingsButton.action = { [unowned self] in self.showSettings() }
    buttons = [settingsButton, playButton, highScoresButton]
    defaultFocus = playButton
    let bottomHstack = horizontalStack(nodes: buttons, minSpacing: buttonSpacing)
    bottomHstack.position = CGPoint(x: bottomHstack.position.x,
                                    y: fullFrame.minY + buttonSize.height + buttonSpacing - bottomHstack.position.y)
    menu.addChild(bottomHstack)
  }

  /// Create a new menu scene
  /// - Parameter size: The size of the scene
  override init(size: CGSize) {
    super.init(size: size)
    name = "menuScene"
    initGameArea(avoidSafeArea: false)
    initMenu()
    physicsWorld.contactDelegate = self
    isUserInteractionEnabled = true
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // MARK: - Button actions

  /// Make the UFOs go away in preparation for a scene switch
  ///
  /// Also stops any pending review request
  func prepareForSwitch() {
    cancelReviewRequest()
    getRidOfUFOs = true
    _ = warpOutUFOs(averageDelay: 0.25)
  }

  /// Go to the game settings
  func showSettings() {
    guard beginSceneSwitch() else { return }
    prepareForSwitch()
    switchWhenQuiescent { SettingsScene(size: self.fullFrame.size) }
  }

  /// Start a new game
  func startGame() {
    guard beginSceneSwitch() else { return }
    prepareForSwitch()
    switchWhenQuiescent { GameScene(size: self.fullFrame.size) }
  }

  /// Show the high scores screen
  func showHighScores() {
    guard beginSceneSwitch() else { return }
    prepareForSwitch()
    switchWhenQuiescent { HighScoreScene(size: self.fullFrame.size, score: nil) }
  }

  // MARK: - Game Center authentication

  /// Enforce pausing if the Game Center authentication controller is shown.
  override var forcePause: Bool { presentingGCAuth }

  /// Game Center calls this to request authentication
  ///
  /// When this gets called with `nil`, it means either that Game Center is now
  /// successfully authenticated, or that it's given up trying to authenticate
  /// because the player dismissed the authentication view controller.
  ///
  /// This method just stores the view controller.  When the menu scene is shown and
  /// the stored view controller isn't `nil`, then it will be presented.
  ///
  /// - Parameter viewController: A view controller to show for authentication, `nil`
  ///   if nothing to show
  func setGameCenterAuth(viewController: UIViewController?) {
    gameCenterAuthVC = viewController
    if gameCenterAuthVC == nil {
      os_log("MenuScene clears Game Center view controller", log: .app, type: .debug)
      presentingGCAuth = false
      isPaused = false
    } else {
      os_log("MenuScene sets Game Center view controller", log: .app, type: .debug)
    }
  }

  /// Check if Game Center wants to authenticate, and show its view controller if so
  func gameCenterAuth() {
    if let gcvc = gameCenterAuthVC, !presentingGCAuth, let rootVC = view?.window?.rootViewController {
      os_log("MenuScene will present Game Center view controller", log: .app, type: .debug)
      presentingGCAuth = true
      isPaused = true
      rootVC.present(gcvc, animated: true)
    }
  }

  // MARK: - Reviews

  /// Ask for a review and save the number of games played
  func askForReview() {
    if let windowScene = view?.window?.windowScene {
      SKStoreReviewController.requestReview(in: windowScene)
      UserData.reviewsRequested.value += 1
      UserData.gamesPlayedWhenReviewRequested.value = UserData.gamesPlayed.value
    }
  }

  /// If the user wants to move on, stop the action that would request a review
  func cancelReviewRequest() {
    removeAction(forKey: "askForReview")
  }

  // MARK: - Coming back to the menu

  /// Set up for the menu scene to be shown and kick off the background animation
  ///
  /// This is a little more involved than for most scenes because there's only one
  /// menu scene that is created, and it is returned to repeatedly.  The reason for
  /// having just one scene is because it looks better for the asteroids and things
  /// to stick around rather than starting with an empty scene every time.
  ///
  /// - Parameter view: The view that will show the menu
  override func didMove(to view: SKView) {
    super.didMove(to: view)
    if switchingScenes {
      // Getting here means that this is a transition back to the menu after doing
      // something.  See about asking for a review.
      let gamesSinceLastReview = UserData.gamesPlayed.value - UserData.gamesPlayedWhenReviewRequested.value
      let numRequests = UserData.reviewsRequested.value
      let gamesBeforeAsking = [5, 10, 20]
      if gamesSinceLastReview >= gamesBeforeAsking[min(numRequests, gamesBeforeAsking.count - 1)] {
        // A reasonable number of games have been played since the last request.  If
        // they stick around long enough, then poke them to leave a review.
        run(.wait(for: 2) { self.askForReview() }, withKey: "askForReview")
      }
    }
    // Any earlier scene transition that the menu initiated has obviously finished,
    // so reset the switching flag
    switchingScenes = false
    // If a touch was in progress for some button and the user pressed another button
    // that caused a scene transition, then the first button will be stuck in a
    // half-touched state when we come back to the menu.  So be sure to clear the
    // state of all the buttons.
    buttons.forEach { $0.resetAndCancelConfirmation() }
    // Set up controller
    bindControllerMenuButtons()
    // The player may have adjusted the audio level in the settings
    audio.level = UserData.audioLevel.value
    // Reset the number of things the player has tapped; they have to do the full
    // number in one go to get the `tooMuchTime` achievement.
    bubblesPopped = 0
    // The high score might have changed
    highScore.text = "High Score: \(UserData.highScores.highest)"
    // Allow UFOs
    getRidOfUFOs = false
    Globals.gameConfig = loadGameConfig(forMode: "menu")
    Globals.gameConfig.currentWaveNumber = 1
    // Allow spawning of a Little Prince asteroid
    littlePrinceAllowed = true
    // Kick off the regular spawning actions for UFOs and asteroids
    wait(for: 1, then: spawnAsteroids)
    // The first time into the menu there won't be any asteroids, so wait longer
    // before starting the UFOs to ensure that they'll have something to shoot at
    wait(for: (asteroids.count > 5 ? 5 : 10), then: spawnUFOs)
  }

  // MARK: - Touch handling

  /// For (non-button) touches, find asteroids or UFOs that are touched and destroy them
  /// - Parameters:
  ///   - touches: The touches that just began
  ///   - event: The event the touches belong to
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let location = touch.location(in: self)
    for touched in nodes(at: location) {
      // You can't destroy anything without a physics body
      guard let body = touched.physicsBody else { continue }
      if body.isA(.asteroid) {
        touchedAsteroid(touched as! SKSpriteNode)
      } else if body.isA(.ufo) {
        touchedUFO(touched as! UFO)
      }
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}

  // MARK: - Background animation

  /// Spawn an asteroid if there aren't many in existence
  ///
  /// Reschedules itself so that this runs repeatedly.
  func spawnAsteroids() {
    if asteroids.count < 15 {
      spawnAsteroid(size: [.big, .huge].randomElement()!)
    }
    wait(for: 1, then: spawnAsteroids)
  }

  /// Make a UFO if there are sufficient asteroids
  ///
  /// Reschedules itself so that this runs repeatedly.
  func spawnUFOs() {
    if !getRidOfUFOs && asteroids.count >= 3 && ufos.count < Globals.gameConfig.value(for: \.maxUFOs) {
      let ufo = UFO(audio: nil)
      spawnUFO(ufo: ufo)
      shotsToFire[ufo] = .random(in: 3 ... 10)
    }
    wait(for: 5, then: spawnUFOs)
  }

  /// Remove a UFO
  ///
  /// This is an override because I need to update `shotsToFire`.
  ///
  /// - Parameter ufo: The UFO that's being removed
  override func removeUFO(_ ufo: UFO) {
    shotsToFire.removeValue(forKey: ufo)
    super.removeUFO(ufo)
  }

  /// The player tapped something and destroyed it
  ///
  /// This handles the `tooMuchTime` achievement.
  func poppedSomething() {
    bubblesPopped += 1
    if let gc = Globals.gcInterface, gc.enabled, bubblesPopped == 100 {
      reportAchievement(achievement: .tooMuchTime)
    }
  }

  /// The player touched an asteroid
  /// - Parameter asteroid: The asteroid that they touched
  func touchedAsteroid(_ asteroid: SKSpriteNode) {
    splitAsteroid(asteroid)
    poppedSomething()
  }

  /// The player touched a UFO
  /// - Parameter ufo: The UFO that they touched
  func touchedUFO(_ ufo: UFO) {
    destroyUFO(ufo, collision: false)
    poppedSomething()
  }

  /// Handles all the possible physics engine contact notifications
  /// - Parameter contact: What contacted what
  func didBegin(_ contact: SKPhysicsContact) {
    when(contact, isBetween: .ufoShot, and: .asteroid) {
      ufoLaserHit(laser: $0, asteroid: $1)
    }
    when(contact, isBetween: .ufo, and: .asteroid) { ufoCollided(ufo: $0, asteroid: $1) }
    // The scene is written to allow multiple UFOs, in case I ever decide to enable
    // it in the configuration.
    when(contact, isBetween: .ufo, and: .ufo) { ufosCollided(ufo1: $0, ufo2: $1) }
  }

  /// Main update loop for the menu
  ///
  /// Moves UFOs and checks to see if Game Center wants to authenticate.
  ///
  /// - Parameter currentTime: The current game time
  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    ufos.forEach { ufo in
      ufo.fly(player: nil, playfield: playfield) { angle, position, speed in
        if !self.getRidOfUFOs {
          self.fireUFOLaser(angle: angle, position: position, speed: speed)
          self.shotsToFire[ufo] = self.shotsToFire[ufo]! - 1
          if self.shotsToFire[ufo]! == 0 {
            // Use a key here so that if the UFO happens to get destroyed before the
            // warp out, then the action can be cancelled.
            ufo.run(.wait(for: .random(in: 1 ... 3)) { self.warpOutUFO(ufo) }, withKey: "warpOut")
          }
        }
      }
    }
    playfield.wrapCoordinates()
    gameCenterAuth()
    endOfUpdate()
  }
}
