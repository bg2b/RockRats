//
//  GameScene.swift
//  Asteroids
//
//  Created by David Long on 9/13/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

/// A score associated with a hidden achievement
struct SpecialScore {
  let score: Int
  let display: String
  let achievement: Achievement
}

let specialScores = [
  SpecialScore(score: 42, display: "Don't Panic", achievement: .dontPanic),
  SpecialScore(score: 404, display: "404: Not Found", achievement: .score404),
  SpecialScore(score: 612, display: "B 612", achievement: .littlePrince),
  SpecialScore(score: 1701, display: "NCC-1701", achievement: .keepOnTrekking),
  SpecialScore(score: 1984, display: "I'm watching you", achievement: .bigBrother),
  SpecialScore(score: 2001, display: "A Space Oddity", achievement: .spaceOddity),
  SpecialScore(score: 3720, display: "3720 to 1", achievement: .whatAreTheOdds),
]

/// The scene for playing a game (surprise!)
///
/// Most of the actual graphics and control stuff is in GameTutorialScene or its
/// superclasses.  This is largely logic, e.g., starting a game, handling object
/// collisions, updating the score, blowing up the player, sending achievements to
/// Game Center, and reporting the achieved score and transitioning to the high score
/// screen at the end of a game.
class GameScene: GameTutorialScene {
  /// The label showing the current score
  var scoreDisplay: SKLabelNode!
  /// The currentTime in update when the player warped in (technically the last time
  /// before the ship appeared on the playfield, but whatevs)
  var lastWarpInTime = 0.0
  /// When the player kills a bunch of UFOs, they start getting more dangerous.  This
  /// records how many UFOs need to be avenged.
  var ufosToAvenge = 0
  /// The number of UFOs that the player has killed in a row, used for the
  /// `armedAndDangerous` achievement
  var ufosKilledWithoutDying = 0
  /// The number of UFOs killed without destroying an asteroid, used to increase the
  /// tempo of UFO spawning if it appears that the player is just hunting UFOs
  var consecutiveUFOsKilled = 0
  /// This is `true` in the interval between when the player dies to a UFO shot and
  /// when they respawn; used for the `bestServedCold` achievement
  var killedByUFO = false
  /// A fraction that multiples meanUFOTime, used to modulate the spawning rate
  /// according to circumstances.  If the player is just hunting UFOs, this may get
  /// as low as 0.25.
  var ufoSpawningRate = 0.0
  /// How many times UFOs have fired a shot, used by the `redShirt` achievement
  var timesUFOsShot = 0
  /// The label in the middle of the screen that displays wave numbers or GAME OVER
  /// (usually hidden)
  var centralDisplay: SKLabelNode!
  /// How many reserve ships they have left; the current ship doesn't count in this.
  var livesRemaining = 0
  /// How many extra ships they've received.  The difference between this and the
  /// number that should have been awarded based on score is what triggers the
  /// awarding of an extra.
  var extraLivesAwarded = 0
  /// Becomes true when the game is over, used to supress wave spawning
  var gameOver = false
  /// The number of player lasers that have hit something without a miss, used for
  /// the `archer`, `sniper`, `sharpshooter`, and `hawkeye` achievements
  var consecutiveHits = 0
  /// True when the heartbeat sound is running, set to false at the end of a game
  var heartbeatOn = false
  /// Starting heartbeat rate (period in seconds)
  let heartbeatRateInitial = 2.0
  /// Period of heartbeats at maximum heartbeat rate
  let heartbeatRateMax = 0.35
  /// Whatever the current heartbeat rate is, gradually decreases
  var currentHeartbeatRate = 0.0

