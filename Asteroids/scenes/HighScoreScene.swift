//
//  HighScoreScene.swift
//  Asteroids
//
//  Created by David Long on 10/31/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import GameKit

func abbreviatedName(_ playerName: String) -> String {
  let maxLength = 20
  if playerName.count > maxLength {
    // Cut off names that are too long
    return playerName.prefix(maxLength - 3) + "..."
  } else {
    return playerName
  }
}

class HighScoreScene: BasicScene, GKGameCenterControllerDelegate {
  var scores: SKNode!
  var showingGCVC = false
  var newGame: GameScene? = nil

  func highScoreLineLabels(_ highScore: GameScore, highlighted: GameScore) -> (SKLabelNode, SKLabelNode) {
    let playerScore = SKLabelNode()
    playerScore.name = "playerScore"
    var playerScoreText = "\(highScore.points)"
    let playerName = SKLabelNode()
    playerName.name = "playerName"
    var playerNameText = abbreviatedName((highScore.playerName ?? "Space Ghost").uppercased())
    if highScore.playerID == highlighted.playerID {
      // Boldface name of the current player
      playerNameText = "@" + playerNameText + "@"
      if highScore == highlighted {
        // Also boldface the points if it matches the just-played game
        playerScoreText = "@" + playerScoreText + "@"
      }
    }
    let attributes = AttrStyles(fontName: AppColors.font, fontSize: 35)
    playerName.attributedText = makeAttributed(text: playerNameText, until: playerNameText.endIndex, attributes: attributes)
    playerName.horizontalAlignmentMode = .left
    playerName.verticalAlignmentMode = .center
    playerScore.attributedText = makeAttributed(text: playerScoreText, until: playerScoreText.endIndex, attributes: attributes)
    playerScore.horizontalAlignmentMode = .right
    playerScore.verticalAlignmentMode = .center
    return (playerName, playerScore)
  }

  func highScoreLines(_ highScores: [GameScore], highlighted: GameScore) -> SKNode {
    let scores = SKNode()
    scores.name = "highScoreLines"
    var labels = highScores.map { highScoreLineLabels($0, highlighted: highlighted) }
    let numHighScores = labels.count
    if highScores.firstIndex(of: highlighted) == nil && highlighted.points > 0 {
      // Add a final line for the just-played game if it's not a high score
      labels.append(highScoreLineLabels(highlighted, highlighted: highlighted))
    }
    if highScores.isEmpty {
      let ghostly = GameScore()
      labels.append(highScoreLineLabels(ghostly, highlighted: ghostly))
    }
    let maxNameWidth = labels.reduce(CGFloat(0)) { max($0, $1.0.frame.width) }
    let maxScoreWidth = labels.reduce(CGFloat(0)) { max($0, $1.1.frame.width) }
    let paddingX = CGFloat(10)
    let paddingY = CGFloat(3)
    let width = max(paddingX + maxNameWidth + 10 * paddingX + maxScoreWidth + paddingX, 350)
    let height = labels[0].0.frame.height + 2 * paddingY
    var nextY = CGFloat(0)
    for (i, (playerName, playerScore)) in labels.enumerated() {
      let line = SKNode()
      line.name = "highScoreLine"
      if i == numHighScores {
        // Extra space to separate the just-played game from the regular high scores
        nextY -= 3 * paddingY
      }
      line.position = CGPoint(x: 0, y: nextY)
      let box = SKShapeNode(rect: CGRect(x: -0.5 * width, y: -0.5 * height, width: width, height: height), cornerRadius: 2 * paddingY)
      box.name = "highScoreLineBox"
      box.fillColor = .white
      box.strokeColor = .clear
      box.alpha = 0.1
      box.zPosition = -1
      line.addChild(box)
      playerName.position = CGPoint(x: -0.5 * width + paddingX, y: 0)
      line.addChild(playerName)
      playerScore.position = CGPoint(x: 0.5 * width - paddingX, y: 0)
      line.addChild(playerScore)
      nextY -= height + paddingY
      scores.addChild(line)
    }
    return scores
  }

  func initScores(score: GameScore?, highScores: [GameScore]) {
    let highlighted = score ?? GameScore(points: 0)
    scores = SKNode()
    scores.name = "scores"
    scores.setZ(.info)
    addChild(scores)
    let title = SKLabelNode(fontNamed: AppColors.font)
    title.fontSize = 100
    title.fontColor = AppColors.highlightTextColor
    title.text = "High Scores"
    title.verticalAlignmentMode = .center
    title.position = CGPoint(x: fullFrame.midX, y: fullFrame.maxY - title.fontSize)
    scores.addChild(title)
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
    if !Globals.gcInterface.enabled {
      gcButton.disable()
    }
    scores.addChild(gcButton)
    let highScores = highScoreLines(highScores, highlighted: highlighted)
    let wantedMidY = 0.5 * (title.frame.minY + playButton.calculateAccumulatedFrame().maxY)
    // Center highScores vertically at wantedMidY
    highScores.position = .zero
    let highScoresY = round(wantedMidY - highScores.calculateAccumulatedFrame().midY)
    highScores.position = CGPoint(x: fullFrame.midX, y: highScoresY)
    scores.addChild(highScores)
  }

  func startGame() {
    switchToScene { return GameScene(size: self.fullFrame.size) }
  }

  func mainMenu() {
    showWhenQuiescent(Globals.menuScene)
  }

  /// Enforce pausing when showing the Game Center view controller.
  override var forcePause: Bool { showingGCVC }

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
    showingGCVC = true
    rootVC.present(gcvc, animated: true)
  }

  func gameCenterViewControllerDidFinish(_ gcvc: GKGameCenterViewController) {
    gcvc.dismiss(animated: true) {
      self.showingGCVC = false
      self.isPaused = false
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
    name = "highScoreScene"
    initGameArea(avoidSafeArea: false)
    physicsWorld.contactDelegate = self
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by HighScoreScene")
  }

  convenience init(size: CGSize, score: GameScore?) {
    self.init(size: size)
    var highScores = userDefaults.highScores.value
    if let gc = Globals.gcInterface, gc.enabled, !gc.leaderboardScores.isEmpty {
      var ranks = Array(1 ... gc.leaderboardScores.count)
      if gc.leaderboardScores.count >= 5 {
        ranks = [1, 3, 5]
        if gc.leaderboardScores.count >= 10 {
          ranks = [1, 3, 10]
        }
      }
      for rank in ranks {
        // This style keeps the Game Center names.
        // let globalScore = GameScore(score: gc.leaderboardScores[rank - 1])
        //
        // This styles replaces the names with Weekly #1, Weekly #10, etc.  I think
        // these are better for giving the player an idea of where they stand.  Note
        // that the display name is not considered in the sameScore test for adding
        // this score to highScores, so if the current player happens to be at one of
        // those positions then their name will still be used.  (Actually if they get
        // on to the global leaderboard at such a position but then reset their local
        // device high scores and come look at the high score screen, they won't see
        // their name, but it serves them right...)
        let globalScore = GameScore(score: gc.leaderboardScores[rank - 1], displayName: "Weekly #\(rank)")
        if (highScores.firstIndex { sameScore($0, globalScore) }) == nil {
          highScores.append(globalScore)
        }
      }
      highScores = highScores.sorted { $0.points > $1.points || ($0.points == $1.points && $0.date > $1.date) }
      for score in highScores {
        let date = Date(timeIntervalSinceReferenceDate: score.date)
        print("\(score.playerName ?? "unknown") \(score.points) \(score.date) \(date)")
      }
    }
    initScores(score: score, highScores: Array(highScores.prefix(10)))
  }
}
