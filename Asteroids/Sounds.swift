//
//  Sounds.swift
//  Asteroids
//
//  Created by David Long on 8/17/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

enum SoundEffect: String, CaseIterable {
  case playerExplosion = "player_explosion"
  case playerShot = "player_laser"
  case playerEngines = "player_engines"
  case asteroidHugeHit = "meteorhuge_hit"
  case asteroidBigHit = "meteorbig_hit"
  case asteroidMedHit = "meteormed_hit"
  case asteroidSmallHit = "meteorsmall_hit"
  case warpIn = "warpin"
  case warpOut = "warpout"
  case extraLife = "extra_life"
  case heartbeat = "heartbeat"
  case gameOver = "gameover"
  case ufoExplosion = "ufo_explosion"
  case ufoEngines = "ufo_engine"
}

class Sounds: SKNode {
  var backgroundMusic: SKAudioNode!
  let backgroundDoubleTempoInterval = 60.0
  let heartbeatRateInitial = 2.0
  let heartbeatRateMax = 0.25
  var currentHeartbeatRate = 0.0

  required init(listener: SKNode?) {
    super.init()
    name = "sounds"
    position = .zero
    scene?.listener = listener
    for effect in SoundEffect.allCases {
      preload(effect)
    }
    normalHeartbeatRate()
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Sounds")
  }

  func heartbeat() {
    soundEffect(.heartbeat, withVolume: 0.5)
    currentHeartbeatRate = max(0.99 * currentHeartbeatRate, heartbeatRateMax)
    run(SKAction.sequence([SKAction.wait(forDuration: currentHeartbeatRate),
                           SKAction.run { self.heartbeat() }]),
        withKey: "heartbeat")
  }

  func stopHeartbeat() {
    removeAction(forKey: "heartbeat")
  }

  func normalHeartbeatRate() {
    currentHeartbeatRate = heartbeatRateInitial
  }

  func audioNodeFor(url: URL) -> SKAudioNode {
    let audio = SKAudioNode(url: url)
    audio.isPositional = false
    audio.autoplayLooped = false
    return audio
  }

  func audioNodeFor(_ sound: SoundEffect) -> SKAudioNode {
    guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else {
      fatalError("Sound effect file \(sound.rawValue) missing")
    }
    return audioNodeFor(url: url)
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

  func soundEffect(_ sound: SoundEffect, at position: CGPoint? = nil, withVolume volume: Float = 1.0) {
    let effect = audioNodeFor(sound)
    if let position = position {
      effect.position = position
    }
    playOnce(effect, atVolume: volume)
  }
}