  /// Add score and central display to game area (lives display, energy bar, and
  /// pause controls are added by the `super.initInfo()`)
  override func initInfo() {
    super.initInfo()
    // Score and central display
    let moreInfo = SKNode()
    moreInfo.name = "moreInfo"
    moreInfo.setZ(.info)
    gameArea.addChild(moreInfo)
    scoreDisplay = SKLabelNode(fontNamed: AppColors.font)
    scoreDisplay.fontSize = 50
    scoreDisplay.fontColor = AppColors.textColor
    scoreDisplay.text = "0"
    scoreDisplay.name = "score"
    scoreDisplay.position = CGPoint(x: gameFrame.midX, y: gameFrame.maxY - 50)
    moreInfo.addChild(scoreDisplay)
    centralDisplay = SKLabelNode(fontNamed: AppColors.font)
    centralDisplay.fontSize = 100
    centralDisplay.fontColor = AppColors.highlightTextColor
    centralDisplay.text = ""
    centralDisplay.name = "centralDisplay"
    centralDisplay.isHidden = true
    centralDisplay.verticalAlignmentMode = .center
    centralDisplay.position = CGPoint(x: gameFrame.midX, y: gameFrame.midY)
    moreInfo.addChild(centralDisplay)
  }

  /// Force quit the game
  ///
  /// Turns off the heartbeat and saves achievement progress before calling
  /// `super.doQuit()` to transition back to the menu.
  override func doQuit() {
    stopHeartbeat()
    endGameSaveProgress()
    super.doQuit()
  }

  /// Update game counters, achievement progress, etc., at the end of a game (or upon
  /// quit)
  func endGameSaveProgress() {
    updateGameCounters()
    if Globals.gcInterface.enabled {
      reportHiddenProgress()
      Globals.gcInterface.flushProgress()
    }
  }

  /// Start creation of the high scores scene
  ///
  /// After the scene construction finishes and the GAME OVER message has been
  /// displayed for a while, this is the scene that will be shown.
  ///
  /// - Parameter gameScore: The score earned in the game
  func prepareHighScoreScene(gameScore: GameScore) {
    self.makeSceneInBackground { HighScoreScene(size: self.fullFrame.size, score: gameScore) }
  }

  /// End of game, report the score to Game Center (if active) and get ready to
  /// transition to the high scores scene
  func saveScoreAndPrepareHighScores() {
    // When Game Center is active, we need to report the score and refresh
    // leaderboards.  When game over calls this method, we have 6 seconds before the
    // earliest possible transition to the high scores screen.  It doesn't take long
    // to create the high scores scene, so we'll report the score immediately, then
    // wait a couple of seconds to refresh Game Center leaderboards, and then a
    // couple more seconds for the leaderboard data to load.  If the leaderboard data
    // doesn't load in time, we'll wind up creating the high scores scene with
    // somewhat out-of-date Game Center scores, but whatevs.
    let gc = Globals.gcInterface!
    let gameScore = gc.enabled ? gc.saveScore(score) : GameScore(points: score)
    _ = userDefaults.highScores.addScore(gameScore)
    if gc.enabled {
      wait(for: 2) {
        gc.loadLeaderboards()
      }
    }
    wait(for: 4) {
      self.prepareHighScoreScene(gameScore: gameScore)
    }
  }

