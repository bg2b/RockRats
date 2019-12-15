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
  /// The sound volume button
  var volumeButton: Button!
  /// The heartbeat on/off button
  var heartbeatButton: Button!
  /// The controls left/right button
  var controlsButton: Button!
  /// Ship appearance button (normal, retro)
  var retroButton: Button!
  /// The button that resets the achievements in Game Center
  var resetAchievementsButton: Button!

  static func stackedLabels(_ lines: [String], fontColor: UIColor) -> SKNode {
    let stack = SKNode()
    let fontSize = CGFloat(30)
    var nextY = CGFloat(0)
    for line in lines {
      let label = SKLabelNode(fontNamed: AppAppearance.font)
      label.fontSize = fontSize
      label.fontColor = fontColor
      label.text = line
      label.horizontalAlignmentMode = .center
      label.verticalAlignmentMode = .center
      label.position = CGPoint(x: 0, y: nextY)
      nextY -= fontSize
      stack.addChild(label)
    }
    let currentMidY = stack.calculateAccumulatedFrame().midY
    stack.position = CGPoint(x: 0, y: -currentMidY)
    return stack
  }

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
    let buttonSize = CGSize(width: 150, height: 100)
    let buttonSpacing = CGFloat(20)
    // Main menu button
    let menuButton = Button(imageNamed: "homebutton", imageColor: AppAppearance.buttonColor, size: buttonSize)
    menuButton.action = { [unowned self] in self.mainMenu() }
    // Play button
    let playButton = Button(imageNamed: "playbutton", imageColor: AppAppearance.playButtonColor, size: buttonSize)
    playButton.action = { [unowned self] in self.startGame() }
    // Game credits
    let creditsButton = Button(imageNamed: "infobutton", imageColor: AppAppearance.buttonColor, size: buttonSize)
    creditsButton.action = { [unowned self] in self.showCredits() }
    let bottomHstack = horizontalStack(nodes: [menuButton, playButton, creditsButton], minSpacing: buttonSpacing)
    bottomHstack.position = CGPoint(x: bottomHstack.position.x,
                                    y: fullFrame.minY + buttonSize.height + buttonSpacing - bottomHstack.position.y)
    settings.addChild(bottomHstack)

    // Replaying intro, tutorial, etc.
    var replayTypes = ["Intro", "Help"]
    if achievementIsCompleted(.promoted) {
      replayTypes.append("Ending")
    }
    var replayButtons = [Button]()
    for replayType in replayTypes {
      let labelStack = SettingsScene.stackedLabels(["Replay", replayType], fontColor: AppAppearance.textColor)
      let replayButton = Button(forNode: labelStack, size: buttonSize)
      replayButton.name = "replay" + replayType + "Button"
      replayButtons.append(replayButton)
    }
    replayButtons[0].action = { [unowned self] in self.replayIntro() }
    replayButtons[1].action = { [unowned self] in self.replayTutorial() }
    if replayButtons.count >= 3 {
      replayButtons[2].action = { [unowned self] in self.replayConclusion() }
    }
    let replayHstack = horizontalStack(nodes: replayButtons, minSpacing: buttonSpacing)
    // Resetting scores and achievements
    let resetButtonImages = ["resetscores", "resetgamecenter"]
    var resetButtons = [Button]()
    for resetImage in resetButtonImages {
      let resetButton = Button(imageNamed: resetImage, imageColor: AppAppearance.dangerButtonColor, size: buttonSize)
      resetButton.name = resetImage + "Button"
      resetButton.requiresConfirmation(SettingsScene.stackedLabels(["Confirm", "Reset"],
                                                                   fontColor: AppAppearance.dangerButtonColor))
      resetButtons.append(resetButton)
    }
    resetButtons[0].action = { [unowned self] in self.resetScores() }
    resetButtons[1].action = { [unowned self] in self.resetAchievements() }
    resetAchievementsButton = resetButtons[1]
    NotificationCenter.default.addObserver(self, selector: #selector(gcStateChanged), name: .authenticationChanged, object: nil)
    if !Globals.gcInterface.enabled {
      resetAchievementsButton.disable()
    }
    let resetHstack = horizontalStack(nodes: resetButtons, minSpacing: buttonSpacing)
    // Options like sound volume and control preferences
    var optionButtons = [Button]()
    volumeButton = Button(imagesNamed: ["soundnone", "soundsmall", "soundmed", "soundbig"],
                          imageColor: AppAppearance.buttonColor, size: buttonSize)
    volumeButton.selectedValue = UserData.audioLevel.value
    volumeButton.action = { [unowned self] in self.setVolume() }
    optionButtons.append(volumeButton)
    heartbeatButton = Button(imagesNamed: ["heartbeatoff", "heartbeaton"],
                             imageColor: AppAppearance.buttonColor, size: buttonSize)
    heartbeatButton.selectedValue = UserData.heartbeatMuted.value ? 0 : 1
    heartbeatButton.action = { [unowned self] in self.toggleHeartbeat() }
    if volumeButton.selectedValue == 0 {
      heartbeatButton.disable()
    }
    optionButtons.append(heartbeatButton)
    controlsButton = Button(imagesNamed: ["controlsleft", "controlsright"],
                            imageColor: AppAppearance.buttonColor, size: buttonSize)
    controlsButton.selectedValue = UserData.joystickOnLeft.value ? 0 : 1
    controlsButton.action = { [unowned self] in self.toggleControls() }
    optionButtons.append(controlsButton)
    // This retro/modern selection is only available if the player has the
    // `blastFromThePast` achievement.
    if achievementIsCompleted(.blastFromThePast) {
      retroButton = Button(imagesNamed: ["shipmodern", "shipretro"], imageColor: .white, size: buttonSize)
      retroButton.selectedValue = (UserData.retroMode.value ? 1 : 0)
      retroButton.action = { [unowned self] in self.toggleRetro() }
      optionButtons.append(retroButton)
    }
    let optionsHstack = horizontalStack(nodes: optionButtons, minSpacing: buttonSpacing)

    let vstack = verticalStack(nodes: [replayHstack, resetHstack, optionsHstack], minSpacing: buttonSpacing)

    //vstack.addChild(resetAchievementsButton)
    let wantedMidY = 0.5 * (title.frame.minY + bottomHstack.calculateAccumulatedFrame().maxY)
    // Center verticalStack vertically at wantedMidY
    vstack.position = .zero
    let vstackY = round(wantedMidY - vstack.calculateAccumulatedFrame().midY)
    vstack.position = CGPoint(x: fullFrame.midX, y: vstackY)
    settings.addChild(vstack)
  }

  /// Create the settings scene
  /// - Parameter size: The size of the scene
  override init(size: CGSize) {
    logging("SettingsScene init")
    super.init(size: size)
    name = "settingsScene"
    initGameArea(avoidSafeArea: false)
    initSettings()
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  deinit {
    logging("SettingsScene deinit \(self.hash)")
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

  /// Start a new game
  func startGame() {
    guard beginSceneSwitch() else { return }
    switchToScene { GameScene(size: self.fullFrame.size) }
  }

  /// Display the credits scene
  func showCredits() {
    switchToScene { CreditsScene(size: self.fullFrame.size) }
  }

  /// Adjust the sound volume
  ///
  /// Scenes read userDefaults.audioLevel when they're constructed.  The main menu is
  /// special though, since it's only made once.  Its didMove(to:) will switch the
  /// sound as appropriate.
  func setVolume() {
    UserData.audioLevel.value = volumeButton.selectedValue
    audio.level = volumeButton.selectedValue
    audio.soundEffect(.playerShot)
    if volumeButton.selectedValue == 0 {
      heartbeatButton.disable()
    } else {
      heartbeatButton.enable()
    }
  }

  /// Toggle retro/modern appearance
  func toggleHeartbeat() {
    UserData.heartbeatMuted.value = (heartbeatButton.selectedValue == 0)
    if !UserData.heartbeatMuted.value {
      audio.soundEffect(.heartbeatHigh)
      wait(for: 0.25) {
        self.audio.soundEffect(.heartbeatLow)
      }
    }
  }

  /// Toggle controls left/right
  func toggleControls() {
    UserData.joystickOnLeft.value = (controlsButton.selectedValue == 0)
  }

  /// Toggle retro/modern appearance
  func toggleRetro() {
    UserData.retroMode.value = (retroButton.selectedValue == 1)
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
