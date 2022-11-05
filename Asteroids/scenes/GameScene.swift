//
//  GameScene.swift
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

// MARK: Special scores for hidden achievements

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
  SpecialScore(score: 2101, display: "In A.D. 2101", achievement: .allYourBase),
  SpecialScore(score: 3720, display: "3720 to 1", achievement: .whatAreTheOdds)
]

// MARK: - The game is afoot

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
  /// A label just below the score for showing the initial wave clearing bonus
  /// (usually hidden)
  var bonusDisplay: SKLabelNode!
  /// The currentTime in update when the player warped in (technically the last time
  /// before the ship appeared on the playfield, but whatevs)
  var lastWarpInTime = 0.0
  /// `true` in the time between when a wave ends (last asteroid removed) and the
  /// next starts; used to inhibit player spawning from starting UFO spawning too
  /// early
  var betweenWaves = false
  /// The number of UFOs that have been spawned in the current wave
  var numberOfUFOsThisWave = 0
  /// When the player kills a bunch of UFOs, they start getting more dangerous.  This
  /// records how many UFOs need to be avenged.
  var ufosToAvenge = 0
  /// The number of UFOs that the player has killed in a row, used for the
  /// `armedAndDangerous` achievement
  var ufosKilledWithoutDying = 0
  /// This is `true` in the interval between when the player dies to a UFO shot and
  /// when they respawn; used for the `bestServedCold` achievement
  var killedByUFO = false
  /// A fraction that multiples meanUFOTime, used to modulate the spawning rate
  /// according to circumstances
  var ufoSpawningRate = 0.0
  /// Becomes `true` just after the player kills a UFO, then `false` a couple of
  /// seconds later; used to hold off a ready-to-spawn UFO for just a bit
  var pauseUFOSpawning = false
  /// Becomes `true` after a UFO spawns and set back to `false` after about half a
  /// period; used to delay spawning when that would lead to multiple UFOs at once
  var pauseMultiSpawn = false
  /// How many times UFOs have fired a shot, used by the `redShirt` achievement
  var timesUFOsShot = 0
  /// A cache of ready-to-go UFOs
  var ufoCache: UFOCache!
  /// The label in the middle of the screen that displays wave numbers or Gave Over
  /// (usually hidden)
  var centralDisplay: SKLabelNode!
  /// How many extra ships they've received.  The difference between this and the
  /// number that should have been awarded based on score is what triggers the
  /// awarding of an extra.
  var extraLivesAwarded = 0
  /// The bonus they'll get if they clear the starting wave
  var bonus = 0
  /// Becomes `true` when the game is over, used to supress wave spawning
  var gameOver = false
  /// The number of player lasers that have hit something without a miss, used for
  /// the `archer`, `sniper`, `sharpshooter`, and `hawkeye` achievements
  var consecutiveHits = 0
  /// `true` when the heartbeat sound is running, set to `false` at the end of a game
  var heartbeatOn = false
  /// Starting heartbeat rate (period in seconds)
  let heartbeatRateInitial = 2.0
  /// Period of heartbeats at maximum heartbeat rate
  let heartbeatRateMax = 0.35
  /// Whatever the current heartbeat rate is, gradually decreases
  var currentHeartbeatRate = 0.0

  // MARK: - Initialization

  /// Add score, bonus display, and central display to game area (lives display,
  /// energy bar, and pause controls are added by the `super.initInfo()`)
  override func initInfo() {
    super.initInfo()
    // Score, bonus, and central display
    let moreInfo = SKNode()
    moreInfo.name = "moreInfo"
    moreInfo.setZ(.info)
    gameArea.addChild(moreInfo)
    scoreDisplay = SKLabelNode(fontNamed: AppAppearance.font)
    scoreDisplay.fontSize = 50
    scoreDisplay.fontColor = AppAppearance.textColor
    scoreDisplay.text = "0"
    scoreDisplay.name = "score"
    scoreDisplay.position = CGPoint(x: gameFrame.midX, y: gameFrame.maxY - scoreDisplay.fontSize)
    moreInfo.addChild(scoreDisplay)
    bonusDisplay = SKLabelNode(fontNamed: AppAppearance.font)
    bonusDisplay.fontSize = scoreDisplay.fontSize
    bonusDisplay.fontColor = AppAppearance.highlightTextColor
    bonusDisplay.text = ""
    bonusDisplay.name = "bonus"
    bonusDisplay.isHidden = true
    moreInfo.addChild(bonusDisplay)
    bonusDisplay.position = scoreDisplay.position + CGPoint(x: 0, y: -bonusDisplay.fontSize)
    centralDisplay = SKLabelNode(fontNamed: AppAppearance.font)
    centralDisplay.fontSize = 100
    centralDisplay.fontColor = AppAppearance.highlightTextColor
    centralDisplay.text = ""
    centralDisplay.name = "centralDisplay"
    centralDisplay.isHidden = true
    centralDisplay.verticalAlignmentMode = .center
    centralDisplay.position = CGPoint(x: gameFrame.midX, y: gameFrame.midY)
    moreInfo.addChild(centralDisplay)
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
  func initRetroShader() {
    let rgba = AppAppearance.transitionColor.cgColor.components!
    let shaderSource = """
    // Convert a pixel in a texture to grayscale
    float grayscale(vec2 coord, texture2d<float> texture) {
      vec4 color = texture2D(texture, coord);
      return 0.2 * color.r + 0.7 * color.g + 0.1 * color.b;
    }
    // Look for an edge in grayscale values at the given coordinate.
    // Delta determines the direction, and is oriented perpendicular
    // to the desired edge.
    float edge_detect(vec2 coord, vec2 delta, texture2d<float> texture) {
      return abs(grayscale(coord + delta, texture) - grayscale(coord - delta, texture));
    }
    void main() {
      // The 0.35 is a number of order 1 (= 1 pixel) that's been
      // chosen to make the effect look good for the game's particular
      // graphics.
      vec2 radius = 0.35 / a_size;
      float dx = radius.x;
      float dy = radius.y;
      float const invr2 = 0.707;  // 1/sqrt(2)
      // Look for edges horizontally, vertically, and diagonally
      float vedge = edge_detect(v_tex_coord, vec2(dx, 0.0), u_texture);
      float hedge = edge_detect(v_tex_coord, vec2(0.0, dy), u_texture);
      float d1edge = edge_detect(v_tex_coord, invr2 * vec2(dx, dy), u_texture);
      float d2edge = edge_detect(v_tex_coord, invr2 * vec2(dx, -dy), u_texture);
      // What's the overall edginess of the current pixel?
      float gray = hedge + vedge + d1edge + d2edge;
      // Amplifiy the edginess and clamp to 0-1 (high contrast B&W)
      gray = max(gray - 0.05, 0.0);
      gray *= 5.0;
      gray = min(gray, 1.0);
      // Match transition color for the blacks
      gl_FragColor = vec4(max(gray, \(rgba[0])), max(gray, \(rgba[1])), max(gray, \(rgba[2])), 1.0);
    }
    """
    let shader = SKShader(source: shaderSource)
    shader.attributes = [SKAttribute(name: "a_size", type: .vectorFloat2)]
    let pixelSize = vector_float2(Float(fullFrame.width), Float(fullFrame.height))
    setValue(SKAttributeValue(vectorFloat2: pixelSize), forAttribute: "a_size")
    self.shader = shader
  }

  /// Make a new game scene
  /// - Parameter size: The size of the scene
  init(size: CGSize) {
    os_log("GameScene init", log: .app, type: .debug)
    var shipColor: String?
    if unlockedShipColors().contains(UserData.shipColor.value) {
      shipColor = UserData.shipColor.value
    }
    super.init(size: size, shipColor: shipColor)
    name = "gameScene"
    initRetroShader()
    onlyRetro = true
    // onlyRetro is set to false if the retro shader is ever disabled, including by
    // the next line
    setRetroMode(enabled: achievementIsCompleted(.blastFromThePast) && UserData.retroMode.value)
    // Show touches according to preference
    displayingTouches = UserData.showTouches.value
    ufoCache = UFOCache(audio: audio)
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  deinit {
    os_log("GameScene deinit %{public}s", log: .app, type: .debug, "\(self.hash)")
  }

  // MARK: - Central display

  /// Display a message in the center of the screen, then do something
  ///
  /// There's an animation to make the message expand in from a tiny size, then pause
  /// and optionally fade out.
  ///
  /// - Parameters:
  ///   - message: The message to show
  ///   - fade: `true` if the message should fade out, `false` if it stays
  ///   - duration: Number of seconds to show the message
  ///   - action: What to do after the message fades out
  func displayMessage(_ message: String, fade: Bool, forTime duration: Double, then action: (() -> Void)? = nil) {
    centralDisplay.text = message
    centralDisplay.setScale(0.0)
    centralDisplay.alpha = 1.0
    centralDisplay.isHidden = false
    let grow = SKAction.sequence([
      .scale(to: 1.0, duration: 0.25),
      .wait(forDuration: duration)
    ])
    let growAndFade = SKAction.sequence([
      grow,
      .fadeOut(withDuration: 0.5),
      .hide(),
      // This slight extra delay makes sure that the WAVE # is gone from the screen
      // before spawnWave is called.  Without this delay, in extreme cases (like 100
      // asteroids spawned) there would be a slight stutter with the ghost of the
      // message still displayed.
      .wait(forDuration: 0.25)
      ])
    let displayAction = fade ? growAndFade : grow
    if let action {
      centralDisplay.run(displayAction, completion: action)
    } else {
      centralDisplay.run(displayAction)
    }
  }

  // MARK: - Heartbeat sounds

  /// Play the first part of a heartbeat sound, wait a bit, play the second part, and
  /// then reschedule `heartbeat`
  func heartbeat() {
    if heartbeatOn {
      audio.soundEffect(.heartbeatHigh)
      let fractionBetween = 0.5
      wait(for: fractionBetween * currentHeartbeatRate) {
        self.audio.soundEffect(.heartbeatLow)
        self.currentHeartbeatRate = max(0.98 * self.currentHeartbeatRate, self.heartbeatRateMax)
        self.wait(for: (1 - fractionBetween) * self.currentHeartbeatRate, then: self.heartbeat)
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

  // MARK: - Scoring

  /// How many points is a destroyed asteroid worth?
  /// - Parameter asteroid: The asteroid that was hit
  /// - Returns: The point value
  func asteroidPoints(_ asteroid: SKNode) -> Int {
    guard let name = asteroid.name else { fatalError("Asteroid should have a name") }
    // Small is not actually used...
    if name.contains("small") { return 20 }
    if name.contains("med") { return 10 }
    if name.contains("big") { return 5 }
    assert(name.contains("huge"), "Asteroids should be small, med, big, or huge")
    return 2
  }

  /// Point value for a particular UFO type
  func ufoPoints(_ type: UFOType) -> Int {
    return [20, 50, 100][type.rawValue]
  }

  /// How many points is a destroyed UFO worth?
  /// - Parameter ufo: The UFO that was hit
  /// - Returns: The point value
  func ufoPoints(_ ufo: SKNode) -> Int {
    guard let ufo = ufo as? UFO else { fatalError("The ufo doesn't have the UFO nature") }
    return ufoPoints(ufo.type)
  }

  /// When the player is starting at a wave number that's higher than 1, they get a
  /// bonus if they manage to clear it.  The bonus is an estimate of how many points
  /// they'd get if they played all the lower waves.  E.g., if they start on wave 3
  /// and clear it, they get a bonus that represents an approximate score for waves 1
  /// and 2.
  ///
  /// This function sets the initial bonus, and as a side effect advances the wave
  /// number to the desired starting value.  If the wave is cleared the bonus will be
  /// added to their score, and then the bonus is reset to 0.
  func setBonus(forWave wave: Int) {
    bonus = 0
    while Globals.gameConfig.waveNumber() + 1 < wave {
      // The next wave would be cleared
      Globals.gameConfig.nextWave()
      // Asteroid points would be exact aside from UFOs shooting them on occasion
      let numAsteroids = Globals.gameConfig.numAsteroids()
      let asteroidScore = (2 + 2 * 5 + 4 * 10) * numAsteroids
      // Weight UFO probabilities by point values to get the average number of points
      // per UFO
      var avgUfoScore = 0.0
      let ufoChances = Globals.gameConfig.value(for: \.ufoChances)
      for ufoType in UFOType.allCases {
        avgUfoScore += ufoChances[ufoType.rawValue] * Double(ufoPoints(ufoType))
      }
      // This is a rough estimate of how many UFOs they'll encounter before they
      // manage to destroy all the asteroids.  Empirically it's an underestimate for low
      // waves when they might try to farm, but gets better by about wave 4 or 5.
      let expectedUfos = Double(numAsteroids) / 2.5
      bonus += asteroidScore + Int(expectedUfos * avgUfoScore)
    }
  }

  /// All your base are belong to us
  func allYourBase() {
    let cat = SKSpriteNode(imageNamed: "cat")
    playfield.addChild(cat)
    cat.zPosition = -1
    cat.alpha = 0.0
    cat.run(.sequence([
      .fadeAlpha(to: 0.25, duration: 0.5),
      .wait(forDuration: 2.5),
      .fadeOut(withDuration: 0.5),
      .removeFromParent()]))
  }

  /// Add some points to the player's score
  ///
  /// This routine also handles awarding of extra lives and reporting achievements
  /// based on the score.
  ///
  /// - Parameter amount: The increment to the score
  func addToScore(_ amount: Int) {
    score += amount
    let extraLivesEarned = score / Globals.gameConfig.extraLifeScore
    // If the amount being added is a bonus from clearing the initial wave, it can be
    // large.  I want to report achievements for each multiple of extraLifeScore, but
    // no matter how many levels they pass they only get one real extra life.
    if extraLivesAwarded < extraLivesEarned {
      updateReserves(+1)
      audio.soundEffect(.extraLife)
      while extraLivesAwarded < extraLivesEarned {
        extraLivesAwarded += 1
        switch extraLivesAwarded {
        case 3:
          reportAchievement(achievement: .spaceCadet)
        case 4:
          reportAchievement(achievement: .spaceScout)
        case 5:
          reportAchievement(achievement: .spaceRanger)
        case 6:
          reportRepeatableAchievement(achievement: .spaceAce)
        case 8:
          reportRepeatableAchievement(achievement: .galacticGuardian)
        case 10:
          reportRepeatableAchievement(achievement: .cosmicChampion)
        default:
          break
        }
      }
    }
    scoreDisplay.text = "\(score)"
    // For certain special scores, show a custom message instead of a point value and
    // award a hidden achievement.  But don't give the achievement if they're in the
    // middle of blasting a bunch of asteroids and would zip past the score without
    // having time to appreciate the message.  So there's some delaying before the
    // actual reportAchievement.
    for special in specialScores where score == special.score {
      // Don't display the special message immediately in case the player is in the
      // middle of blasting a bunch of stuff and will zoom past it.
      wait(for: 0.75) {
        if self.score == special.score {
          self.scoreDisplay.text = special.display
          // Then wait a bit more to make sure they've had time to notice the message.
          self.wait(for: 1.5) {
            if self.score == special.score {
              if special.achievement == .allYourBase {
                self.allYourBase()
              }
              reportAchievement(achievement: special.achievement)
            }
          }
        }
      }
    }
  }

  /// Award a possible bonus for clearing the initial wave
  func awardBonus() {
    if bonus == 0 {
      return
    }
    // They started on a wave higher than 1 and cleared it, give the bonus (which
    // may in turn give an extra life)
    os_log("Awarding bonus of %d", log: .app, type: .debug, bonus)
    bonusDisplay.text = "Bonus +\(bonus)"
    bonusDisplay.alpha = 1.0
    bonusDisplay.isHidden = false
    let fadeAndHide = SKAction.sequence([
      .wait(forDuration: 1.5),
      .fadeOut(withDuration: 0.5),
      .hide()
      ])
    bonusDisplay.run(fadeAndHide)
    addToScore(bonus)
    bonus = 0
  }

  // MARK: - Asteroid spawning

  /// When an asteroid is removed, check to see if I should start a new wave
  override func asteroidRemoved() {
    if asteroids.isEmpty && !gameOver {
      os_log("Last asteroid removed at %f, going to spawn a wave", log: .app, type: .debug, Globals.lastUpdateTime)
      os_signpost(.event, log: .poi, name: "Last asteroid removed", signpostID: signpostID)
      awardBonus()
      normalHeartbeatRate()
      stopSpawningUFOs()
      betweenWaves = true
      // If the player dies from colliding with the last asteroid, then I have to
      // wait long enough for any of the player's remaining lasers to possibly hit a
      // UFO and score enough points for an extra life.  That wait is currently 4
      // seconds (see destroyPlayer).  If no points have been scored within 4 seconds
      // and the player is out of lives, then this action can be cancelled by
      // respawnOrGameOver.
      run(.wait(for: 4.1, then: nextWave), withKey: "spawnWave")
    }
  }

  /// Spawn a wave of asteroids
  func spawnWave() {
    os_log("Spawn next wave asteroids at %f", log: .app, type: .debug, Globals.lastUpdateTime)
    os_signpost(.event, log: .poi, name: "Spawn wave", signpostID: signpostID)
    if Globals.gameConfig.waveNumber() == 11 {
      reportAchievement(achievement: .spinalTap)
    }
    // One Little Prince asteroid is allowed per wave; if one spawns, the
    // littlePrinceAllowed flag will be cleared so that another can't
    littlePrinceAllowed = true
    let numAsteroids = Globals.gameConfig.numAsteroids()
    for _ in 1...numAsteroids {
      spawnAsteroid(size: .huge)
    }
    // UFOs will start appearing after a full duration period
    ufoSpawningRate = 1
    spawnUFOs()
  }

  /// Display the WAVE ## message, wait a bit, and then spawn asteroids
  func nextWave() {
    os_log("Next wave begins at %f", log: .app, type: .debug, Globals.lastUpdateTime)
    let clearedWave = Globals.gameConfig.waveNumber()
    if UserData.highestWaveCleared.value < clearedWave {
      os_log("Highest wave cleared now %d", log: .app, type: .debug, clearedWave)
      UserData.highestWaveCleared.value = clearedWave
    }
    Globals.gameConfig.nextWave()
    ufosToAvenge = 0
    ufosKilledWithoutDying = 0
    numberOfUFOsThisWave = 0
    betweenWaves = false
    displayMessage("WAVE \(Globals.gameConfig.waveNumber())", fade: true, forTime: 1.5) {
      self.spawnWave()
    }
  }

  // MARK: - UFO spawning and recycling

  /// Remove a UFO
  ///
  /// This is an override because I want to put the UFO back in the cache for use
  /// later.
  ///
  /// - Parameter ufo: The UFO being removed
  override func removeUFO(_ ufo: UFO) {
    super.removeUFO(ufo)
    ufoCache.recycle(ufo)
  }

  /// Move a UFO on to the playfield
  ///
  /// This is an override so that I can log the event
  ///
  /// - Parameter ufo: The UFO to launch
  override func launchUFO(_ ufo: UFO) {
    os_log("Launch UFO at %f", log: .app, type: .debug, Globals.lastUpdateTime)
    os_signpost(.event, log: .poi, name: "Launch UFO", signpostID: signpostID)
    super.launchUFO(ufo)
  }

  /// Consider spawning a UFO
  ///
  /// This is called periodically by an action started in `spawnUFOs`.  If conditions
  /// are right (the player is not dead/respawning/warping, there wouldn't be too
  /// many UFOs, etc.), then make a new UFO and start it launching.  Otherwise, wait
  /// a short time and then try to spawn again.  Once a UFO successfully spawns,
  /// increase the spawning rate and call `spawnUFOs` again.
  func maybeSpawnUFO() {
    if player.parent == nil || ufos.count >= Globals.gameConfig.value(for: \.maxUFOs) ||
      pauseUFOSpawning || (pauseMultiSpawn && !ufos.isEmpty) {
      // Don't spawn at this moment; either the player is dead/warping, or there are
      // already plenty of UFOs, or they just killed a UFO, or the spawn would give
      // multiple UFOs and it hasn't been very long since the previous spawn.  Wait a
      // bit and then try again.
      os_log("Cannot spawn UFO at %f", log: .app, type: .debug, Globals.lastUpdateTime)
      run(.wait(for: 2, then: maybeSpawnUFO), withKey: "spawnUFOs")
    } else {
      // Do the spawn
      os_log("Spawn UFO at %f", log: .app, type: .debug, Globals.lastUpdateTime)
      os_signpost(.event, log: .poi, name: "Spawn UFO", signpostID: signpostID)
      spawnUFO(ufo: ufoCache.getRandom(brothersKilled: ufosToAvenge))
      numberOfUFOsThisWave += 1
      // Once a UFO spawns, don't be eager to spawn a second
      pauseMultiSpawn = true
      run(.wait(for: 0.5 * Globals.gameConfig.value(for: \.meanUFOTime)) { self.pauseMultiSpawn = false },
          withKey: "multiSpawnDelay")
      if ufos.count == 2 {
        reportAchievement(achievement: .doubleTrouble)
      }
      // Increase tempo of spawning
      ufoSpawningRate = max(0.5 * ufoSpawningRate, 0.125)
      spawnUFOs()
    }
  }

  /// Start spawning UFOs
  ///
  /// The delay to the first potential spawn is controlled by `ufoSpawningRate` (and
  /// the `gameConfig` value).  After that delay, try to spawn a UFO; once the spawn
  /// succeeds, it will call `spawnUFOs` again (possibly with an adjusted delay).
  func spawnUFOs() {
    guard ufoSpawningRate > 0 else {
      fatalError("spawnUFOs called with ufoSpawningRate == 0")
    }
    removeAction(forKey: "spawnUFOs") // Remove any existing scheduled spawn
    let meanTimeToNextUFO = ufoSpawningRate * Globals.gameConfig.value(for: \.meanUFOTime)
    let delay = Double.random(in: 0.75 * meanTimeToNextUFO ... 1.25 * meanTimeToNextUFO)
    os_log("Try to spawn UFO in %f sec, rate %f, at %f", log: .app, type: .debug, delay, ufoSpawningRate, Globals.lastUpdateTime)
    run(.wait(for: delay, then: maybeSpawnUFO), withKey: "spawnUFOs")
  }

  /// Turn off UFO spawning (e.g., because the player died or a new wave is starting)
  func stopSpawningUFOs() {
    removeAction(forKey: "spawnUFOs")
    removeAction(forKey: "multiSpawnDelay")
    pauseMultiSpawn = false
    // Spawning rate zero means "don't spawn UFOs"
    ufoSpawningRate = 0
  }

  // MARK: - Player birth and death

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
      // I didn't find a safe position so wait a bit and try again.  Be a little more
      // aggressive about what is considered safe.
      os_log("No safe spot to spawn player at %f", log: .app, type: .debug, Globals.lastUpdateTime)
      wait(for: 0.5) { self.spawnPlayer(safeTime: max(safeTime - 0.25, 0)) }
    } else {
      os_log("Spawn player at %f", log: .app, type: .debug, Globals.lastUpdateTime)
      os_signpost(.event, log: .poi, name: "Spawn player", signpostID: signpostID)
      ufosToAvenge /= 2
      killedByUFO = false
      energyBar.fill()
      player.reset()
      player.warpIn(to: spawnPosition, atAngle: player.zRotation, addTo: playfield)
      audio.soundEffect(.warpIn, at: spawnPosition)
      // If spawning between waves, don't start with UFOs yet; the beginning of the
      // wave will start the them instead
      if betweenWaves {
        os_log("Player spawned between waves, so delay start of UFO spawning", log: .app, type: .debug)
      } else {
        switch numberOfUFOsThisWave {
        case 0:
          // At the start of a wave, or if they got killed before the first UFO appeared,
          // then give them a full duration period.
          ufoSpawningRate = 1
        case 1 ... 3:
          // For a normal number of UFOs, they get half a period
          ufoSpawningRate = 0.5
        default:
          // They've perhaps been hunting UFOs, so don't given them a break
          ufoSpawningRate = 0.25
        }
        spawnUFOs()
      }
      updateReserves(-1)
      consecutiveHits = 0
    }
  }

  /// The player died, decide whether to respawn them or end the game
  ///
  /// This routine is called some time after the player is destroyed.  A delay is
  /// needed so that any shots that the player might have fired will either expire or
  /// hit their targets.  Only after all the shots are gone do I know whether they
  /// might have just gotten enough points for an extra life.  (In other words, this
  /// routine is not called until it's certain that `livesRemaining` is stable.)
  ///
  /// In either case, any UFOs that are flying around should warp out.
  func respawnOrGameOver() {
    os_log("Respawn or game over at %f", log: .app, type: .debug, Globals.lastUpdateTime)
    let delay = warpOutUFOs() + 1
    if reservesRemaining > 0 {
      wait(for: delay) { self.spawnPlayer() }
    } else {
      // If the player wanted to rage quit after losing their last ship, they had
      // time to do it by now.  At this point, I'll always progress to the high
      // scores scene.
      disablePause()
      guard beginSceneSwitch() else { fatalError("respawnOrGameOver in GameScene found scene switch in progress???") }
      gameOver = true
      stopHeartbeat()
      removeAction(forKey: "spawnWave")
      if onlyRetro, let gc = Globals.gcInterface, gc.enabled {
        // If the whole game was played in retro mode, they get a cookie
        reportAchievement(achievement: .auldLangSyne)
      }
      wait(for: delay) {
        self.audio.soundEffect(.gameOver)
        // Start building the high scores scene in the background
        let gameScore = self.saveScoreAndPrepareHighScores()
        self.displayMessage("Game Over", fade: false, forTime: 5) {
          self.switchWhenQuiescent {
            self.endGameSaveProgress()
            return HighScoreScene(size: self.fullFrame.size, score: gameScore)
          }
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
    audio.soundEffect(.playerExplosion, at: player.position)
    addToPlayfield(player.explode())
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

  // MARK: - Contact handling

  /// Remove a player laser that missed
  /// - Parameter laser: The laser being removed
  override func laserExpired(_ laser: SKSpriteNode) {
    consecutiveHits = 0
    super.laserExpired(laser)
  }

  /// Count consecutive hits and award achievements at various levels
  func consecutiveHit() {
    consecutiveHits += 1
    switch consecutiveHits {
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
    if !asteroid.requiredPhysicsBody().isOnScreen {
      reportAchievement(achievement: .quickFingers)
    }
    UserData.asteroidsDestroyed.value += 1
    if UserData.asteroidsDestroyed.value % 100 == 0 {
      if let minDestroyed = reportAchievement(achievement: .rockRat, soFar: UserData.asteroidsDestroyed.value) {
        os_log("Bumping destroyed asteroids from %d to %d", log: .app, type: .info, UserData.asteroidsDestroyed.value, minDestroyed)
        UserData.asteroidsDestroyed.value = minDestroyed
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
    os_log("UFO hit by laser at %f", log: .app, type: .debug, Globals.lastUpdateTime)
    os_signpost(.event, log: .poi, name: "UFO shot by player", signpostID: signpostID)
    consecutiveHit()
    if killedByUFO {
      // The player died by getting shot by a UFO and hasn't respawned yet.
      reportAchievement(achievement: .bestServedCold)
    } else {
      ufosKilledWithoutDying += 1
      ufosToAvenge += 1
      pauseUFOSpawning = true
      wait(for: 2) { self.pauseUFOSpawning = false }
      if ufos.isEmpty {
        // No need to worry about spawning multiple UFOs anymore
        removeAction(forKey: "multiSpawnDelay")
        pauseMultiSpawn = false
      }
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
    UserData.ufosDestroyed.value += 1
    if UserData.ufosDestroyed.value % 5 == 0 {
      if let minDestroyed = reportAchievement(achievement: .ufoHunter, soFar: UserData.ufosDestroyed.value) {
        os_log("Bumping destroyed UFOs from %d to %d", log: .app, type: .info, UserData.ufosDestroyed.value, minDestroyed)
        UserData.ufosDestroyed.value = minDestroyed
      }
    }
    addToScore(ufoPoints(ufo))
    removeLaser(laser as! SKSpriteNode)
    destroyUFO(ufo as! UFO, collision: false)
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
    os_log("Player shot by UFO at %f", log: .app, type: .debug, Globals.lastUpdateTime)
    os_signpost(.event, log: .poi, name: "Player shot by UFO", signpostID: signpostID)
    if timesUFOsShot == 1 {
      reportAchievement(achievement: .redShirt)
    }
    if laser.requiredPhysicsBody().hasWrapped && !gameFrame.insetBy(dx: 200, dy: 200).contains(player.position) {
      reportAchievement(achievement: .itsATrap)
    }
    removeUFOLaser(laser as! SKSpriteNode)
    destroyPlayer()
    // This gets reset upon respawning, but if they happen to shoot a UFO in the
    // meantime, give them the revenge achievement.
    killedByUFO = true
  }

  /// The player ran into an asteroid
  /// - Parameter asteroid: The asteroid
  func playerCollided(asteroid: SKNode) {
    os_log("Player collided with asteroid at %f", log: .app, type: .debug, Globals.lastUpdateTime)
    os_signpost(.event, log: .poi, name: "Player collided with asteroid", signpostID: signpostID)
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
    os_log("Player and UFO collided at %f", log: .app, type: .debug, Globals.lastUpdateTime)
    os_signpost(.event, log: .poi, name: "Player collided with UFO", signpostID: signpostID)
    if (ufo as! UFO).type != .kamikaze {
      reportAchievement(achievement: .leeroyJenkins)
    }
    addToScore(ufoPoints(ufo))
    destroyUFO(ufo as! UFO, collision: true)
    destroyPlayer()
  }

  /// A UFO collided with an asteroid
  ///
  /// No special handling, but I do want to log the event for debugging purposes
  ///
  /// - Parameters:
  ///   - ufo: The UFO
  ///   - asteroid: The asteroid
  override func ufoCollided(ufo: SKNode, asteroid: SKNode) {
    os_log("UFO collided with asteroid at %f", log: .app, type: .debug, Globals.lastUpdateTime)
    os_signpost(.event, log: .poi, name: "UFO collided with asteroid", signpostID: signpostID)
    super.ufoCollided(ufo: ufo, asteroid: asteroid)
  }

  /// Two UFOs collided
  ///
  /// No special handling, though this is very rare (I think I saw it once, and
  /// wasn't logging then so can't say 100% for sure).  Maybe there should be a
  /// special achievement for witnessing this?
  ///
  /// - Parameters:
  ///   - ufo1: The first UFO
  ///   - ufo2: The second UFO
  override func ufosCollided(ufo1: SKNode, ufo2: SKNode) {
    os_log("UFOs collided at %f", log: .app, type: .debug, Globals.lastUpdateTime)
    os_signpost(.event, log: .poi, name: "UFOs collided", signpostID: signpostID)
    super.ufosCollided(ufo1: ufo1, ufo2: ufo2)
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

  // MARK: - End of game

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

  /// End of game, report the score to Game Center (if active) and get ready to
  /// transition to the high scores scene
  func saveScoreAndPrepareHighScores() -> GameScore {
    let gameScore = GameScore(points: score)
    _ = UserData.highScores.addScore(gameScore)
    if let gc = Globals.gcInterface, gc.enabled {
      // When Game Center is active, I need to report the score and refresh
      // leaderboards.  When game over calls this method, I have about 6 seconds
      // before the earliest possible transition to the high scores screen.  It
      // doesn't take long to create the high scores scene, so I'll report the score
      // immediately, then wait a couple of seconds to refresh Game Center
      // leaderboards, and then a couple more seconds for the leaderboard data to
      // load.  If the leaderboard data doesn't load in time, I'll wind up creating
      // the high scores scene with somewhat out-of-date Game Center scores, but
      // whatevs.
      gc.saveScore(score)
      wait(for: 2) { gc.loadLeaderboards() }
    }
    return gameScore
  }

  // MARK: - Playing a game

  /// Start a new game
  /// - Parameter view: The view that will present the scene
  override func didMove(to view: SKView) {
    super.didMove(to: view)
    Globals.gameConfig = loadGameConfig(forMode: "normal")
    Globals.gameConfig.currentWaveNumber = 0
    // Assume the player wants to start at the highest possible wave...
    var startWave = 999
    if UserData.startingWave.value > 0 {
      // No, a fixed value is desired...
      startWave = min(startWave, UserData.startingWave.value)
    }
    // But they can only skip waves that they've cleared in the past
    startWave = min(startWave, UserData.highestWaveCleared.value + 1)
    os_log("Game starts at wave %d", log: .app, type: .debug, startWave)
    setBonus(forWave: startWave)
    reservesRemaining = Globals.gameConfig.initialLives
    updateReserves(0)
    energyBar.fill()
    replenishEnergy()
    wait(for: 1) {
      if !UserData.heartbeatMuted.value {
        self.startHearbeat()
      }
      self.nextWave()
      self.wait(for: 3) { self.spawnPlayer() }
    }
  }

  /// Main update loop
  /// - Parameter currentTime: The game time
  override func update(_ currentTime: TimeInterval) {
    // Mark the start of the render loop
    super.update(currentTime)
    if player.parent == nil {
      lastWarpInTime = currentTime
    }
    ufos.forEach {
      $0.fly(player: player, playfield: playfield) { angle, position, speed in
        self.fireUFOLaser(angle: angle, position: position, speed: speed)
        self.timesUFOsShot += 1
      }
    }
    player.fly()
    playfield.wrapCoordinates()
    audio.update()
    endOfUpdate()
  }
}
