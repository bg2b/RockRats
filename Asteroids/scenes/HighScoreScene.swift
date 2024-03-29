//
//  HighScoreScene.swift
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
import os.log

// MARK: Demolition derby UFOs

/// A UFO that feels a strange affinity for others
class SmashyUFO: SKNode {
  /// The UFO's texture
  let ufoTexture: SKTexture
  /// How fast the UFO prefers to go
  let desiredSpeedRange = CGFloat(150) ... 350
  /// How massive the UFO is
  let mass: CGFloat

  // MARK: - Initialization

  /// Make a smashy UFO
  override init() {
    let type = Int.random(in: 0 ..< 3)
    ufoTexture = Globals.textureCache.findTexture(imageNamed: "ufo_\(["green", "blue", "red"][type])")
    mass = 1 - 0.25 * CGFloat(type)
    super.init()
    name = "smashyUFO"
    let sprite = SKSpriteNode(texture: ufoTexture)
    sprite.name = "smashySprite"
    addChild(sprite)
    let radius = 0.5 * ufoTexture.size().width
    let body = SKPhysicsBody(circleOfRadius: radius)
    body.mass = mass
    body.categoryBitMask = ObjectCategories.ufo.rawValue
    body.collisionBitMask = 0
    body.contactTestBitMask = ObjectCategories.ufo.rawValue
    body.linearDamping = 0
    body.angularDamping = 0
    body.angularVelocity = .random(in: -2 * .pi ... 2 * .pi)
    physicsBody = body
    // Originally I had an SKFieldNode for attraction between UFOs, but it performed
    // horribly with either iOS 12 and/or older devices (don't know which was really
    // responsible), so I'll instead just calculate the forces explicitly in fly().
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented SmashyUFO")
  }

  // MARK: - Movement

  /// Make the UFO fly around
  func fly(_ smashies: Set<SmashyUFO>) {
    let body = requiredPhysicsBody()
    let speed = body.velocity.length()
    if speed > desiredSpeedRange.upperBound {
      body.velocity = body.velocity.scale(by: 0.95)
    } else if speed < 0.1 * desiredSpeedRange.lowerBound {
      body.velocity = CGVector(angle: .random(in: 0 ... 2 * .pi)).scale(by: .random(in: desiredSpeedRange))
    } else if speed < desiredSpeedRange.lowerBound {
      body.velocity = body.velocity.scale(by: 1.05)
    }
    if Int.random(in: 0 ..< 100) == 0 {
      body.angularVelocity = .random(in: -2 * .pi ... 2 * .pi)
    }
    for ufo in smashies {
      guard ufo != self else { continue }
      let r = ufo.position - position
      // The + 1 shouldn't be needed since the collision ought to be flagged long
      // before it would be possible to get to small distances, but I stuck it in
      // just to avoid a one-in-a-zillion division-by-0 crash in case of lag.
      body.applyForce(r.scale(by: 200 * mass * ufo.mass / (r.length() + 1)))
    }
  }

  // MARK: - Death and hyperspace

  func cleanup() {
    // Be sure that any actions (which may have a closure with a self reference for
    // the scene, leading to a retain cycle) get nuked.
    removeAllActions()
    removeFromParent()
  }

  /// Make the UFO explode
  func explode() -> [SKNode] {
    let velocity = requiredPhysicsBody().velocity
    cleanup()
    return makeExplosion(texture: ufoTexture, angle: zRotation, velocity: velocity, at: position, duration: 2, cuts: 5)
  }

  /// Make the UFO jump to hyperspace
  func warpOut() -> [SKNode] {
    cleanup()
    return warpOutEffect(texture: ufoTexture, position: position, rotation: zRotation)
  }
}

// MARK: - High scores

/// Ensure that a name that won't make the high scores list too wide
/// - Parameter playerName: The name to be display
/// - Returns: The name unchanged if it's short, otherwise an abbreviated name
func abbreviatedName(_ playerName: String) -> String {
  let maxLength = 20
  if playerName.count > maxLength {
    // Cut off names that are too long
    return playerName.prefix(maxLength - 3) + "..."
  } else {
    return playerName
  }
}

