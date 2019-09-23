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
  case heartbeatHigh = "heartbeat_high"
  case heartbeatLow = "heartbeat_low"
  case gameOver = "gameover"
  case ufoExplosion = "ufo_explosion"
  case ufoEnginesBig = "ufo1loop"
  case ufoEnginesSmall = "ufo2loop"
  case ufoShot = "ufo_laser"
  case ufoWarpOut = "ufo_warpout"
  case transmission = "transmission"
}

class Sounds: SKNode {
  let heartbeatRateInitial = 2.0
  let heartbeatRateMax = 0.5
  var currentHeartbeatRate = 0.0
  var heartbeatVolume: Float = 0.0
  var heartbeatOn = false

  override required init() {
    super.init()
    name = "sounds"
    position = .zero
    for effect in SoundEffect.allCases {
      preload(effect)
    }
    normalHeartbeatRate()
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Sounds")
  }

  func heartbeat() {
    if heartbeatOn {
      soundEffect(.heartbeatHigh, withVolume: heartbeatVolume)
      let fractionBetween = 0.2
      wait(for: fractionBetween * currentHeartbeatRate) {
        self.soundEffect(.heartbeatLow, withVolume: self.heartbeatVolume)
        self.heartbeatVolume = 0.5
        self.currentHeartbeatRate = max(0.98 * self.currentHeartbeatRate, self.heartbeatRateMax)
        self.wait(for: (1 - fractionBetween) * self.currentHeartbeatRate) { self.heartbeat() }
      }
    }
  }

  func startHearbeat() {
    normalHeartbeatRate()
    heartbeatOn = true
    heartbeat()
  }

  func stopHeartbeat() {
    heartbeatOn = false
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
    addChild(audio)
    audio.run(SKAction.sequence([SKAction.changeVolume(to: volume, duration: 0),
                                 SKAction.play(),
                                 SKAction.wait(forDuration: 1.0),
                                 SKAction.removeFromParent()]))
  }

  func preload(_ sound: SoundEffect) {
    playOnce(audioNodeFor(sound), atVolume: 0)
  }

  func soundEffect(_ sound: SoundEffect, withVolume volume: Float = 1.0) {
    let effect = audioNodeFor(sound)
    playOnce(effect, atVolume: volume)
  }
}

extension Globals {
  static let sounds = Sounds()
}