  /// Create the retro mode shader
  ///
  /// Retro mode turns on the scene's shader, which is created by this function.  The
  /// shader turns the game to black-and-white to somewhat mimic the look of the
  /// original Asteroids arcade game.  This is basically an edge detect shader, with
  /// parameters chosen to give a reasonable look given our graphics.  One caveat
  /// here is that it assumes Metal under the hood, since the `grayscale` and
  /// `edge_detect` functions take a `texture2d<float>` argument which is Metal
  /// syntax.  The behind-the-scenes translation from OpenGL to Metal doesn't seem to
  /// translate an OpenGL-style texture declaration in a function parameter
  /// appropriately.  If the translator ever changes, this should probably be
  /// updated.  Or better, it should be just rewritten entirely in Metal syntax if
  /// SpriteKit ever allows native Metal shaders.
  func initFutureShader() {
    let shaderSource = """
    float grayscale(vec2 coord, texture2d<float> texture) {
      vec4 color = texture2D(texture, coord);
      return 0.2 * color.r + 0.7 * color.g + 0.1 * color.b;
    }
    float edge_detect(vec2 coord, vec2 delta, texture2d<float> texture) {
      return abs(grayscale(coord + delta, texture) - grayscale(coord - delta, texture));
    }
    void main() {
      vec2 radius = 0.35 / a_size;
      float dx = radius.x;
      float dy = radius.y;
      float const invr2 = 0.707;
      float vedge = edge_detect(v_tex_coord, vec2(dx, 0.0), u_texture);
      float hedge = edge_detect(v_tex_coord, vec2(0.0, dy), u_texture);
      float d1edge = edge_detect(v_tex_coord, invr2 * vec2(dx, dy), u_texture);
      float d2edge = edge_detect(v_tex_coord, invr2 * vec2(dx, -dy), u_texture);
      float gray = hedge + vedge + d1edge + d2edge;
      gray = max(gray - 0.05, 0.0);
      gray *= 5.0;
      gray = min(gray, 1.0);
      gl_FragColor = vec4(gray, gray, gray, 0.0);
    }
    """
    let shader = SKShader(source: shaderSource)
    shader.attributes = [SKAttribute(name: "a_size", type: .vectorFloat2)]
    let pixelSize = vector_float2(Float(fullFrame.width), Float(fullFrame.height))
    setValue(SKAttributeValue(vectorFloat2: pixelSize), forAttribute: "a_size")
    self.shader = shader
  }

  /// Spawn a wave of asteroids
  func spawnWave() {
    if Globals.gameConfig.waveNumber() == 11 {
      reportAchievement(achievement: .spinalTap)
    }
    let numAsteroids = Globals.gameConfig.numAsteroids()
    for _ in 1...numAsteroids {
      spawnAsteroid(size: "huge")
    }
    logging("Spawned next wave")
    consecutiveUFOsKilled = 0
    // UFOs will start appearing after a full duration period
    ufoSpawningRate = 1
    spawnUFOs()
  }

  /// Display the WAVE ## message, wait a bit, and then spawn asteroids
  func nextWave() {
    Globals.gameConfig.nextWave()
    ufosToAvenge = 0
    ufosKilledWithoutDying = 0
    displayMessage("WAVE \(Globals.gameConfig.waveNumber())", forTime: 1.5) {
      self.spawnWave()
    }
  }

  /// Play the first part of a heartbeat sound, wait a bit, play the second part, and
  /// then repeat
  func heartbeat() {
    if heartbeatOn {
      audio.soundEffect(.heartbeatHigh)
      let fractionBetween = 0.5
      wait(for: fractionBetween * currentHeartbeatRate) {
        self.audio.soundEffect(.heartbeatLow)
        self.currentHeartbeatRate = max(0.98 * self.currentHeartbeatRate, self.heartbeatRateMax)
        self.wait(for: (1 - fractionBetween) * self.currentHeartbeatRate) { self.heartbeat() }
      }
    }
  }

  /// Turn on heartbeats at the initial (slow) rate
  func startHearbeat() {
    normalHeartbeatRate()
    heartbeatOn = true
    heartbeat()
  }

  /// Turn off heartbeats
  ///
  /// This actually doesn't cancel the action that might play the second half of a
  /// heartbeat, but it makes it so that the `heartbeat()` after that will just quit
  /// without doing anything.
  func stopHeartbeat() {
    heartbeatOn = false
  }

  /// Reset the heartbeat rate to the starting value (at the start of a wave)
  func normalHeartbeatRate() {
    currentHeartbeatRate = heartbeatRateInitial
  }

