//
//  Sounds.swift
//  Asteroids
//
//  Created by David Long on 8/17/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import AVFoundation

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

  var url: URL {
    guard let url = Bundle.main.url(forResource: self.rawValue, withExtension: "wav") else {
      fatalError("Sound effect file \(self.rawValue) missing")
    }
    return url
  }

  func player() -> AVAudioPlayer {
    guard let result = try? AVAudioPlayer(contentsOf: self.url) else {
      fatalError("Unable to instantiate AVAudioPlayer")
    }
    result.prepareToPlay()
    return result
  }
}

let numSimultaneousSounds = [
  SoundEffect.playerShot: 5,
  .asteroidHugeHit: 5,
  .asteroidBigHit: 5,
  .asteroidMedHit: 5,
  .ufoExplosion: 3,
  .ufoEnginesBig: 3,
  .ufoEnginesSmall: 3,
  .ufoShot: 3,
  .ufoWarpOut: 3
]

class SoundEffectPlayers {
  let players: [AVAudioPlayer]
  var nextPlayer = -1

  init(forEffect effect: SoundEffect, count: Int) {
    players = (0..<count).map { _ in effect.player() }
  }

  func getNextPlayer() -> AVAudioPlayer {
    nextPlayer += 1
    if nextPlayer >= players.count {
      nextPlayer = 0
    }
    return players[nextPlayer]
  }
}

struct PositionalEffect {
  weak var player: AVAudioPlayer?
  weak var atNode: SKNode?
}

class Sounds {
  let heartbeatRateInitial = 2.0
  let heartbeatRateMax = 0.5
  var currentHeartbeatRate = 0.0
  var heartbeatVolume: Float = 0.0
  var heartbeatOn = false
  var audioPlayerCache = [SoundEffect: SoundEffectPlayers]()
  var positionalEffects = [PositionalEffect]()
  var stereoEffectsFrame = CGRect(origin: .zero, size: .zero)
  let soundQueue: DispatchQueue

  init() {
    soundQueue = DispatchQueue.global(qos: .background)
    for effect in SoundEffect.allCases {
      preload(effect)
    }
    normalHeartbeatRate()
  }

  func wait(for duration: Double, execute closure: @escaping () -> Void) {
    let dispatchTime = DispatchTime.now() + duration
    soundQueue.asyncAfter(deadline: dispatchTime, execute: closure)
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
    heartbeatOn = true
    heartbeat()
  }

  func stopHeartbeat() {
    heartbeatOn = false
  }

  func normalHeartbeatRate() {
    currentHeartbeatRate = heartbeatRateInitial
  }

  func audioPlayerFor(_ sound: SoundEffect) -> AVAudioPlayer {
    guard let players = audioPlayerCache[sound] else { fatalError("No players created for \(sound)") }
    return players.getNextPlayer()
  }

  func stereoBalance(_ position: CGPoint) -> Float {
    guard stereoEffectsFrame.width != 0 else { return 0 }
    guard position.x <= stereoEffectsFrame.maxX else { return 1 }
    guard position.x >= stereoEffectsFrame.minX else { return -1 }
    return Float((position.x - stereoEffectsFrame.midX) / (0.5 * stereoEffectsFrame.width))
  }

  func addPositional(player: AVAudioPlayer, at node: SKNode) {
    positionalEffects.append(PositionalEffect(player: player, atNode: node))
  }

  func preload(_ sound: SoundEffect) {
    audioPlayerCache[sound] = SoundEffectPlayers(forEffect: sound, count: numSimultaneousSounds[sound] ?? 1)
  }

  func startPlaying(_ player: AVAudioPlayer) {
    soundQueue.async {
      player.play()
    }
  }

  func soundEffect(_ sound: SoundEffect, at position: CGPoint = .zero, withVolume volume: Float = 1) {
    let player = audioPlayerFor(sound)
    let balance = stereoBalance(position)
    soundQueue.async {
      player.volume = volume
      player.pan = balance
      player.play()
    }
  }

  func adjustPositionalEffects() {
    for positional in positionalEffects {
      guard let player = positional.player, let node = positional.atNode else { continue }
      let balance = stereoBalance(node.position)
      soundQueue.async {
        player.pan = balance
      }
    }
    positionalEffects.removeAll { $0.player == nil || $0.atNode == nil }
  }
}

extension Globals {
  static let sounds = Sounds()
}
