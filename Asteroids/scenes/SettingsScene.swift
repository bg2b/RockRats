//
//  SettingsScene.swift
//  Asteroids
//
//  Created by David Long on 11/15/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

// MARK: Game settings

/// Game settings scene
///
/// Sound, credits, ship appearance (if the player discovered retro mode), replay
/// intro and tutorial (and conclusion if the player has found that), reset (local)
/// high scores, reset Game Center achievements.
///
/// I don't really like the way the central buttons are layed out.  Maybe I can
/// eventually think of something more attractive.
class SettingsScene: BasicScene {
  /// The sound on/off button
  var muteButton: Button!
  /// Ship appearance button (normal, retro)
  var retroButton: Button!
  /// The button that resets the achievements in Game Center
  var resetAchievementsButton: Button!

  // MARK: - Initialization

  /// Create the stuff the for the settings scene
  func initSettings() {
    let settings = SKNode()
    settings.name = "settings"
    settings.setZ(.info)
    addChild(settings)
    // Title
    let title = SKLabelNode(fontNamed: AppAppearance.font)
    title.fontSize = 100
    title.fontColor = AppAppearance.highlightTextColor
    title.text = "Settings"
    title.verticalAlignmentMode = .center
    title.position = CGPoint(x: fullFrame.midX, y: fullFrame.maxY - title.fontSize)
    settings.addChild(title)
    // Buttons at the bottom
    let bottomButtons = SKNode()
    bottomButtons.name = "bottomButtons"
    let buttonSize = CGSize(width: 150, height: 100)
    let buttonSpacing = CGFloat(20)
    var nextButtonX = CGFloat(0)
    // Main menu button
    let menuButton = Button(imageNamed: "homebutton", imageColor: AppAppearance.buttonColor, size: buttonSize)
    menuButton.action = { [unowned self] in self.mainMenu() }
    menuButton.position = CGPoint(x: nextButtonX, y: 0)
    nextButtonX += buttonSize.width + buttonSpacing
    bottomButtons.addChild(menuButton)
    // Sound on/off
    muteButton = Button(imagesNamed: ["soundon", "soundoff"], imageColor: AppAppearance.buttonColor, size: buttonSize)
    muteButton.selectedValue = (UserData.audioIsMuted.value ? 1 : 0)
    muteButton.action = { [unowned self] in self.toggleSound() }
    muteButton.position = CGPoint(x: nextButtonX, y: 0)
    nextButtonX += buttonSize.width + buttonSpacing
    bottomButtons.addChild(muteButton)
    // This retro/modern selection is only available if the player has the
    // `blastFromThePast` achievement.
    if achievementIsCompleted(.blastFromThePast) {
      retroButton = Button(imagesNamed: ["shipmodern", "shipretro"], imageColor: .white, size: buttonSize)
      retroButton.selectedValue = (UserData.retroMode.value ? 1 : 0)
      retroButton.action = { [unowned self] in self.toggleRetro() }
      retroButton.position = CGPoint(x: nextButtonX, y: 0)
      nextButtonX += buttonSize.width + buttonSpacing
      bottomButtons.addChild(retroButton)
    }
    // Game credits
    let creditsButton = Button(imageNamed: "infobutton", imageColor: AppAppearance.buttonColor, size: buttonSize)
    creditsButton.action = { [unowned self] in self.showCredits() }
    creditsButton.position = CGPoint(x: nextButtonX, y: 0)
    bottomButtons.addChild(creditsButton)
    bottomButtons.position = .zero
    let bottomFrame = bottomButtons.calculateAccumulatedFrame()
    let buttonY = fullFrame.minY + buttonSize.height + buttonSpacing
    // Center the bottom row of buttons on fullFrame.x, buttonY
    bottomButtons.position = CGPoint(x: fullFrame.midX - bottomFrame.midX, y: buttonY - bottomFrame.midY)
    settings.addChild(bottomButtons)
    // Now for the buttons in the middle.  I'll stick everything under a single node
    // (vstack) and then center that vertically between the title and the bottom
    // buttons.
    let vstack = SKNode()
    vstack.name = "vstack"
    let buttonFontSize = CGFloat(50)
    let textButtonSize = CGSize(width: 650, height: buttonFontSize)
    var nextButtonY = CGFloat(0)
    // Button to replay the intro scene.  This is also how to trigger the hidden
    // conclusion scene once the player has earned the top Rock Rat achievement.
    let introButton = Button(forText: "Introduction", fontSize: buttonFontSize, size: textButtonSize)
    introButton.name = "introButton"
    introButton.action = { [unowned self] in self.replayIntro() }
    introButton.position = CGPoint(x: 0, y: nextButtonY)
    nextButtonY -= introButton.calculateAccumulatedFrame().height + 0.5 * buttonSpacing
    vstack.addChild(introButton)
    // Replay tutorial
    let tutorialButton = Button(forText: "Tutorial", fontSize: buttonFontSize, size: textButtonSize)
    tutorialButton.name = "tutorialButton"
    tutorialButton.action = { [unowned self] in self.replayTutorial() }
    tutorialButton.position = CGPoint(x: 0, y: nextButtonY)
    nextButtonY -= tutorialButton.calculateAccumulatedFrame().height + 0.5 * buttonSpacing
    vstack.addChild(tutorialButton)
    // If they saw the conclusion once and got the promoted achievement, add a
    // separate button to replay the conclusion.
    if achievementIsCompleted(.promoted) {
      let conclusionButton = Button(forText: "Conclusion", fontSize: buttonFontSize, size: textButtonSize)
      conclusionButton.name = "introButton"
      conclusionButton.action = { [unowned self] in self.replayConclusion() }
      conclusionButton.position = CGPoint(x: 0, y: nextButtonY)
      nextButtonY -= conclusionButton.calculateAccumulatedFrame().height + 0.5 * buttonSpacing
      vstack.addChild(conclusionButton)
    }
    // Extra space before dangerous items
    nextButtonY -= buttonSpacing
    // Reset (local) high scores
    let resetScoresButton = Button(forText: "Reset Scores", confirmText: "Confirm Reset", fontSize: buttonFontSize, size: textButtonSize)
    resetScoresButton.name = "resetScoresButton"
    resetScoresButton.action = { [unowned self] in self.resetScores() }
    resetScoresButton.position = CGPoint(x: 0, y: nextButtonY)
    nextButtonY -= resetScoresButton.calculateAccumulatedFrame().height + 0.5 * buttonSpacing
    vstack.addChild(resetScoresButton)
    // Reset Game Center achievements
    resetAchievementsButton = Button(forText: "Reset Achievements", confirmText: "Confirm Reset", fontSize: buttonFontSize, size: textButtonSize)
    resetAchievementsButton.name = "resetAchievementsButton"
    resetAchievementsButton.action = { [unowned self] in self.resetAchievements() }
    resetAchievementsButton.position = CGPoint(x: 0, y: nextButtonY)
    // The resetAchievementsButton has to track the status of Game Center's
    // authentication.
    if !Globals.gcInterface.enabled {
      resetAchievementsButton.disable()
    }
    NotificationCenter.default.addObserver(self, selector: #selector(gcStateChanged), name: .authenticationChanged, object: nil)
    vstack.addChild(resetAchievementsButton)
    let wantedMidY = 0.5 * (title.frame.minY + bottomButtons.calculateAccumulatedFrame().maxY)
    // Center verticalStack vertically at wantedMidY
    vstack.position = .zero
    let vstackY = round(wantedMidY - vstack.calculateAccumulatedFrame().midY)
    vstack.position = CGPoint(x: fullFrame.midX, y: vstackY)
    settings.addChild(vstack)
  }

  /// Create the settings scene
  /// - Parameter size: The size of the scene
  override init(size: CGSize) {
    super.init(size: size)
    name = "settingsScene"
    initGameArea(avoidSafeArea: false)
    initSettings()
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  // MARK: - Button actions

  /// Replay the intro scene
  ///
  /// If they've reached the top level but have not seen the conclusion screen, then
  /// this instead triggers the promoted achievement and shows the conclusion.  Once
  /// the promoted achievement has been done, then there will be a separate replay
  /// conclusion button.
  func replayIntro() {
    guard beginSceneSwitch() else { return }
    var showConclusion = false
    if levelIsReached(achievement: .rockRat, level: 3) && !achievementIsCompleted(.promoted) {
      // Game Center has to be enabled to get here, since levelIsReached will have
      // returned false if it was not enabled.
      reportAchievement(achievement: .promoted)
      showConclusion = true
    }
    switchToScene { IntroScene(size: self.fullFrame.size, conclusion: showConclusion) }
  }

  /// Replay the conclusion scene
  func replayConclusion() {
    guard beginSceneSwitch() else { return }
    switchToScene { IntroScene(size: self.fullFrame.size, conclusion: true) }
  }

  /// Replay the tutorial
  func replayTutorial() {
    guard beginSceneSwitch() else { return }
    switchToScene { TutorialScene(size: self.fullFrame.size) }
  }

  /// Go back to the main menu
  func mainMenu() {
    guard beginSceneSwitch() else { return }
    showWhenQuiescent(Globals.menuScene)
  }

  /// Turn the sound on and off
  ///
  /// Scenes read userDefaults.audioIsMuted when they're constructed.  The main menu
  /// is special though, since it's only made once.  Its didMove(to:) will switch the
  /// sound as appropriate.
  func toggleSound() {
    if muteButton.selectedValue == 1 {
      // Muted
      audio.muted = true
      UserData.audioIsMuted.value = true
    } else {
      audio.muted = false
      UserData.audioIsMuted.value = false
    }
  }

  /// Toggle retro/modern appearance
  func toggleRetro() {
    UserData.retroMode.value = (retroButton.selectedValue == 1)
  }

  /// Display the credits scene
  func showCredits() {
    switchToScene { CreditsScene(size: self.fullFrame.size) }
  }

  /// Reset all local high scores
  func resetScores() {
    UserData.highScores.reset()
    logging("Scores reset")
  }

  // MARK: - Game Center

  /// Reset all Game Center achievements
  ///
  /// We also have to reset the game counters for things like asteroids and UFOs
  /// destroyed, which requires syncing through iCloud.
  func resetAchievements() {
    if let gc = Globals.gcInterface, gc.enabled {
      gc.resetAchievements()
      UserData.ufosDestroyed.value = 0
      UserData.asteroidsDestroyed.value = 0
      // Assigning a negative value means to force the iCloud-synchronized per-player
      // values to zero.
      UserData.ufosDestroyedCounter.value = -1
      UserData.asteroidsDestroyedCounter.value = -1
      logging("Achievements reset")
    }
  }

  /// The Game Center status has changed, so update `resetAchievementsButton`'s
  /// enabled/disabled state to match
  /// - Parameter notification: A notification indicating what happened
  @objc func gcStateChanged(_ notification: Notification) {
    logging("Settings scene got notification of Game Center state change")
    if notification.object as? Bool ?? false {
      resetAchievementsButton.enable()
    } else {
      resetAchievementsButton.disable()
    }
  }

  override func didMove(to view: SKView) {
    super.didMove(to: view)
    logging("\(name!) finished didMove to view")
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
  }
}