  /// When an asteroid is removed, check to see if we need to start a new wave
  override func asteroidRemoved() {
    if asteroids.isEmpty && !gameOver {
      normalHeartbeatRate()
      stopSpawningUFOs()
      logging("Last asteroid removed, going to spawn a wave")
      // If the player dies from colliding with the last asteroid, then we have to
      // wait long enough for any of the player's remaining lasers to possibly hit a
      // UFO and score enough points for an extra life.  That wait is currently 4
      // seconds (see destroyPlayer).  If no points have been scored within 4 seconds
      // and the player is out of lives, then this action can be cancelled by
      // respawnOrGameOver.
      run(SKAction.sequence([SKAction.wait(forDuration: 4.1), SKAction.run { self.nextWave() }]), withKey: "spawnWave")
    }
  }

  /// Add some points to the player's score
  ///
  /// This routine also handles awarding of extra lives and reporting achievements
  /// based on the score.
  ///
  /// - Parameter amount: The increment to the score
  func addToScore(_ amount: Int) {
    let initialScore = score
    score += amount
    let extraLivesEarned = score / Globals.gameConfig.extraLifeScore
    if extraLivesEarned > extraLivesAwarded {
      updateLives(+1)
      audio.soundEffect(.extraLife)
      extraLivesAwarded += 1
    }
    scoreDisplay.text = "\(score)"
    if initialScore < 3000 && score >= 3000 {
      reportAchievement(achievement: .spaceCadet)
    } else if initialScore < 4000 && score >= 4000 {
      reportAchievement(achievement: .spaceScout)
    } else if initialScore < 5000 && score >= 5000 {
      reportAchievement(achievement: .spaceRanger)
    } else if initialScore < 6000 && score >= 6000 {
      reportRepeatableAchievement(achievement: .spaceAce)
    }
    // For certain special scores, we show a custom message instead of a point value
    // and award a hidden achievement.  But we don't want to give the achievement if
    // they're in the middle of blasting a bunch of asteroids and would zip past the
    // score without having time to appreciate the message.  So there's some delaying
    // before the actual reportAchievement.
    for special in specialScores {
      if score == special.score {
        // We don't display the special message immediately in case the player is in the
        // middle of blasting a bunch of stuff and will zoom past it.
        wait(for: 0.75) {
          if self.score == special.score {
            self.scoreDisplay.text = special.display
            // Then we wait a bit more to make sure they've had time to notice the message.
            self.wait(for: 1.5) {
              if self.score == special.score {
                reportAchievement(achievement: special.achievement)
              }
            }
          }
        }
      }
    }
  }

  /// Update the reserve ships
  /// - Parameter amount: The amount by which to change the number of reserves
  func updateLives(_ amount: Int) {
    livesRemaining += amount
    livesDisplay.showLives(livesRemaining)
  }

  /// Display a message in the center of the screen for some time, then do something
  ///
  /// There's an animation to make the message expand in from a tiny size, then pause
  /// and fade out.
  ///
  /// - Parameters:
  ///   - message: The message to show
  ///   - duration: Number of seconds to show the message
  ///   - action: What to do after the message fades out
  func displayMessage(_ message: String, forTime duration: Double, then action: (() -> Void)? = nil) {
    centralDisplay.text = message
    centralDisplay.setScale(0.0)
    centralDisplay.alpha = 1.0
    centralDisplay.isHidden = false
    let growAndFade = SKAction.sequence([
      SKAction.scale(to: 1.0, duration: 0.25),
      SKAction.wait(forDuration: duration),
      SKAction.fadeOut(withDuration: 0.5),
      SKAction.hide(),
      // This slight extra delay makes sure that the WAVE # is gone from the screen
      // before spawnWave is called.  Without this delay, in extreme cases (like 100
      // asteroids spawned) there would be a slight stutter with the ghost of the
      // message still displayed.
      SKAction.wait(forDuration: 0.25)
      ])
    if let action = action {
      centralDisplay.run(growAndFade, completion: action)
    } else {
      centralDisplay.run(growAndFade)
    }
  }

