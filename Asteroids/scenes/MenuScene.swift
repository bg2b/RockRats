//
//  MenuScene.swift
//  Asteroids
//
//  Created by David Long on 9/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import GameKit

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
  var shotsFired = [UFO: Int]()
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
  weak var gameCenterAuthVC: UIViewController? = nil
  /// `true` when `gameCenterAuthVC` is being shown
  var presentingGCAuth = false
  /// All of the buttons used in the scene
  ///
  /// We need this because the menu is not reconstructed from scratch every time.
  /// When a transition happens, it's possible for a button to be in an intermediate
  /// state (e.g., the player might have touched two buttons at once, and only one
  /// can activate).  So the buttons have to be reset to their starting states upon
  /// coming back to the menu.
  var buttons = [Button]()

  /// Build all the stuff in the menu
  func initMenu() {
    let menu = SKNode()
    menu.name = "menu"
    menu.setZ(.info)
    addChild(menu)
    // Title mostly centered
    let title = SKLabelNode(fontNamed: AppColors.font)
    title.fontSize = 125
    title.fontColor = AppColors.highlightTextColor
    title.text = "ROCK RATS"
    title.verticalAlignmentMode = .center
    title.position = CGPoint(x: fullFrame.midX, y: 0.875 * fullFrame.midY + 0.125 * fullFrame.maxY)
    menu.addChild(title)
    // High score below the title
    highScore = SKLabelNode(fontNamed: AppColors.font)
    highScore.fontSize = 50
    highScore.fontColor = AppColors.highlightTextColor
    highScore.verticalAlignmentMode = .center
    highScore.position = CGPoint(x: fullFrame.midX, y: 0.75 * fullFrame.midY + 0.125 * fullFrame.minY)
    menu.addChild(highScore)
    // Buttons at the bottom
    let buttonSize = CGSize(width: 150, height: 100)
    let buttonSpacing = CGFloat(20)
    let buttonY = fullFrame.minY + buttonSize.height + buttonSpacing
    // New gamee
    let playButton = Button(imageNamed: "playbutton", imageColor: AppColors.green, size: buttonSize)
    playButton.position = CGPoint(x: fullFrame.midX, y: buttonY)
    playButton.action = { [unowned self] in self.startGame() }
    buttons.append(playButton)
    menu.addChild(playButton)
    // High scores
    let highScoresButton = Button(imageNamed: "highscoresbutton", imageColor: AppColors.blue, size: buttonSize)
    highScoresButton.position = CGPoint(x: playButton.position.x + buttonSize.width + buttonSpacing, y: playButton.position.y)
    highScoresButton.action = { [unowned self] in self.showHighScores() }
    buttons.append(highScoresButton)
    menu.addChild(highScoresButton)
    // Settings
    let settingsButton = Button(imageNamed: "settingsbutton", imageColor: AppColors.blue, size: buttonSize)
    settingsButton.position = CGPoint(x: playButton.position.x - buttonSize.width - buttonSpacing, y: playButton.position.y)
    settingsButton.action = { [unowned self] in self.showSettings() }
    buttons.append(settingsButton)
    menu.addChild(settingsButton)
  }

  /// Spawn an asteroid if there aren't many in existence
  ///
  /// Reschedules itself so that this runs repeatedly.
  func spawnAsteroids() {
    if asteroids.count < 15 {
      spawnAsteroid(size: ["big", "huge"].randomElement()!)
    }
    wait(for: 1) { self.spawnAsteroids() }
  }

  /// Make a UFO if there are sufficient asteroids
  ///
  /// Reschedules itself so that this runs repeatedly.
  func spawnUFOs() {
    if !getRidOfUFOs && asteroids.count >= 3 && ufos.count < Globals.gameConfig.value(for: \.maxUFOs) {
      let ufo = UFO(brothersKilled: 0, audio: nil)
      spawnUFO(ufo: ufo)
      shotsFired[ufo] = 0
    }
    wait(for: 5) { self.spawnUFOs() }
  }

  /// Make a UFO warp out; this is an override because I need to update `shotsFired`
  /// - Parameter ufo: The UFO that's leaving
  override func warpOutUFO(_ ufo: UFO) {
    shotsFired.removeValue(forKey: ufo)
    super.warpOutUFO(ufo)
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

  /// A UFO is being destroyed; this is an override because I need to update `shotsFired`
  /// - Parameter ufo: The UFO that is being nuked
  override func destroyUFO(_ ufo: UFO) {
    shotsFired.removeValue(forKey: ufo)
    super.destroyUFO(ufo)
  }

  /// The player touched a UFO
  /// - Parameter ufo: The UFO that they touched
  func touchedUFO(_ ufo: UFO) {
    destroyUFO(ufo)
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

  /// Make the UFOs go away in preparation for a scene switch
  func prepareForSwitch() {
    getRidOfUFOs = true
    _ = warpOutUFOs(averageDelay: 0.25)
  }

  /// Go to the game settings
  func showSettings() {
    prepareForSwitch()
    switchToScene { SettingsScene(size: self.fullFrame.size) }
  }

  /// Start a new game
  func startGame() {
    prepareForSwitch()
    switchToScene { GameScene(size: self.fullFrame.size) }
  }

  /// Show the high scores screen
  func showHighScores() {
    prepareForSwitch()
    switchToScene { HighScoreScene(size: self.fullFrame.size, score: nil) }
  }

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
      logging("\(name!) clears Game Center view controller")
      presentingGCAuth = false
      isPaused = false
    } else {
      logging("\(name!) sets Game Center view controller")
    }
  }

  /// Check if Game Center wants to authenticate, and show its view controller if so
  func gameCenterAuth() {
    if let gcvc = gameCenterAuthVC, !presentingGCAuth, let rootVC = view?.window?.rootViewController {
      logging("\(name!) will present Game Center view controller")
      presentingGCAuth = true
      isPaused = true
      rootVC.present(gcvc, animated: true)
    }
  }

  /// Set up for the menu scene to be shown
  ///
  /// This is a little more involved than for most scenes because there's only one
  /// menu scene that is created, and it is returned to repeatedly.  The reason for
  /// having just one scene is because it looks better for the asteroids and things
  /// to stick around rather than starting with an empty scene every time.
  ///
  /// - Parameter view: The view that will show the menu
  override func didMove(to view: SKView) {
    super.didMove(to: view)
    // If a touch was in progress for some button and the user pressed another button
    // that caused a scene transition, then the first button will be stuck in a
    // half-touched state when we come back to the menu.  So be sure to clear the
    // state of all the buttons.
    buttons.forEach { $0.resetTouch() }
    // The player may have turned audio on or off in the settings.
    audio.muted = userDefaults.audioIsMuted.value
    // Reset the number of things the player has tapped; they have to do the full
    // number in one go to get the `tooMuchTime` achievement.
    bubblesPopped = 0
    // The high score might have changed.
    highScore.text = "High Score: \(userDefaults.highScores.highest)"
    // Allow UFOs
    getRidOfUFOs = false
    Globals.gameConfig = loadGameConfig(forMode: "menu")
    Globals.gameConfig.currentWaveNumber = 1
    // Now start the regular spawning actions for UFOs and asteroids
    wait(for: 1) { self.spawnAsteroids() }
    wait(for: 10) { self.spawnUFOs() }
    logging("\(name!) finished didMove to view")
  }

  /// Main update loop for the menu
  ///
  /// Moves UFOs and checks to see if Game Center wants to authenticate.
  ///
  /// - Parameter currentTime: The current game time
  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    ufos.forEach { ufo in
      ufo.fly(player: nil, playfield: playfield) { (angle, position, speed) in
        if !self.getRidOfUFOs {
          self.fireUFOLaser(angle: angle, position: position, speed: speed)
          self.shotsFired[ufo] = self.shotsFired[ufo]! + 1
          if self.shotsFired[ufo]! > 3 && Int.random(in: 0 ..< 10) == 0 {
            self.warpOutUFO(ufo)
          }
        }
      }
    }
    playfield.wrapCoordinates()
    gameCenterAuth()
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

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}
