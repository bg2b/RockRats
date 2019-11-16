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
    creditsButton.action = { print("credits") }
    creditsButton.position = CGPoint(x: nextButtonX, y: buttonY)
    nextButtonX += buttonSize.width + buttonSpacing
    settings.addChild(creditsButton)
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
