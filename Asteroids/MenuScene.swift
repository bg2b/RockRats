//
//  MenuScene.swift
//  Asteroids
//
//  Created by David Long on 9/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import GameKit

class MenuScene: BasicScene, GKGameCenterControllerDelegate {
  var shotsFired = [UFO: Int]()
  var gameStarting = false
  var menu: SKNode!
  var highScore: SKLabelNode!
  weak var gameCenterAuthVC: UIViewController? = nil
  var presentingGCAuth = false

  func initMenu() {
    menu = SKNode()
    menu.name = "menu"
    menu.zPosition = LevelZs.info.rawValue
    addChild(menu)
    let title = SKLabelNode(fontNamed: "Kenney Future Narrow")
    title.fontSize = 125
    title.fontColor = AppColors.highlightTextColor
    title.text = "ROCK RATS"
    title.verticalAlignmentMode = .center
    title.position = CGPoint(x: fullFrame.midX, y: 0.875 * fullFrame.midY + 0.125 * fullFrame.maxY)
    menu.addChild(title)
    highScore = SKLabelNode(fontNamed: "Kenney Future Narrow")
    highScore.fontSize = 50
    highScore.fontColor = AppColors.highlightTextColor
    highScore.verticalAlignmentMode = .center
    highScore.position = CGPoint(x: fullFrame.midX, y: 0.75 * fullFrame.midY + 0.125 * fullFrame.minY)
    menu.addChild(highScore)
    let buttonHeight = CGFloat(50)
    let playButton = Button(forText: "Play", size: CGSize(width: 400, height: buttonHeight), fontName: "Kenney Future Narrow")
    playButton.position = CGPoint(x: fullFrame.midX, y: 0.625 * fullFrame.midY + 0.375 * fullFrame.minY)
    playButton.action = { [unowned self] in self.startGame() }
    menu.addChild(playButton)
    let gcButton = Button(forText: "Game Center", size: CGSize(width: 400, height: buttonHeight), fontName: "Kenney Future Narrow")
    gcButton.position = CGPoint(x: fullFrame.midX, y: playButton.position.y - buttonHeight - 25)
    gcButton.action = { [unowned self] in self.showGameCenter() }
    menu.addChild(gcButton)
  }

  func spawnAsteroids() {
    if asteroids.count < 15 {
      spawnAsteroid(size: ["big", "huge"].randomElement()!)
    }
    wait(for: 1) { self.spawnAsteroids() }
  }

  func spawnUFOs() {
    if !gameStarting && asteroids.count >= 3 && ufos.count < Globals.gameConfig.value(for: \.maxUFOs) {
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

  func switchWhenQuiescent(_ newScene: SKScene) {
    if playfield.isQuiescent(transient: setOf([.ufo, .ufoShot, .fragment])) {
      wait(for: 0.25) { self.switchScene(to: newScene) }
    } else {
      wait(for: 0.25) { self.switchWhenQuiescent(newScene) }
    }
  }

  func startGame() {
    gameStarting = true
    _ = warpOutUFOs(averageDelay: 0.25)
    let newGame = GameScene(size: fullFrame.size)
    switchWhenQuiescent(newGame)
  }

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
    Globals.gameConfig = loadGameConfig(forMode: "menu")
    Globals.gameConfig.currentWaveNumber = 1
    highScore.text = "High Score: \(Globals.userData.highScore.value)"
    wait(for: 1) { self.spawnAsteroids() }
    gameStarting = false
    wait(for: 10) { self.spawnUFOs() }
    logging("\(name!) finished didMove to view")
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    ufos.forEach { ufo in
      ufo.fly(player: nil, playfield: playfield) { (angle, position, speed) in
        if !self.gameStarting {
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

  required init(size: CGSize) {
    super.init(size: size)
    name = "menuScene"
    initGameArea(avoidSafeArea: true)
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

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by MenuScene")
  }
}
