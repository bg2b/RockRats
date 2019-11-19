//
//  SettingsScene.swift
//  Asteroids
//
//  Created by David Long on 11/15/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class SettingsScene: BasicScene {
  var muteButton: Button!

  func initSettings() {
    let settings = SKNode()
    settings.name = "settings"
    settings.setZ(.info)
    addChild(settings)
    let title = SKLabelNode(fontNamed: AppColors.font)
    title.fontSize = 100
    title.fontColor = AppColors.highlightTextColor
    title.text = "Settings"
    title.verticalAlignmentMode = .center
    title.position = CGPoint(x: fullFrame.midX, y: fullFrame.maxY - title.fontSize)
    settings.addChild(title)
    let buttonSize = CGSize(width: 150, height: 100)
    let buttonSpacing = CGFloat(20)
    let buttonY = fullFrame.minY + buttonSize.height + buttonSpacing
    let numButtons = 3
    let widthForAllButtons = CGFloat(numButtons) * buttonSize.width + CGFloat(numButtons - 1) * buttonSpacing
    var nextButtonX = fullFrame.midX - 0.5 * widthForAllButtons + 0.5 * buttonSize.width
    let menuButton = Button(imageNamed: "homebutton", imageColor: AppColors.blue, size: buttonSize)
    menuButton.action = { [unowned self] in self.mainMenu() }
    menuButton.position = CGPoint(x: nextButtonX, y: buttonY)
    nextButtonX += buttonSize.width + buttonSpacing
    settings.addChild(menuButton)
    muteButton = Button(imagesNamed: ["soundon", "soundoff"], imageColor: AppColors.blue, size: buttonSize)
    muteButton.selectedValue = (userDefaults.audioIsMuted.value ? 1 : 0)
    muteButton.action = { [unowned self] in self.toggleSound() }
    muteButton.position = CGPoint(x: nextButtonX, y: buttonY)
    nextButtonX += buttonSize.width + buttonSpacing
    settings.addChild(muteButton)
    let creditsButton = Button(imageNamed: "infobutton", imageColor: AppColors.blue, size: buttonSize)
    creditsButton.action = { [unowned self] in self.showCredits() }
    creditsButton.position = CGPoint(x: nextButtonX, y: buttonY)
    nextButtonX += buttonSize.width + buttonSpacing
    settings.addChild(creditsButton)
    let vstack = SKNode()
    vstack.name = "vstack"
    let buttonFontSize = CGFloat(50)
    let textButtonSize = CGSize(width: 650, height: buttonFontSize)
    var nextButtonY = CGFloat(0)
    let introButton = Button(forText: "Introduction", fontSize: buttonFontSize, size: textButtonSize)
    introButton.name = "introButton"
    introButton.action = { [unowned self] in self.replayIntro() }
    introButton.position = CGPoint(x: 0, y: nextButtonY)
    nextButtonY -= introButton.calculateAccumulatedFrame().height + 0.5 * buttonSpacing
    vstack.addChild(introButton)
    let tutorialButton = Button(forText: "Tutorial", fontSize: buttonFontSize, size: textButtonSize)
    tutorialButton.name = "tutorialButton"
    tutorialButton.action = { [unowned self] in self.replayTutorial() }
    tutorialButton.position = CGPoint(x: 0, y: nextButtonY)
    nextButtonY -= tutorialButton.calculateAccumulatedFrame().height + 0.5 * buttonSpacing
    vstack.addChild(tutorialButton)
    if achievementIsCompleted(achievement: .promoted) {
      let conclusionButton = Button(forText: "Conclusion", fontSize: buttonFontSize, size: textButtonSize)
      conclusionButton.name = "introButton"
      conclusionButton.action = { [unowned self] in self.replayConclusion() }
      conclusionButton.position = CGPoint(x: 0, y: nextButtonY)
      nextButtonY -= conclusionButton.calculateAccumulatedFrame().height + 0.5 * buttonSpacing
      vstack.addChild(conclusionButton)
    }
    // Extra space before dangerous items
    nextButtonY -= buttonSpacing
    let resetScoresButton = Button(forText: "Reset Scores", confirmText: "Confirm Reset", fontSize: buttonFontSize, size: textButtonSize)
    resetScoresButton.name = "resetScoresButton"
    resetScoresButton.action = { [unowned self] in self.resetScores() }
    resetScoresButton.position = CGPoint(x: 0, y: nextButtonY)
    nextButtonY -= resetScoresButton.calculateAccumulatedFrame().height + 0.5 * buttonSpacing
    vstack.addChild(resetScoresButton)
    let resetAchievementsButton = Button(forText: "Reset Achievements", confirmText: "Confirm Reset", fontSize: buttonFontSize, size: textButtonSize)
    resetAchievementsButton.name = "resetAchievementsButton"
    resetAchievementsButton.action = { [unowned self] in self.resetAchievements() }
    resetAchievementsButton.position = CGPoint(x: 0, y: nextButtonY)
    if !Globals.gcInterface.enabled {
      resetAchievementsButton.disable()
    }
    vstack.addChild(resetAchievementsButton)
    let wantedMidY = 0.5 * (title.frame.minY + menuButton.calculateAccumulatedFrame().maxY)
    // Center verticalStack vertically at wantedMidY
    vstack.position = .zero
    let vstackY = round(wantedMidY - vstack.calculateAccumulatedFrame().midY)
    vstack.position = CGPoint(x: fullFrame.midX, y: vstackY)
    settings.addChild(vstack)
  }

  func replayIntro() {
    var showConclusion = false
    // If they've reached the top level but have not seen the conclusion screen, then
    // clicking the replay intro button triggers the promoted achievement and shows
    // the conclusion instead.  Once the promoted achievement has been done, then
    // there will be a separate replay conclusion button.
    if let gc = Globals.gcInterface, gc.enabled, levelIsReached(achievement: .rockRat, level: 3) {
      if !achievementIsCompleted(achievement: .promoted) {
        reportAchievement(achievement: .promoted)
        showConclusion = true
      }
    }
    switchToScene { IntroScene(size: self.fullFrame.size, conclusion: showConclusion) }
  }

  func replayConclusion() {
    switchToScene { IntroScene(size: self.fullFrame.size, conclusion: true) }
  }

  func replayTutorial() {
    switchToScene { TutorialScene(size: self.fullFrame.size) }
  }

  func mainMenu() {
    showWhenQuiescent(Globals.menuScene)
  }

  func toggleSound() {
    if muteButton.selectedValue == 1 {
      // Muted
      audio.muted = true
      userDefaults.audioIsMuted.value = true
    } else {
      audio.muted = false
      userDefaults.audioIsMuted.value = false
    }
  }

  func showCredits() {
    switchToScene { CreditsScene(size: self.fullFrame.size) }
  }

  func resetScores() {
    userDefaults.highScores.reset()
    logging("Scores reset")
  }

  func resetAchievements() {
    if let gc = Globals.gcInterface, gc.enabled {
      gc.resetAchievements()
      userDefaults.ufosDestroyed.value = 0
      userDefaults.asteroidsDestroyed.value = 0
      // Assigning a negative value means to force the iCloud-synchronized per-player
      // values to zero.
      userDefaults.ufosDestroyedCounter.value = -1
      userDefaults.asteroidsDestroyedCounter.value = -1
      logging("Achievements reset")
    }
  }

  override func didMove(to view: SKView) {
    super.didMove(to: view)
    logging("\(name!) finished didMove to view")
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
  }

  override init(size: CGSize) {
    super.init(size: size)
    name = "settingsScene"
    initGameArea(avoidSafeArea: false)
    initSettings()
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}