  /// Spawn the player
  ///
  /// Prefer to put the player in the center of the screen, but if that spot is not
  /// safe, then try random positions.  The amount of time they should be safe is a
  /// paramter.  It starts out as whatever is configured in the `gameConfig`, but if
  /// there's no safe spot after a few tries, just pause a bit and repeat with a
  /// shorter safe time.  If `safeTime` ever hits zero, spawn regardless of safety.
  ///
  /// - Parameter safeTime: The amount of time that the player should be safe
  func spawnPlayer(safeTime: CGFloat = Globals.gameConfig.safeTime) {
    var spawnPosition = CGPoint(x: gameFrame.midX, y: gameFrame.midY)
    var attemptsRemaining = 5
    while attemptsRemaining > 0 && !isSafe(point: spawnPosition, forDuration: safeTime) {
      let spawnRegion = gameFrame.insetBy(dx: 0.33 * gameFrame.width, dy: 0.33 * gameFrame.height)
      spawnPosition = CGPoint(x: .random(in: spawnRegion.minX...spawnRegion.maxX),
                              y: .random(in: spawnRegion.minY...spawnRegion.maxY))
      attemptsRemaining -= 1
    }
    if attemptsRemaining == 0 {
      // We didn't find a safe position so wait a bit and try again.  Be a little more
      // aggressive about what is considered safe.
      wait(for: 0.5) { self.spawnPlayer(safeTime: max(safeTime - 0.25, 0)) }
    } else {
      ufosToAvenge /= 2
      killedByUFO = false
      energyBar.fill()
      player.reset()
      player.warpIn(to: spawnPosition, atAngle: player.zRotation, addTo: playfield)
      audio.soundEffect(.warpIn, at: spawnPosition)
      // Give them a full duration period before UFOs start appearing
      ufoSpawningRate = 1
      spawnUFOs()
      updateLives(-1)
      consecutiveHits = 0
    }
  }

  /// How many points is a destroyed asteroid worth?
  /// - Parameter asteroid: The asteroid that was hit
  func asteroidPoints(_ asteroid: SKNode) -> Int {
    guard let name = asteroid.name else { fatalError("Asteroid should have a name") }
    // Small is not actually used...
    if name.contains("small") { return 20 }
    if name.contains("med") { return 10 }
    if name.contains("big") { return 5 }
    assert(name.contains("huge"), "Asteroids should be small, med, big, or huge")
    return 2
  }

  /// How many points is a destroyed UFO worth?
  /// - Parameter ufo: The UFO that was hit
  func ufoPoints(_ ufo: SKNode) -> Int {
    guard let ufo = ufo as? UFO else { fatalError("The ufo doesn't have the UFO nature") }
    return ufo.isBig ? 20 : 100
  }

  /// Remove a player laser that missed
  /// - Parameter laser: The laser being removed
  override func laserExpired(_ laser: SKSpriteNode) {
    consecutiveHits = 0
    super.laserExpired(laser)
  }

  /// Count consecutive hits and award achievements at various levels
  func consecutiveHit() {
    consecutiveHits += 1
    switch consecutiveHits
    {
    case 10:
      reportAchievement(achievement: .archer)
    case 15:
      reportAchievement(achievement: .sniper)
    case 20:
      reportAchievement(achievement: .sharpshooter)
    case 30:
      reportAchievement(achievement: .hawkeye)
    default:
      break
    }
  }

  /// Handle a player's shot hitting an asteroid
  ///
  /// Awards the `quickFingers` achievement if the asteroid wasn't (more than half)
  /// on the screen yet.  This also keeps a count of total asteroids destroyed in
  /// order to award different levels of the `rockRate` achievement.
  ///
  /// - Parameters:
  ///   - laser: The shot
  ///   - asteroid: The asteroid that it hit
  func laserHit(laser: SKNode, asteroid: SKNode) {
    consecutiveHit()
    consecutiveUFOsKilled = 0
    if !asteroid.requiredPhysicsBody().isOnScreen {
      reportAchievement(achievement: .quickFingers)
    }
    userDefaults.asteroidsDestroyed.value += 1
    if userDefaults.asteroidsDestroyed.value % 100 == 0 {
      if let minDestroyed = reportAchievement(achievement: .rockRat, soFar: userDefaults.asteroidsDestroyed.value) {
        logging("Bumping destroyed asteroids from \(userDefaults.asteroidsDestroyed.value) to \(minDestroyed) because of Game Center")
        userDefaults.asteroidsDestroyed.value = minDestroyed
      }
    }
    addToScore(asteroidPoints(asteroid))
    removeLaser(laser as! SKSpriteNode)
    splitAsteroid(asteroid as! SKSpriteNode)
  }

