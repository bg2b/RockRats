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

  func spawnAsteroids() {
    if asteroids.count < 15 {
      spawnAsteroid(size: ["big", "huge"].randomElement()!)
    }
    wait(for: 1) { self.spawnAsteroids() }
  }

  func spawnUFOs() {
    if asteroids.count >= 3 && ufos.isEmpty {
      spawnUFO(ufo: UFO(brothersKilled: 0, withSounds: false))
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

  override func didMove(to view: SKView) {
    initSounds()
    Globals.gameConfig = loadGameConfig(forMode: "menu")
    Globals.gameConfig.currentWaveNumber = 1
    wait(for: 1) { self.spawnAsteroids() }
    wait(for: 10) { self.spawnUFOs() }
  }

  override func update(_ currentTime: TimeInterval) {
    Globals.lastUpdateTime = currentTime
    ufos.forEach {
      $0.fly(player: nil, playfield: playfield) {
        (angle, position, speed) in self.fireUFOLaser(angle: angle, position: position, speed: speed)
      }
    }
    playfield.wrapCoordinates()
  }

  required init(size: CGSize) {
    super.init(size: size)
    initGameArea(limitAspectRatio: false)
    name = "menuScene"
    physicsWorld.contactDelegate = self
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by MenuScene")
  }
}
