//
//  MenuScene.swift
//  Asteroids
//
//  Created by David Long on 9/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import GameKit

class MenuScene: BasicScene { //, GKGameCenterControllerDelegate {
  var shotsFired = [UFO: Int]()
  var getRidOfUFOs = false
  var menu: SKNode!
  var highScore: SKLabelNode!
  weak var gameCenterAuthVC: UIViewController? = nil
  var presentingGCAuth = false

  func initMenu() {
    menu = SKNode()
    menu.name = "menu"
    menu.setZ(.info)
    addChild(menu)
    let title = SKLabelNode(fontNamed: AppColors.font)
    title.fontSize = 125
    title.fontColor = AppColors.highlightTextColor
    title.text = "ROCK RATS"
    title.verticalAlignmentMode = .center
    title.position = CGPoint(x: fullFrame.midX, y: 0.875 * fullFrame.midY + 0.125 * fullFrame.maxY)
    menu.addChild(title)
    highScore = SKLabelNode(fontNamed: AppColors.font)
    highScore.fontSize = 50
    highScore.fontColor = AppColors.highlightTextColor
    highScore.verticalAlignmentMode = .center
    highScore.position = CGPoint(x: fullFrame.midX, y: 0.75 * fullFrame.midY + 0.125 * fullFrame.minY)
    menu.addChild(highScore)
    let buttonSize = CGSize(width: 150, height: 100)
    let buttonSpacing = CGFloat(20)
    let buttonY = fullFrame.minY + buttonSize.height + buttonSpacing
    let playButton = Button(imageNamed: "playbutton", imageColor: AppColors.green, size: buttonSize)
    playButton.position = CGPoint(x: fullFrame.midX, y: buttonY)
    playButton.action = { [unowned self] in self.startGame() }
    menu.addChild(playButton)
    let highScoresButton = Button(imageNamed: "highscoresbutton", imageColor: AppColors.blue, size: buttonSize)
    highScoresButton.position = CGPoint(x: playButton.position.x + buttonSize.width + buttonSpacing, y: playButton.position.y)
    highScoresButton.action = { [unowned self] in self.showHighScores() }
    menu.addChild(highScoresButton)
    let settingsButton = Button(imageNamed: "settingsbutton", imageColor: AppColors.blue, size: buttonSize)
    settingsButton.position = CGPoint(x: playButton.position.x - buttonSize.width - buttonSpacing, y: playButton.position.y)
    settingsButton.action = { [unowned self] in self.showSettings() }
    menu.addChild(settingsButton)
  }

  func spawnAsteroids() {
    if asteroids.count < 15 {
      spawnAsteroid(size: ["big", "huge"].randomElement()!)
    }
    wait(for: 1) { self.spawnAsteroids() }
  }

  func spawnUFOs() {
    if !getRidOfUFOs && asteroids.count >= 3 && ufos.count < Globals.gameConfig.value(for: \.maxUFOs) {
      let ufo = UFO(brothersKilled: 0, audio: nil)
      spawnUFO(ufo: ufo)
      shotsFired[ufo] = 0
    }
    wait(for: 5) { self.spawnUFOs() }
  }

  override func warpOutUFO(_ ufo: UFO) {
    shotsFired.removeValue(forKey: ufo)
    super.warpOutUFO(ufo)
  }

  override func destroyUFO(_ ufo: UFO) {
    shotsFired.removeValue(forKey: ufo)
    super.destroyUFO(ufo)
  }

  func didBegin(_ contact: SKPhysicsContact) {
    when(contact, isBetween: .ufoShot, and: .asteroid) {
      ufoLaserHit(laser: $0, asteroid: $1)
    }
    when(contact, isBetween: .ufo, and: .asteroid) { ufoCollided(ufo: $0, asteroid: $1) }
    when(contact, isBetween: .ufo, and: .ufo) { ufosCollided(ufo1: $0, ufo2: $1) }
  }

  func prepareForSwitch() {
    getRidOfUFOs = true
    _ = warpOutUFOs(averageDelay: 0.25)
  }

  func showSettings() {
    prepareForSwitch()
    switchToScene { SettingsScene(size: self.fullFrame.size) }
  }

  func startGame() {
    prepareForSwitch()
    switchToScene { GameScene(size: self.fullFrame.size) }
  }

  func showHighScores() {
    prepareForSwitch()
    switchToScene { HighScoreScene(size: self.fullFrame.size, score: nil) }
  }

  /// Enforce pausing if the Game Center authentication controller is shown.
  override var forcePause: Bool { presentingGCAuth }

  func setGameCenterAuth(viewController: UIViewController?) {
    gameCenterAuthVC = viewController
    if gameCenterAuthVC == nil {
      logging("\(name!) clears Game Center view controller")
      presentingGCAuth = false
      isPaused = false
    } else {
      logging("\(name!) sets Game Center view controller")
    }
  }

  func gameCenterAuth() {
    if let gcvc = gameCenterAuthVC, !presentingGCAuth, let rootVC = view?.window?.rootViewController {
      logging("\(name!) will present Game Center view controller")
      presentingGCAuth = true
      isPaused = true
      rootVC.present(gcvc, animated: true)
    }
  }

  override func didMove(to view: SKView) {
    super.didMove(to: view)
    audio.muted = userDefaults.audioIsMuted.value
    Globals.gameConfig = loadGameConfig(forMode: "menu")
    Globals.gameConfig.currentWaveNumber = 1
    highScore.text = "High Score: \(userDefaults.highScores.highest)"
    wait(for: 1) { self.spawnAsteroids() }
    getRidOfUFOs = false
    wait(for: 10) { self.spawnUFOs() }
    logging("\(name!) finished didMove to view")
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    ufos.forEach { ufo in
      ufo.fly(player: nil, playfield: playfield) { (angle, position, speed) in
        if !self.getRidOfUFOs {
          self.fireUFOLaser(angle: angle, position: position, speed: speed)
          self.shotsFired[ufo] = self.shotsFired[ufo]! + 1
          if self.shotsFired[ufo]! > 3 && Int.random(in: 0 ..< 10) == 0 {
            self.warpOutUFO(ufo)
          }
        }
      }
    }
    playfield.wrapCoordinates()
    gameCenterAuth()
  }

  override init(size: CGSize) {
    super.init(size: size)
    name = "menuScene"
    initGameArea(avoidSafeArea: false)
    initMenu()
    physicsWorld.contactDelegate = self
    isUserInteractionEnabled = true
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let location = touch.location(in: self)
    for touched in nodes(at: location) {
      guard let body = touched.physicsBody else { continue }
      if body.isA(.asteroid) {
        splitAsteroid(touched as! SKSpriteNode)
        return
      } else if body.isA(.ufo) {
        destroyUFO(touched as! UFO)
      }
    }
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {}
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {}
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {}

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}