/// The scene for displaying a list of high scores
///
/// This is automatically shown at the end of a game, and can also be invoked from
/// the main menu.
class HighScoreScene: BasicScene, GKGameCenterControllerDelegate {
  /// The buttons that invoke Game Center, if that's enabled
  var gcButtons = [Button]()
  /// This is `true` when I'm presenting the view controller supplied by Game Center
  /// with achievements and high scores
  var showingGCVC = false
  /// Demolition derby UFOs
  var smashies = Set<SmashyUFO>()
  /// Key for UFO spawning action
  let spawnSmashiesKey = "spawnSmashies"

  // MARK: - Initialization

  /// Make the labels for a line in the high scores display
  ///
  /// There are two labels per line, one for the player name and one for the score.
  /// The `highlighted` score is typically the score from the just-played game.  If
  /// `highScore` has the same player, then the name will be highlighted.  If
  /// `highScore` is also the same score, then the points will be highlighted too.
  ///
  /// - Parameters:
  ///   - highScore: The score to generate labels for
  ///   - highlighted: A score that should be highlighted
  /// - Returns: A tuple of labels, player name and score
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
    let attributes = AttrStyles(fontName: AppAppearance.font, fontSize: 35)
    playerName.attributedText = makeAttributed(text: playerNameText, until: playerNameText.endIndex, attributes: attributes)
    playerName.horizontalAlignmentMode = .left
    playerName.verticalAlignmentMode = .center
    playerScore.attributedText = makeAttributed(text: playerScoreText, until: playerScoreText.endIndex, attributes: attributes)
    playerScore.horizontalAlignmentMode = .right
    playerScore.verticalAlignmentMode = .center
    return (playerName, playerScore)
  }

  /// Construct an `SKNode` for the high score list
  ///
  /// The `highlighted` score is for the just-played game.  If that score isn't in
  /// the list, then there's an extra line added at the end of the high scores for
  /// `highlighted`.
  ///
  /// - Parameters:
  ///   - highScores: The list of high scores
  ///   - highlighted: What to highlight (see `highScoreLineLabels`)
  /// - Returns: A node that corresponds to the high scores display
  func highScoreLines(_ highScores: [GameScore], highlighted: GameScore) -> SKNode {
    // This has so many label and shape nodes that it blows the draw count if the
    // result is a regular SKNode.  But it's all static, so just make an SKEffectNode
    // and have it cache the rendered content.
    let scores = SKEffectNode()
    scores.name = "highScoreLines"
    scores.shouldRasterize = true
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
      // Each line in the display consists of a left-justified name, a
      // right-justified score, and a faint box around the two so that the eye can
      // match up name to score more easily.
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

  /// Construct all the information on the high scores scene
  /// - Parameters:
  ///   - score: The high scores
  ///   - highScores: What to highlight (typically the score of the just-played game)
  func initScores(score: GameScore?, highScores: [GameScore]) {
    let highlighted = score ?? GameScore(points: 0)
    let scores = SKNode()
    scores.name = "scores"
    scores.setZ(.info)
    addChild(scores)
    // Title
    let title = SKLabelNode(fontNamed: AppAppearance.font)
    title.fontSize = 100
    title.fontColor = AppAppearance.highlightTextColor
    title.text = "High Scores"
    title.verticalAlignmentMode = .center
    title.position = CGPoint(x: fullFrame.midX, y: fullFrame.maxY - title.fontSize)
    scores.addChild(title)
    // Buttons at the bottom
    let buttonSize = CGSize(width: 150, height: 100)
    let buttonSpacing = CGFloat(20)
    // New game
    let playButton = Button(imageNamed: "playbutton", imageColor: AppAppearance.playButtonColor, size: buttonSize)
    playButton.action = { [unowned self] in self.startGame() }
    // Main menu
    let menuButton = Button(imageNamed: "homebutton", imageColor: AppAppearance.buttonColor, size: buttonSize)
    menuButton.action = { [unowned self] in self.mainMenu() }
    // Go the the Game Center interface
    for gcIcon in ["gamecenter", "highscoresbutton"] {
      let gcButton = Button(imageNamed: gcIcon, imageColor: AppAppearance.yellow, size: buttonSize)
      gcButtons.append(gcButton)
      // Popping up the Game Center view controller pauses the scene, so the sound
      // would get cut off
      gcButton.makeSound = false
      let gcType: GKGameCenterViewControllerState = gcIcon == "gamecenter" ? .achievements : .leaderboards
      gcButton.action = { [unowned self] in self.showGameCenter(gcType) }
      // The Game Center button might need to be disabled
      if !Globals.gcInterface.enabled {
        gcButton.disable()
      }
    }
    // If the Game Center state changes, I have to change the button's
    // enabled/disabled state too.
    NotificationCenter.default.addObserver(self, selector: #selector(gcStateChanged), name: .authenticationChanged, object: nil)
    buttons = [menuButton, playButton] + gcButtons
    defaultFocus = playButton
    let bottomHstack = horizontalStack(nodes: buttons, minSpacing: buttonSpacing)
    bottomHstack.position = CGPoint(x: bottomHstack.position.x,
                                    y: fullFrame.minY + buttonSize.height + buttonSpacing - bottomHstack.position.y)
    scores.addChild(bottomHstack)
    // The actual high scores
    let highScores = highScoreLines(highScores, highlighted: highlighted)
    let wantedMidY = 0.5 * (title.frame.minY + bottomHstack.calculateAccumulatedFrame().maxY)
    // Center highScores vertically at wantedMidY
    highScores.position = .zero
    let highScoresY = round(wantedMidY - highScores.calculateAccumulatedFrame().midY)
    highScores.position = CGPoint(x: fullFrame.midX, y: highScoresY)
    scores.addChild(highScores)
  }

  /// Make a new high score scene
  /// - Parameters:
  ///   - size: The size of the scene
  ///   - score: The score of the just-played game (or `nil` if the previous scene
  ///     was the main menu)
  init(size: CGSize, score: GameScore?) {
    os_log("HighScoreScene init", log: .app, type: .debug)
    super.init(size: size)
    name = "highScoreScene"
    initGameArea(avoidSafeArea: false)
    physicsWorld.contactDelegate = self
    // Start with the local high scores
    var highScores = UserData.highScores.value
    // Add the just-earned score, if any
    if let score, !highScores.contains(where: { sameScore(score, $0) }) {
      highScores.append(score)
    }
    // Merge in scores from Game Center, if those are available
    if let gc = Globals.gcInterface, gc.enabled {
      for leaderboardName in ["weekly", "daily"] {
        let leaderboard = gc.leaderboard(leaderboardName)
        guard let scores = leaderboard.scores() else { continue }
        if scores.isEmpty {
          continue
        }
        var ranks = Array(1 ... scores.count)
        // The scores from the leaderboard at positions indicated by ranks will be
        // included in the display.  I'll show up to three scores from each
        // leaderboard.
        if scores.count >= 4 {
          ranks = [1, 2, 4]
          if scores.count >= 5 {
            ranks = [1, 3, 5]
            if scores.count >= 10 {
              ranks = [1, 3, 10]
            }
          }
        }
        // Leaderboard scores are shown like Weekly #2 or Daily #5 to give a better
        // picture of how the player compares globally
        let format = leaderboardName.capitalized + " #%d"
        for rank in ranks {
          let globalScore = GameScore(entry: scores[rank - 1],
                                      displayName: String(format: format, rank))
          // The same score might be on multiple leaderboards, and might also be
          // saved locally.  Be sure not to add the score more than once.
          if !highScores.contains(where: { sameScore(globalScore, $0) }) {
            highScores.append(globalScore)
          }
        }
        var playerScore = score?.points ?? 0
        if playerScore > 0 && leaderboardName == "weekly" {
          // See if the player has achieved a high rank on the weekly leaderboards
          // (either through the just-played game, or through a previous game)
          if let previousWeeklyPlayerEntry = leaderboard.localPlayerEntry {
            playerScore = max(playerScore, previousWeeklyPlayerEntry.score)
          }
          let weeklyRank = (scores.firstIndex { playerScore >= $0.score } ?? 100) + 1
          if weeklyRank == 1 {
            reportAchievement(achievement: .top10)
            reportAchievement(achievement: .top3)
            reportAchievement(achievement: .top1)
          } else if weeklyRank <= 3 {
            reportAchievement(achievement: .top10)
            reportAchievement(achievement: .top3)
          } else if weeklyRank <= 10 {
            reportAchievement(achievement: .top10)
          }
        }
      }
    }
    // Sort everything by points
    highScores = highScores.sorted { $0.points > $1.points || ($0.points == $1.points && $0.date > $1.date) }
    for score in highScores {
      let date = Date(timeIntervalSinceReferenceDate: score.date)
      os_log("score %{public}s %d %f %{public}s", log: .app, type: .debug,
             score.playerName ?? "unknown", score.points, score.date, "\(date)")
    }
    // Display the top ten combined scores
    initScores(score: score, highScores: Array(highScores.prefix(10)))
    if score != nil {
      // A game was just finished
      UserData.gamesPlayed.value += 1
      os_log("%d games played so far", log: .app, type: .debug, UserData.gamesPlayed.value)
    }
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  deinit {
    os_log("HighScoreScene deinit %{public}s", log: .app, type: .debug, "\(self.hash)")
  }

  // MARK: - Button actions

  /// Start a new game
  func startGame() {
    guard beginSceneSwitch() else { return }
    warpOutSmashies()
    switchWhenQuiescent { GameScene(size: self.fullFrame.size) }
  }

  /// Switch back to the main menu
  func mainMenu() {
    guard beginSceneSwitch() else { return }
    warpOutSmashies()
    switchWhenQuiescent { Globals.menuScene }
  }

  // MARK: - Game Center

  /// The Game Center status has changed, so update `gcButtons` enabled/disabled
  /// state to match
  /// - Parameter notification: A notification indicating what happened
  @objc func gcStateChanged(_ notification: Notification) {
    os_log("High score scene got notification of Game Center state change", log: .app, type: .debug)
    if notification.object as? Bool ?? false {
      gcButtons.forEach { $0.enable() }
    } else {
      gcButtons.forEach { $0.disable() }
    }
  }

  /// Enforce pausing when showing the Game Center view controller
  override var forcePause: Bool { showingGCVC }

  /// Display the view controller from Game Center with leaderboards and achievements
  func showGameCenter(_ state: GKGameCenterViewControllerState) {
    guard let rootVC = view?.window?.rootViewController, Globals.gcInterface.enabled else {
      os_log("Can't show Game Center", log: .app, type: .error)
      return
    }
    os_log("HighScoreScene will show Game Center", log: .app, type: .debug)
    let gcvc = GKGameCenterViewController(state: state)
    gcvc.gameCenterDelegate = self
    isPaused = true
    showingGCVC = true
    rootVC.present(gcvc, animated: true)
  }

  /// This is called when the Game Center view controller should be dismissed
  /// - Parameter gcvc: The Game Center view controller
  func gameCenterViewControllerDidFinish(_ gcvc: GKGameCenterViewController) {
    os_log("HighScoreScene finished showing Game Center", log: .app, type: .debug)
    gcvc.dismiss(animated: true) {
      self.showingGCVC = false
      self.isPaused = false
    }
  }

  // MARK: - Demolition derby

  /// Warp out one UFO
  /// - Parameter ufo: The UFO to get rid of
  func warpOutSmashy(_ ufo: SmashyUFO) {
    smashies.remove(ufo)
    audio.soundEffect(.ufoWarpOut, at: ufo.position)
    addToPlayfield(ufo.warpOut())
  }

  /// End the demolition derby
  func warpOutSmashies() {
    removeAction(forKey: spawnSmashiesKey)
    for ufo in smashies {
      let delay = Double.random(in: 0.5 ... 1.5)
      // Run the warp out action with a key so that destroySmashy can cancel it in
      // case of a collision before the warp happens
      ufo.run(.wait(for: delay) { self.warpOutSmashy(ufo) }, withKey: "warpOut")
    }
  }

  /// A UFO goes boom
  ///
  /// There's no sound effect here because all the collisions are between two UFOs,
  /// and it sounds better when there's only one sound effect played for the
  /// collision.
  ///
  /// - Parameter ufo: The UFO to destroy
  func destroySmashy(_ ufo: SmashyUFO) {
    // Be sure to cancel any pending warp
    ufo.removeAction(forKey: "warpOut")
    addToPlayfield(ufo.explode())
    smashies.remove(ufo)
  }

  /// Two UFOs had a head-on collision
  /// - Parameters:
  ///   - ufo1: The first UFO
  ///   - ufo2: The second UFO
  func smashiesCollided(ufo1: SKNode, ufo2: SKNode) {
    audio.soundEffect(.ufoExplosion, at: ufo1.position)
    destroySmashy(ufo1 as! SmashyUFO)
    destroySmashy(ufo2 as! SmashyUFO)
  }

  /// Handle possible contacts
  /// - Parameter contact: Info about the contact from the physics engine
  func didBegin(_ contact: SKPhysicsContact) {
    when(contact, isBetween: .ufo, and: .ufo) { smashiesCollided(ufo1: $0, ufo2: $1) }
  }

  /// Create a reckless UFO
  ///
  /// This method constantly respawns itself until stopped by `warpOutSmashies`
  func spawnSmashies() {
    if smashies.count < 4 {
      let ufo = SmashyUFO()
      let offset = 0.55 * ufo.ufoTexture.size().width
      let pos: CGPoint
      let x = CGFloat.random(in: -fullFrame.minX ... fullFrame.maxX + fullFrame.height)
      if x < fullFrame.maxX {
        // Spawn on top or bottom
        let y = Bool.random() ? fullFrame.minY - offset : fullFrame.maxY + offset
        pos = CGPoint(x: x, y: y)
      } else {
        let y = x - fullFrame.maxX + fullFrame.minY
        pos = CGPoint(x: Bool.random() ? fullFrame.minX - offset : fullFrame.maxX + offset, y: y)
      }
      ufo.position = pos
      let targetPoint = CGPoint(x: fullFrame.midX, y: fullFrame.midY) +
        CGVector(angle: .random(in: 0 ... 2 * .pi)).scale(by: 0.5 * fullFrame.height)
      let displacement = targetPoint - pos
      let v = displacement.scale(by: .random(in: ufo.desiredSpeedRange) / displacement.length())
      playfield.addWithScaling(ufo)
      let body = ufo.requiredPhysicsBody()
      body.velocity = v
      body.isOnScreen = false
      smashies.insert(ufo)
    }
    run(.wait(for: .random(in: 2 ... 3), then: spawnSmashies), withKey: spawnSmashiesKey)
  }

  /// Kick off the UFO demolition derby
  /// - Parameter view: The view that will present the scene
  override func didMove(to view: SKView) {
    super.didMove(to: view)
    bindControllerMenuButtons()
    run(.wait(for: 2, then: spawnSmashies), withKey: spawnSmashiesKey)
  }

  /// Main update loop
  /// - Parameter currentTime: The current game time
  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    for ufo in smashies {
      ufo.fly(smashies)
    }
    playfield.wrapCoordinates()
    endOfUpdate()
  }
}