  /// Handle a player's shot hitting a UFO
  ///
  /// This also handles various shooting-UFO achievements: `bestServedCold`,
  /// `armedAndDangerous`, `hanShotFirst`, `trickShot`, and different levels of
  /// `ufoHunter`.
  ///
  /// - Parameters:
  ///   - laser: The shot
  ///   - ufo: The UFO that it hit
  func laserHit(laser: SKNode, ufo: SKNode) {
    consecutiveHit()
    if killedByUFO {
      // The player died by getting shot by a UFO and hasn't respawned yet.
      reportAchievement(achievement: .bestServedCold)
    } else {
      consecutiveUFOsKilled += 1
      ufosKilledWithoutDying += 1
      ufosToAvenge += 1
      if ufosKilledWithoutDying == 12 {
        reportAchievement(achievement: .armedAndDangerous)
      }
    }
    if !ufo.requiredPhysicsBody().isOnScreen {
      reportAchievement(achievement: .hanShotFirst)
    }
    if laser.requiredPhysicsBody().hasWrapped {
      reportAchievement(achievement: .trickShot)
    }
    userDefaults.ufosDestroyed.value += 1
    if userDefaults.ufosDestroyed.value % 5 == 0 {
      if let minDestroyed = reportAchievement(achievement: .ufoHunter, soFar: userDefaults.ufosDestroyed.value) {
        logging("Bumping destroyed UFOs from \(userDefaults.ufosDestroyed.value) to \(minDestroyed) because of Game Center")
        userDefaults.ufosDestroyed.value = minDestroyed
      }
    }
    addToScore(ufoPoints(ufo))
    removeLaser(laser as! SKSpriteNode)
    destroyUFO(ufo as! UFO)
    if ufoSpawningRate > 0 {
      // UFO spawning is in effect (so, e.g., they didn't just kill a UFO after a
      // wave was cleared and the new wave hasn't yet spawned).  Reset the time to
      // the next UFO so that it doesn't show up immediately, but it's also not so
      // long as the usual full duration like when the player is destroyed or a new
      // wave starts.  Also, if it looks like they're just killing UFOs, go
      // double-time.
      ufoSpawningRate = consecutiveUFOsKilled >= 2 ? 0.25 : min(0.5, ufoSpawningRate)
      spawnUFOs()
    }
  }

  /// Consider spawning a UFO
  ///
  /// This is called periodically by actions started in `spawnUFOs`.  If conditions
  /// are right (the player is not dead/respawning/warping, there wouldn't be too
  /// many UFOs, etc.), then make a new UFO and start it spawning.
  func maybeSpawnUFO() {
    guard player.parent != nil else { return }
    guard ufos.count < Globals.gameConfig.value(for: \.maxUFOs) else { return }
    spawnUFO(ufo: UFO(brothersKilled: ufosToAvenge, audio: audio))
    if ufos.count == 2 {
      reportAchievement(achievement: .doubleTrouble)
    }
  }

