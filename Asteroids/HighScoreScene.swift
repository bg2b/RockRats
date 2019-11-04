//
//  HighScoreScene.swift
//  Asteroids
//
//  Created by David Long on 10/31/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import GameKit

class HighScoreScene: BasicScene, GKGameCenterControllerDelegate {
  var scores: SKNode!
  var gameStarting = false
  var newGame: GameScene? = nil

  func rightAlignPoints(_ scoreStr: String) -> String {
    var result = scoreStr
    if result.count < 5 {
      result = "%" + String(repeating: "0", count: 5 - result.count) + "%" + result
    }
    return result
  }

  func highScoreLine(_ scoreStr: String, playerName: String, highlightedPlayerName: String) -> String {
    var result = ""
    // Highlight line if it's for the player who just played a game.
    if playerName == highlightedPlayerName {
      result += "@"
    }
    result += rightAlignPoints(scoreStr)
    result += "  "
    result += playerName
    if playerName == highlightedPlayerName {
      result += "@"
    }
    result += "\n"
    return result
  }

  func highScoreLine(_ highScore: GameScore, highlightedPlayerName: String) -> String {
    return highScoreLine("\(highScore.points)", playerName: highScore.playerName, highlightedPlayerName: highlightedPlayerName)
  }

  func highlightedPlayerName(_ score: GameScore?) -> String {
    if let score = score {
      return score.playerName
    } else {
      return userDefaults.currentPlayerName.value
    }
  }

  func initScores(score: GameScore?, highScores: [GameScore]) {
    let highlighted = highlightedPlayerName(score)
    scores = SKNode()
    scores.name = "scores"
    scores.zPosition = LevelZs.info.rawValue
    addChild(scores)
    let title = SKLabelNode(fontNamed: AppColors.font)
    title.fontSize = 75
    title.fontColor = AppColors.highlightTextColor
    title.text = "High Scores"
    title.verticalAlignmentMode = .center
    title.position = CGPoint(x: fullFrame.midX, y: fullFrame.maxY - title.fontSize)
    scores.addChild(title)
    let highScoresLabel = SKLabelNode(fontNamed: AppColors.font)
    highScoresLabel.fontSize = 33
    highScoresLabel.numberOfLines = 0
    highScoresLabel.fontColor = AppColors.textColor
    highScoresLabel.verticalAlignmentMode = .center
    highScoresLabel.position = CGPoint(x: fullFrame.midX, y: fullFrame.midY)
    var highScoresText = ""
    for highScore in highScores {
      highScoresText += highScoreLine(highScore, highlightedPlayerName: highlighted)
    }
    if let score = score, !highScores.contains(score) {
      highScoresText += highScoreLine("", playerName: "...", highlightedPlayerName: "")
      highScoresText += highScoreLine(score, highlightedPlayerName: highlighted)
    }
    highScoresLabel.attributedText = makeAttributed(text: highScoresText, until: highScoresText.endIndex,
                                                    attributes: AttrStyles(fontName: AppColors.font, fontSize: highScoresLabel.fontSize))
    scores.addChild(highScoresLabel)

    let buttonSize = CGSize(width: 150, height: 100)
    let buttonSpacing = CGFloat(20)
    let buttonY = fullFrame.minY + buttonSize.height + buttonSpacing
    let playButton = Button(imageNamed: "playbutton", imageColor: AppColors.green, size: buttonSize)
    playButton.position = CGPoint(x: fullFrame.midX, y: buttonY)
    playButton.action = { [unowned self] in self.startGame() }
    scores.addChild(playButton)
    let menuButton = Button(imageNamed: "homebutton", imageColor: AppColors.blue, size: buttonSize)
    menuButton.position = CGPoint(x: playButton.position.x - buttonSize.width - buttonSpacing, y: playButton.position.y)
    menuButton.action = { [unowned self] in self.mainMenu() }
    scores.addChild(menuButton)
    let gcButton = Button(imageNamed: "gamecenterbutton", imageColor: .white, size: buttonSize)
    gcButton.position = CGPoint(x: playButton.position.x + buttonSize.width + buttonSpacing, y: playButton.position.y)
    gcButton.action = { [unowned self] in self.showGameCenter() }
    scores.addChild(gcButton)

//    let buttonHeight = CGFloat(50)
//    let buttons = SKNode()
//    buttons.name = "highScoreButtons"
//    buttons.position = CGPoint(x: fullFrame.midX, y: fullFrame.minY + 1.5 * buttonHeight)
//    scores.addChild(buttons)
//    var nextButtonY = 0 * buttonHeight
//    let menuButton = Button(forText: "Main menu", size: CGSize(width: 400, height: buttonHeight), fontName: AppColors.font)
//    menuButton.position = CGPoint(x: 0, y: nextButtonY)
//    menuButton.action = { [unowned self] in self.mainMenu() }
//    buttons.addChild(menuButton)
//    nextButtonY += 1.5 * buttonHeight
//    if Globals.gcInterface.enabled {
//      let gcButton = Button(forText: "Game Center", size: CGSize(width: 400, height: buttonHeight), fontName: AppColors.font)
//      gcButton.position = CGPoint(x: 0, y: nextButtonY)
//      gcButton.action = { [unowned self] in self.showGameCenter() }
//      buttons.addChild(gcButton)
//      nextButtonY += 1.5 * buttonHeight
//    }
//    let playText = (score == nil ? "Play" : "Play again")
//    let playButton = Button(forText: playText, size: CGSize(width: 400, height: buttonHeight), fontName: AppColors.font)
//    playButton.position = CGPoint(x: 0, y: nextButtonY)
//    playButton.action = { [unowned self] in self.startGame() }
//    buttons.addChild(playButton)
//    nextButtonY += 1.5 * buttonHeight
  }

