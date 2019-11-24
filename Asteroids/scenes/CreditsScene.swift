//
//  CreditsScene.swift
//  Asteroids
//
//  Created by David Long on 11/19/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// Game credits and acknowledgements
class CreditsScene: BasicScene {
  /// Build the stuff in the scene
  func initCredits() {
    let attributes = AttrStyles(fontName: AppAppearance.font, fontSize: 40)
    let credits = SKNode()
    credits.name = "credits"
    credits.setZ(.info)
    addChild(credits)
    // Title
    let title = SKLabelNode(fontNamed: AppAppearance.font)
    title.fontSize = 100
    title.fontColor = AppAppearance.highlightTextColor
    title.text = "Credits"
    title.verticalAlignmentMode = .center
    title.position = CGPoint(x: fullFrame.midX, y: fullFrame.maxY - title.fontSize)
    credits.addChild(title)
    // Buttons at the bottom
    let buttonSize = CGSize(width: 150, height: 100)
    let buttonSpacing = CGFloat(20)
    let buttonY = fullFrame.minY + buttonSize.height + buttonSpacing
    // New game
    let playButton = Button(imageNamed: "playbutton", imageColor: AppAppearance.playButtonColor, size: buttonSize)
    playButton.position = CGPoint(x: fullFrame.midX, y: buttonY)
    playButton.action = { [unowned self] in self.startGame() }
    credits.addChild(playButton)
    // Main menu
    let menuButton = Button(imageNamed: "homebutton", imageColor: AppAppearance.buttonColor, size: buttonSize)
    menuButton.position = CGPoint(x: playButton.position.x - buttonSize.width - buttonSpacing, y: playButton.position.y)
    menuButton.action = { [unowned self] in self.mainMenu() }
    credits.addChild(menuButton)
    // Settings screen
    let settingsButton = Button(imageNamed: "settingsbutton", imageColor: AppAppearance.buttonColor, size: buttonSize)
    settingsButton.position = CGPoint(x: playButton.position.x + buttonSize.width + buttonSpacing, y: playButton.position.y)
    settingsButton.action = { [unowned self] in self.showSettings() }
    credits.addChild(settingsButton)
    // The actual credits in the center
    let creditsLabels = SKNode()
    creditsLabels.name = "creditsLabels"
    // There are several sections, and I want more control over the spacing between
    // sections than is obtained by making one big label with some line breaks, so
    // I'll make one label per section instead.
    let creditsText = [
    """
    Designed & Programmed by
    @Daniel Long@ and @David Long@
    """,
    """
    Game art & sounds by @Kenney@
    @www.kenney.nl@
    """,
    """
    Thanks to @Paul Hudson@ for iOS development tutorials
    @www.hackingwithswift.com@
    """
    ]
    var nextLabelY = CGFloat(0)
    for text in creditsText {
      let creditsLabel = SKLabelNode(attributedText: makeAttributed(text: text, until: text.endIndex, attributes: attributes))
      creditsLabel.name = "creditsLabel"
      creditsLabel.numberOfLines = 0
      creditsLabel.lineBreakMode = .byWordWrapping
      creditsLabel.preferredMaxLayoutWidth = 900
      creditsLabel.horizontalAlignmentMode = .left
      creditsLabel.verticalAlignmentMode = .top
      creditsLabel.position = CGPoint(x: 0, y: nextLabelY)
      nextLabelY -= creditsLabel.frame.height + 30
      creditsLabels.addChild(creditsLabel)
    }
    let wantedMidY = 0.5 * (title.frame.minY + playButton.calculateAccumulatedFrame().maxY)
    // Center credits vertically at wantedMidY
    creditsLabels.position = .zero
    let creditsFrame = creditsLabels.calculateAccumulatedFrame()
    let creditsX = round(fullFrame.midX - creditsFrame.midX)
    let creditsY = round(wantedMidY - creditsFrame.midY)
    creditsLabels.position = CGPoint(x: creditsX, y: creditsY)
    credits.addChild(creditsLabels)
  }

  /// Start a new game
  func startGame() {
    switchToScene { return GameScene(size: self.fullFrame.size) }
  }

  /// Switch back to the main menu
  func mainMenu() {
    showWhenQuiescent(Globals.menuScene)
  }

  /// Show the game settings
  func showSettings() {
    switchToScene { SettingsScene(size: self.fullFrame.size) }
  }

  override func didMove(to view: SKView) {
    super.didMove(to: view)
    logging("\(name!) finished didMove to view")
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
  }

  /// Make a new scene to display the credits
  /// - Parameter size: The size of the scene
  override init(size: CGSize) {
    super.init(size: size)
    name = "creditsScene"
    initGameArea(avoidSafeArea: false)
    initCredits()
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}
