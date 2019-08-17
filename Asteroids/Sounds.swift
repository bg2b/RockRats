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
  case extraLife = "extra_life"
}

class Sounds: SKNode {
  var backgroundMusic: SKAudioNode!
  let backgroundDoubleTempoInterval = 60.0

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
    guard let backgroundMusicURL = Bundle.main.url(forResource: "spacefighter", withExtension: "mp3") else {
      fatalError("Background music file missing")
    }
    backgroundMusic = audioNodeFor(url: backgroundMusicURL)
    backgroundMusic.isPositional = false
    backgroundMusic.autoplayLooped = true
    backgroundMusic.run(SKAction.changeVolume(to: 0.25, duration: 0))
    addChild(backgroundMusic)
    increaseBackgroundTempo()
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by Sounds")
  }

  func increaseBackgroundTempo() {
    backgroundMusic.run(SKAction.changePlaybackRate(by: 1 / Float(backgroundDoubleTempoInterval),
                                                    duration: 3 * backgroundDoubleTempoInterval))
  }

  func normalBackgroundTempo() {
    backgroundMusic.removeAllActions()
    backgroundMusic.run(SKAction.changePlaybackRate(to: 1, duration: 10)) { self.increaseBackgroundTempo() }
  }

  func audioNodeFor(url: URL) -> SKAudioNode {
    let audio = SKAudioNode(url: url)
    audio.isPositional = true
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

  func soundEffect(_ sound: SoundEffect, at position: CGPoint = .zero) {
    let effect = audioNodeFor(sound)
    effect.position = position
    playOnce(effect, atVolume: 1)
  }
}