  /// Start spawning UFOs
  ///
  /// The delay to the first potential spawn is controlled by `ufoSpawningRate` (and
  /// the `gameConfig` value).  After that delay, try to spawn a UFO and then repeat
  /// `spawnUFOs`.
  func spawnUFOs() {
    guard ufoSpawningRate > 0 else {
      fatalError("spawnUFOs called with ufoSpawningRate == 0")
    }
    removeAction(forKey: "spawnUFOs") // Remove any existing scheduled spawn
    let meanTimeToNextUFO = ufoSpawningRate * Globals.gameConfig.value(for: \.meanUFOTime)
    let delay = Double.random(in: 0.75 * meanTimeToNextUFO ... 1.25 * meanTimeToNextUFO)
    logging("Maybe spawn UFO in \(delay) seconds, relativeDuration \(ufoSpawningRate)")
    run(SKAction.sequence([SKAction.wait(forDuration: delay),
                           SKAction.run { self.maybeSpawnUFO(); self.spawnUFOs() }]),
        withKey: "spawnUFOs")
  }

  /// Turn off UFO spawning (e.g., because the player died or a new wave is starting)
  func stopSpawningUFOs() {
    removeAction(forKey: "spawnUFOs")
    // Spawning rate zero means "don't spawn UFOs"
    ufoSpawningRate = 0
  }

  /// The player died, decide whether to respawn them or end the game
  ///
  /// This routine is called some time after the player is destroyed.  A delay is
  /// needed so that any shots that the player might have fired will either expire or
  /// hit their targets.  Only after all the shots are gone do we know whether they
  /// might have just gotten enough points for an extra life.
  ///
  /// In either case, any UFOs that are flying around should warp out.
  func respawnOrGameOver() {
    let delay = warpOutUFOs() + 1
    if livesRemaining > 0 {
      wait(for: delay) { self.spawnPlayer() }
    } else {
      gameOver = true
      stopHeartbeat()
      self.removeAction(forKey: "spawnWave")
      wait(for: delay) {
        self.audio.soundEffect(.gameOver)
        self.endGameSaveProgress()
        self.saveScoreAndPrepareHighScores()
        self.displayMessage("GAME OVER", forTime: 4)
        self.wait(for: 6) {
          // saveScoreAndPrepareHighScores has been preparing the high score scene in
          // the background.  After GAME OVER has been displayed for a while,
          // transition whenever the scene is ready.
          self.switchWhenReady()
        }
      }
    }
  }

  /// The player died in some way
  ///
  /// Make an explosion, award `rightPlaceWrongTime` if appropriate, turn off UFO
  /// spawning and reset various UFO-related counters.
  ///
  /// There's a slow-motion effect so that the player can appreciate their demise in
  /// all its glory ;-).
  func destroyPlayer() {
    if Globals.lastUpdateTime - lastWarpInTime <= 0.1 {
      reportAchievement(achievement: .rightPlaceWrongTime)
    }
    ufosKilledWithoutDying = 0
    consecutiveUFOsKilled = 0
    audio.soundEffect(.playerExplosion, at: player.position)
    addExplosion(player.explode())
    stopSpawningUFOs()
    playfield.changeSpeed(to: 0.25)
    // Lasers live for a bit less than a second.  If the player fires and immediately
    // dies, then due to the slow-motion effect that can get stretched to a bit less
    // than 4 seconds.  If the player was going to hit anything to score some points
    // and gain a life, then it should have happened by the time respawnOrGameOver is
    // called.
    wait(for: 4) {
      self.playfield.changeSpeed(to: 1)
      self.respawnOrGameOver()
    }
  }

  /// A UFO shot the player
  ///
  /// Handles getting-shot achievements `redShirt` and `itsATrap`, and sets
  /// `killedByUFO` so that `bestServedCold` can be awarded if one of the player's
  /// shots happens to hit the UFO in return.
  ///
  /// - Parameters:
  ///   - laser: The UFO's shot
  ///   - player: The player
  func ufoLaserHit(laser: SKNode, player: SKNode) {
    if timesUFOsShot == 1 {
      reportAchievement(achievement: .redShirt)
    }
    if laser.requiredPhysicsBody().hasWrapped && !gameFrame.insetBy(dx: 200, dy: 200).contains(player.position) {
      reportAchievement(achievement: .itsATrap)
    }
    removeUFOLaser(laser as! SKSpriteNode)
    destroyPlayer()
    // This gets reset upon respawning, but if they happen to shoot a UFO in the
    // meantime, we give them the revenge achievement.
    killedByUFO = true
  }

