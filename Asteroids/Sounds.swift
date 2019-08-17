//
//  Sounds.swift
//  Asteroids
//
//  Created by David Long on 8/17/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

enum SoundEffect: String {
  case playerExplosion = "player_explosion"
  case playerShot = "player_laser"
  case playerEngines = "player_engines"
  case asteroidHugeHit = "meteorhuge_hit"
  case asteroidBigHit = "meteorbig_hit"
  case asteroidMedHit = "meteormed_hit"
  case asteroidSmallHit = "smallAsteroidsNotImplemented"
}

class Sounds: SKNode {
  required init(listener: SKNode?) {
    super.init()
    name = "sounds"
    position = .zero
    scene?.listener = listener
    preload(.playerExplosion)
    preload(.playerShot)
    preload(.playerEngines)
    preload(.asteroidHugeHit)
    preload(.asteroidBigHit)
    preload(.asteroidMedHit)
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Sounds")
  }

  func audioNodeFor(_ sound: SoundEffect) -> SKAudioNode {
    guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else {
      fatalError("Sound effect file \(sound.rawValue) missing")
    }
    let audio = SKAudioNode(url: url)
    audio.isPositional = true
    audio.autoplayLooped = false
    return audio
  }

  func playOnce(_ audio: SKAudioNode, atVolume volume: Float) {
    audio.run(SKAction.sequence([SKAction.changeVolume(to: volume, duration: 0),
                                 SKAction.play(),
                                 SKAction.wait(forDuration: 1.0),
                                 SKAction.removeFromParent()]))
    addChild(audio)
  }

  func preload(_ sound: SoundEffect) {
    playOnce(audioNodeFor(sound), atVolume: 0)
  }

  func soundEffect(_ sound: SoundEffect, at position: CGPoint = .zero) {
    let effect = audioNodeFor(sound)
    effect.position = position
    playOnce(effect, atVolume: 1)
  }
}