  func showWhenQuiescent(_ newScene: SKScene) {
    if playfield.isQuiescent(transient: setOf([.ufo, .ufoShot, .fragment])) {
      wait(for: 0.25) {
        self.switchScene(to: newScene)
      }
    } else {
      wait(for: 0.25) { self.showWhenQuiescent(newScene) }
    }
  }

  func startWhenQuiescent() {
    if let newGame = newGame {
      self.newGame = nil
      showWhenQuiescent(newGame)
    } else {
      wait(for: 0.25) { self.startWhenQuiescent() }
    }
  }

  func startGame() {
    gameStarting = true
    // The game creation is a little time-consuming and would cause the menu
    // animation to lag, so run it in the background while UFOs are warping out and
    // we're waiting for the playfield to become quiescent.
    run(SKAction.run({ self.newGame = GameScene(size: self.fullFrame.size) },
                     queue: DispatchQueue.global(qos: .utility)))
    startWhenQuiescent()
  }

  func mainMenu() {
    showWhenQuiescent(Globals.menuScene)
  }

  func showGameCenter() {
    guard let rootVC = view?.window?.rootViewController, Globals.gcInterface.enabled else {
      logging("Can't show Game Center")
      return
    }
    let gcvc = GKGameCenterViewController()
    gcvc.gameCenterDelegate = self
    gcvc.viewState = .achievements
    gcvc.leaderboardTimeScope = .week
    isPaused = true
    rootVC.present(gcvc, animated: true)
  }

  func gameCenterViewControllerDidFinish(_ gcvc: GKGameCenterViewController) {
    gcvc.dismiss(animated: true) { self.isPaused = false }
  }

  override func didMove(to view: SKView) {
    super.didMove(to: view)
//    Globals.gameConfig = loadGameConfig(forMode: "menu")
//    Globals.gameConfig.currentWaveNumber = 1
//    highScore.text = "High Score: \(userDefaults.highScore.value)"
//    wait(for: 1) { self.spawnAsteroids() }
//    gameStarting = false
//    wait(for: 10) { self.spawnUFOs() }
    logging("\(name!) finished didMove to view")
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
//    ufos.forEach { ufo in
//      ufo.fly(player: nil, playfield: playfield) { (angle, position, speed) in
//        if !self.gameStarting {
//          self.fireUFOLaser(angle: angle, position: position, speed: speed)
//          self.shotsFired[ufo] = self.shotsFired[ufo]! + 1
//          if self.shotsFired[ufo]! > 3 && Int.random(in: 0 ..< 10) == 0 {
//            self.warpOutUFO(ufo)
//          }
//        }
//      }
//    }
//    playfield.wrapCoordinates()
  }

  override init(size: CGSize) {
    super.init(size: size)
    name = "highScoreScene"
    initGameArea(avoidSafeArea: false)
    physicsWorld.contactDelegate = self
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by HighScoreScene")
  }

  convenience init(size: CGSize, score: GameScore?) {
    self.init(size: size)
    let highScores = userDefaults.highScores.value
    initScores(score: score, highScores: highScores)
  }
}