  /// The player ran into an asteroid
  /// - Parameter asteroid: The asteroid
  func playerCollided(asteroid: SKNode) {
    addToScore(asteroidPoints(asteroid))
    splitAsteroid(asteroid as! SKSpriteNode)
    destroyPlayer()
  }

  /// The player collided with a UFO
  ///
  /// Awards `leeroyJenkins` if it was a regular UFO.
  ///
  /// - Parameter ufo: The UFO that they hit
  func playerHitUFO(ufo: SKNode) {
    if !(ufo as! UFO).isKamikaze {
      reportAchievement(achievement: .leeroyJenkins)
    }
    addToScore(ufoPoints(ufo))
    destroyUFO(ufo as! UFO)
    destroyPlayer()
  }

  /// Handles all the possible physics engine contact notifications
  /// - Parameter contact: What contacted what
  func didBegin(_ contact: SKPhysicsContact) {
    when(contact, isBetween: .playerShot, and: .asteroid) { laserHit(laser: $0, asteroid: $1) }
    when(contact, isBetween: .player, and: .asteroid) { playerCollided(asteroid: $1) }
    when(contact, isBetween: .playerShot, and: .ufo) { laserHit(laser: $0, ufo: $1) }
    when(contact, isBetween: .player, and: .ufo) { playerHitUFO(ufo: $1) }
    when(contact, isBetween: .ufoShot, and: .asteroid) { ufoLaserHit(laser: $0, asteroid: $1)}
    when(contact, isBetween: .ufo, and: .asteroid) { ufoCollided(ufo: $0, asteroid: $1) }
    when(contact, isBetween: .ufo, and: .ufo) { ufosCollided(ufo1: $0, ufo2: $1) }
    when(contact, isBetween: .ufoShot, and: .player) { ufoLaserHit(laser: $0, player: $1)}
  }

  /// Start a new game
  /// - Parameter view: The view that will present the scene
  override func didMove(to view: SKView) {
    super.didMove(to: view)
    joystickTouch = nil
    fireOrWarpTouches.removeAll()
    Globals.gameConfig = loadGameConfig(forMode: "normal")
    Globals.gameConfig.currentWaveNumber = 0
    score = 0
    addToScore(0)
    lastWarpInTime = 0
    timesUFOsShot = 0
    livesRemaining = Globals.gameConfig.initialLives
    extraLivesAwarded = 0
    updateLives(0)
    gameOver = false
    energyBar.fill()
    replenishEnergy()
    wait(for: 1) {
      self.startHearbeat()
      self.nextWave()
      self.wait(for: 3) { self.spawnPlayer() }
    }
    logging("\(name!) finished didMove to view")
  }

  /// Main update loop
  /// - Parameter currentTime: The game time
  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    if player.parent == nil {
      lastWarpInTime = currentTime
    }
    ufos.forEach {
      $0.fly(player: player, playfield: playfield) {
        (angle, position, speed) in self.fireUFOLaser(angle: angle, position: position, speed: speed)
        timesUFOsShot += 1
      }
    }
    player.fly()
    playfield.wrapCoordinates()
    audio.update()
  }

  /// Make a new game scene
  /// - Parameter size: The size of the scene
  override init(size: CGSize) {
    super.init(size: size)
    name = "gameScene"
    initFutureShader()
    player = Ship(color: "blue", getJoystickDirection: { [unowned self] in return self.joystickDirection }, audio: audio)
    setRetroMode(enabled: achievementIsCompleted(achievement: .blastFromThePast) && userDefaults.retroMode.value)
    physicsWorld.contactDelegate = self
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}
