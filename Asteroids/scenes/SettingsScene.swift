//
//  SettingsScene.swift
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
  /// The UFO sound continous/fading button
  var ufoFadeButton: Button!
  /// The button for selecting the initial wave
  var startingWaveButton: Button!
  /// The show touches button
  var showTouchesButton: Button!
  /// Selector for setting thrust via controller joystick vs A/B buttons
  var joystickThrustButton: Button!
  /// Selector for enabling or disabling haptics
  var hapticsButton: Button!
  /// Unlocked ship styles
  var shipStyles = [String]()
  /// Ship appearance button (chooses modern of various colors or retro)
  var shipStyleButton: Button!
  /// The button that resets the achievements in Game Center
  var resetAchievementsButton: Button!
  /// The current fortune being shown, `nil` if none
  var fortuneNode: SKNode?
  /// The most recent fortunes
  var recentFortunes = Set<String>()

  // MARK: - Initialization

  /// Create the stuff the for the settings scene
  func initSettings() {
    let settings = SKEffectNode()
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
    buttons = [menuButton, playButton, creditsButton]
    defaultFocus = playButton
    let bottomHstack = horizontalStack(nodes: buttons, minSpacing: buttonSpacing)
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
      let labelStack = stackedLabels(["Replay", replayType], fontColor: AppAppearance.textColor)
      let replayButton = Button(forNode: labelStack, size: buttonSize)
      replayButton.name = "replay" + replayType + "Button"
      replayButtons.append(replayButton)
    }
    replayButtons[0].action = { [unowned self] in self.replayIntro() }
    replayButtons[1].action = { [unowned self] in self.replayTutorial() }
    if replayButtons.count >= 3 {
      replayButtons[2].action = { [unowned self] in self.replayConclusion() }
    }
    buttons.append(contentsOf: replayButtons)
    // Resetting scores and achievements
    let resetButtonImages = ["resetscores", "resetgamecenter"]
    var resetButtons = [Button]()
    for resetImage in resetButtonImages {
      let resetButton = Button(imageNamed: resetImage, imageColor: AppAppearance.dangerButtonColor, size: buttonSize)
      resetButton.name = resetImage + "Button"
      resetButton.requiresConfirmation(stackedLabels(["Confirm", "Reset"],
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
    let redoHstack = horizontalStack(nodes: replayButtons + resetButtons, minSpacing: buttonSpacing)
    buttons.append(contentsOf: resetButtons)
    // Sound controls
    var soundButtons = [Button]()
    volumeButton = Button(imagesNamed: ["soundnone", "soundsmall", "soundmed", "soundbig"],
                          imageColor: AppAppearance.buttonColor, size: buttonSize)
    volumeButton.selectedValue = UserData.audioLevel.value
    volumeButton.makeSound = false
    volumeButton.action = { [unowned self] in self.setVolume() }
    soundButtons.append(volumeButton)
    heartbeatButton = Button(imagesNamed: ["heartbeatoff", "heartbeaton"],
                             imageColor: AppAppearance.buttonColor, size: buttonSize)
    heartbeatButton.selectedValue = UserData.heartbeatMuted.value ? 0 : 1
    heartbeatButton.makeSound = false
    heartbeatButton.action = { [unowned self] in self.toggleHeartbeat() }
    if volumeButton.selectedValue == 0 {
      heartbeatButton.disable()
    }
    soundButtons.append(heartbeatButton)
    ufoFadeButton = Button(imagesNamed: ["ufosoundcontinuous", "ufosoundchopped"],
                             imageColor: AppAppearance.buttonColor, size: buttonSize)
    ufoFadeButton.selectedValue = UserData.fadeUFOAudio.value ? 1 : 0
    ufoFadeButton.makeSound = false
    ufoFadeButton.action = { [unowned self] in self.toggleUFOFade() }
    if volumeButton.selectedValue == 0 {
      ufoFadeButton.disable()
    }
    soundButtons.append(ufoFadeButton)
    let soundHstack = horizontalStack(nodes: soundButtons, minSpacing: buttonSpacing)
    buttons.append(contentsOf: soundButtons)
    // Other options
    var optionButtons = [Button]()
    let maxStart = UserData.highestWaveCleared.value + 1
    let startLabels = (0 ... maxStart).map { start in
      if start == 0 {
        let label = SKLabelNode(fontNamed: AppAppearance.font)
        label.fontSize = 30
        label.fontColor = AppAppearance.highlightTextColor
        label.text = "FRENZY!"
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zRotation = .pi / 8
        return label as SKNode
      } else {
        return stackedLabels(["Start", "Wave \(start)"], fontColor: AppAppearance.buttonColor)
      }
    }
    startingWaveButton = Button(forNodes: startLabels, size: buttonSize)
    if maxStart == 1 {
      // No choice but wave 1
      startingWaveButton.selectedValue = 1
      startingWaveButton.disable()
    } else if UserData.startingWave.value == 0 {
      // They want to start at the highest allowed wave
      startingWaveButton.selectedValue = 0
    } else {
      // They've chosen a particular starting value
      startingWaveButton.selectedValue = min(maxStart, UserData.startingWave.value)
    }
    startingWaveButton.action = { [unowned self] in self.selectStartingWave() }
    optionButtons.append(startingWaveButton)
    let hapticsIcon: String
    if Globals.controller.connected {
      // If there's a controller, show a preference for thrust using the stick or
      // dpad vs thrust on A/B buttons
      joystickThrustButton = Button(imagesNamed: ["thruststick", "thrustbuttons"],
                                    imageColor: .white, size: buttonSize)
      joystickThrustButton.selectedValue = UserData.buttonThrust.value ? 1 : 0
      joystickThrustButton.action = { [unowned self] in self.toggleJoystickThrust() }
      optionButtons.append(joystickThrustButton)
      // Use a controller icon on the haptics button
      hapticsIcon = "controller"
    } else {
      // Show preference for touches displayed or not
      showTouchesButton = Button(imagesNamed: ["showtouchesoff", "showtoucheson"],
                                 imageColor: AppAppearance.buttonColor, size: buttonSize)
      showTouchesButton.selectedValue = UserData.showTouches.value ? 1 : 0
      showTouchesButton.action = { [unowned self] in self.toggleShowTouches() }
      optionButtons.append(showTouchesButton)
      // Use a device icon on the haptics button
      hapticsIcon = "device"
    }
    // Haptics button
    hapticsButton = Button(imagesNamed: ["\(hapticsIcon)hapticsoff", "\(hapticsIcon)hapticson"],
                           imageColor: AppAppearance.buttonColor, size: buttonSize)
    hapticsButton.selectedValue = UserData.useHaptics.value ? 1 : 0
    hapticsButton.action = { [unowned self] in self.toggleHaptics() }
    if !Globals.haptics.enabled {
      hapticsButton.selectedValue = 0
      hapticsButton.disable()
    }
    optionButtons.append(hapticsButton)
    // Get the unlocked ship colors
    shipStyles = unlockedShipColors().map { "shipmodern_\($0)" }
    // This retro/modern selection is only available if the player has the
    // blastFromThePast achievement.
    if achievementIsCompleted(.blastFromThePast) {
      shipStyles.append("shipretro")
    }
    shipStyleButton = Button(imagesNamed: shipStyles, imageColor: .white, size: buttonSize)
    if let retroIndex = shipStyles.firstIndex(of: "shipretro"), UserData.retroMode.value {
      // The user has the retro mode preference set; show that selection
      shipStyleButton.selectedValue = retroIndex
    } else if let modernIndex = shipStyles.firstIndex(of: "shipmodern_\(UserData.shipColor.value)") {
      // The user has picked some unlocked color
      shipStyleButton.selectedValue = modernIndex
    } else {
      shipStyleButton.selectedValue = 0
    }
    shipStyleButton.action = { [unowned self] in self.selectShipStyle() }
    optionButtons.append(shipStyleButton)
    if shipStyles.count == 1 {
      shipStyleButton.disable()
    }
    let optionsHstack = horizontalStack(nodes: optionButtons, minSpacing: buttonSpacing)
    buttons.append(contentsOf: optionButtons)
    let vstack = verticalStack(nodes: [redoHstack, soundHstack, optionsHstack], minSpacing: buttonSpacing)
    let wantedMidY = 0.5 * (title.frame.minY + bottomHstack.calculateAccumulatedFrame().maxY)
    // Center verticalStack vertically at wantedMidY
    vstack.position = .zero
    let vstackY = round(wantedMidY - vstack.calculateAccumulatedFrame().midY)
    vstack.position = CGPoint(x: fullFrame.midX, y: vstackY)
    settings.addChild(vstack)
    settings.shouldRasterize = true
  }

  /// Create the settings scene
  /// - Parameter size: The size of the scene
  override init(size: CGSize) {
    os_log("SettingsScene init", log: .app, type: .debug)
    super.init(size: size)
    name = "settingsScene"
    initGameArea(avoidSafeArea: false)
    initSettings()
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  deinit {
    os_log("SettingsScene deinit %{public}s", log: .app, type: .debug, "\(self.hash)")
  }

  // MARK: - Button actions

  /// Replay the intro scene
  ///
  /// If they've reached the top level but have not seen the conclusion screen, then
  /// this instead triggers the promoted achievement and shows the conclusion.  Once
  /// the promoted achievement has been done, then there will be a separate replay
  /// conclusion button.
  func replayIntro() {
    guard prepareForSwitch() else { return }
    var showConclusion = false
    if levelIsReached(achievement: .rockRat, level: 3) && !achievementIsCompleted(.promoted) {
      // Game Center has to be enabled to get here, since levelIsReached will have
      // returned false if it was not enabled.
      reportAchievement(achievement: .promoted)
      showConclusion = true
    }
    switchWhenQuiescent { IntroScene(size: self.fullFrame.size, conclusion: showConclusion) }
  }

  /// Replay the conclusion scene
  func replayConclusion() {
    guard prepareForSwitch() else { return }
    switchWhenQuiescent { IntroScene(size: self.fullFrame.size, conclusion: true) }
  }

  /// Replay the tutorial
  func replayTutorial() {
    guard prepareForSwitch() else { return }
    switchWhenQuiescent { TutorialScene(size: self.fullFrame.size) }
  }

  /// Go back to the main menu
  func mainMenu() {
    guard prepareForSwitch() else { return }
    switchWhenQuiescent { Globals.menuScene }
  }

  /// Start a new game
  func startGame() {
    guard prepareForSwitch() else { return }
    switchWhenQuiescent { GameScene(size: self.fullFrame.size) }
  }

  /// Display the credits scene
  func showCredits() {
    guard prepareForSwitch() else { return }
    switchWhenQuiescent { CreditsScene(size: self.fullFrame.size) }
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
      ufoFadeButton.disable()
    } else {
      heartbeatButton.enable()
      ufoFadeButton.enable()
    }
  }

  /// Temporarily disable sound control buttons while a sound effect demo is running
  func beginSoundEffectDemo() {
    // Don't change the alpha since this is only a temporary thing
    volumeButton.disable(1)
    heartbeatButton.disable(1)
    ufoFadeButton.disable(1)
  }

  /// Re-enable sound control buttons
  func endSoundEffectDemo() {
    volumeButton.enable()
    heartbeatButton.enable()
    ufoFadeButton.enable()
  }

  /// Toggle heartbeat on/off
  func toggleHeartbeat() {
    UserData.heartbeatMuted.value = (heartbeatButton.selectedValue == 0)
    if !UserData.heartbeatMuted.value {
      // Silently disable volume and heartbeat buttons until the sound effect demo is done
      beginSoundEffectDemo()
      audio.soundEffect(.heartbeatHigh)
      wait(for: 0.25) {
        self.audio.soundEffect(.heartbeatLow)
        self.endSoundEffectDemo()
      }
    } else {
      heartbeatButton.clickSound()
    }
  }

  /// Toggle UFO sound continuous/fading
  func toggleUFOFade() {
    UserData.fadeUFOAudio.value = (ufoFadeButton.selectedValue == 1)
    // Silently disable volume and UFO sound buttons until the sound effect demo is done
    beginSoundEffectDemo()
    let node = SKNode()
    let ufoSound = audio.continuousAudio(.ufoEnginesBig, at: node)
    ufoSound.playerNode.volume = UFO.ufoVolume
    ufoSound.playerNode.play()
    addChild(node)
    let exampleTime = 1.5
    if UserData.fadeUFOAudio.value {
      let fadeTime = 0.67 * exampleTime
      run(.customAction(withDuration: fadeTime) { _, time in
        ufoSound.playerNode.volume = UFO.ufoVolume * max(Float(1 - Double(time) / fadeTime), 0)
      })
    }
    wait(for: exampleTime) {
      ufoSound.playerNode.volume = 0
      ufoSound.playerNode.stop()
      node.removeFromParent()
      self.endSoundEffectDemo()
    }
  }

  /// Toggle showing touches on/off
  func toggleShowTouches() {
    UserData.showTouches.value = (showTouchesButton.selectedValue == 1)
  }

  /// Toggle showing touches on/off
  func toggleJoystickThrust() {
    UserData.buttonThrust.value = (joystickThrustButton.selectedValue == 1)
  }

  /// Toggle haptics on/off
  func toggleHaptics() {
    UserData.useHaptics.value = (hapticsButton.selectedValue == 1)
    if UserData.useHaptics.value {
      Globals.haptics.explosion()
    }
  }

  /// Choose the ship style
  func selectShipStyle() {
    let selected = shipStyles[shipStyleButton.selectedValue]
    if selected == "shipretro" {
      UserData.retroMode.value = true
    } else {
      UserData.retroMode.value = false
      let parts = selected.split(separator: "_")
      assert(parts.count == 2)
      UserData.shipColor.value = String(parts[1])
    }
    Globals.controller.setColor("ship")
  }

  /// Choose the starting wave
  func selectStartingWave() {
    UserData.startingWave.value = startingWaveButton.selectedValue
  }

  /// Reset all local high scores
  func resetScores() {
    UserData.highScores.reset()
    os_log("Scores reset", log: .app, type: .debug)
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
      UserData.ufosDestroyedCounter.reset()
      UserData.asteroidsDestroyed.value = 0
      UserData.asteroidsDestroyedCounter.reset()
      // Perhaps no real need to reset the maximum wave cleared since it does not
      // affect any achievements directly, but whatevs.  Be sure to disable the wave
      // select button and set it to start on wave 1 to be consistent.
      UserData.highestWaveCleared.value = 0
      UserData.highestWaveClearedCounter.reset()
      startingWaveButton.selectedValue = 1
      startingWaveButton.disable()
      // Setting these is perhaps pointless since if the user presses the ship style
      // button these will just get changed again.  But when actually starting a
      // game, the values will be ignored unless the appropriate achievements have
      // been completed.
      UserData.retroMode.value = false
      UserData.shipColor.value = "blue"
      os_log("Achievements reset", log: .app, type: .debug)
    }
  }

  /// The Game Center status has changed, so update `resetAchievementsButton`'s
  /// enabled/disabled state to match
  /// - Parameter notification: A notification indicating what happened
  @objc func gcStateChanged(_ notification: Notification) {
    os_log("Settings scene got notification of Game Center state change", log: .app, type: .debug)
    if notification.object as? Bool ?? false {
      resetAchievementsButton.enable()
    } else {
      resetAchievementsButton.disable()
    }
  }

  // MARK: - Skywriting (spacewriting?)

  /// Remove the currently displayed fortune, if any
  func removeFortune() {
    os_signpost(.event, log: .poi, name: "Skywriting finished", signpostID: signpostID)
    fortuneNode?.removeAllActions()
    fortuneNode?.removeFromParent()
    fortuneNode = nil
  }

  /// Skywrite a random fortune
  ///
  /// This method reschedules itself indirectly through `nextFortune`
  func skywriteFortune() {
    // Try to pick something new.
    os_signpost(.event, log: .poi, name: "Composing skywriting", signpostID: signpostID)
    var candidateFortune = fortunes.randomElement()
    var tries = 0
    while let fortune = candidateFortune, recentFortunes.contains(fortune), tries < 10 {
      candidateFortune = fortunes.randomElement()
      tries += 1
    }
    let fortune = candidateFortune ?? "This space unintentionally left blank."
    recentFortunes.insert(fortune)
    let (fortuneNode, delay) = skywriting(message: fortune, frame: gameFrame)
    self.fortuneNode = fortuneNode
    fortuneNode.run(.wait(for: delay, then: nextFortune), withKey: "skywriting")
    os_signpost(.event, log: .poi, name: "Running skywriting", signpostID: signpostID)
    playfield.addWithScaling(fortuneNode)
  }

  /// Wait a bit, then skywrite a random fortune
  ///
  /// This method reschedules itself indirectly through `skywriteFortune`
  func nextFortune() {
    removeFortune()
    run(.wait(for: .random(in: 2 ... 3), then: skywriteFortune), withKey: "skywriting")
  }

  /// Stop skywriting and get ready to switch scenes
  /// - Returns: `true` means go ahead, `false` means a scene switch is already in progress
  func prepareForSwitch() -> Bool {
    guard self.beginSceneSwitch() else { return false }
    removeAction(forKey: "skywriting")
    if let fortuneNode {
      fortuneNode.removeAction(forKey: "skywriting")
      fortuneNode.run(.sequence([.fadeOut(withDuration: 0.5), .wait(forDuration: 0.1), .removeFromParent()]))
      self.fortuneNode = nil
    }
    return true
  }

  /// Start skywriting
  /// - Parameter view: The view that will display the scene
  override func didMove(to view: SKView) {
    super.didMove(to: view)
    bindControllerMenuButtons()
    if !fortunes.isEmpty {
      nextFortune()
    }
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    endOfUpdate()
  }
}

// MARK: - Fortunes

let fortunes: [String] = {
  var result = [String]()
  if let url = Bundle.main.url(forResource: "fortunes", withExtension: "txt") {
    do {
      let contents = try String(contentsOf: url)
      result = contents.split(separator: "\n").compactMap {
        let fortune = String($0)
        if fortune.allSatisfy({ char in skywritingFont[char] != nil }) {
          return fortune
        } else {
          os_log("Missing character in fortune %{public}s", log: .app, type: .error, String(fortune))
          return nil
        }
      }
    } catch {
      os_log("Unable to load fortunes.txt", log: .app, type: .error)
    }
  }
  return result
}()
