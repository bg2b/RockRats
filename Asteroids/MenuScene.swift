//
//  MenuScene.swift
//  Asteroids
//
//  Created by David Long on 9/14/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class MenuScene: BasicScene {
  var asteroidsHit = 0
  var gameStarting = false
  var menu: SKNode!
  var highScore: SKLabelNode!

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
    let playButton = Button(forText: "Play", size: CGSize(width: 250, height: 75), fontName: "Kenney Future Narrow")
    playButton.position = CGPoint(x: fullFrame.midX, y: 0.625 * fullFrame.midY + 0.375 * fullFrame.minY)
    playButton.action = { [unowned self] in self.startGame() }
    menu.addChild(playButton)
  }

  func spawnAsteroids() {
    if asteroids.count < 15 {
      spawnAsteroid(size: ["big", "huge"].randomElement()!)
    }
    wait(for: 1) { self.spawnAsteroids() }
  }

  func spawnUFOs() {
    if !gameStarting && asteroids.count >= 3 && ufos.isEmpty {
      spawnUFO(ufo: UFO(brothersKilled: 0, audio: nil))
      asteroidsHit = 0
    }
    wait(for: 5) { self.spawnUFOs() }
  }

  func didBegin(_ contact: SKPhysicsContact) {
    when(contact, isBetween: .ufoShot, and: .asteroid) {
      ufoLaserHit(laser: $0, asteroid: $1)
      asteroidsHit += 1
      if asteroidsHit > 3 && Int.random(in: 0..<10) == 0 {
        let _ = warpOutUFOs()
      }
    }
    when(contact, isBetween: .ufo, and: .asteroid) { ufoCollided(ufo: $0, asteroid: $1) }
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
    let _ = warpOutUFOs(averageDelay: 0.25)
    let newGame = GameScene(size: fullFrame.size)
    switchWhenQuiescent(newGame)
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
    ufos.forEach {
      $0.fly(player: nil, playfield: playfield) { (angle, position, speed) in
        if !self.gameStarting {
          self.fireUFOLaser(angle: angle, position: position, speed: speed)
        }
      }
    }
    playfield.wrapCoordinates()
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
