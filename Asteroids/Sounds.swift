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
  case ufoEnginesMed = "ufo3loop"
  case ufoEnginesSmall = "ufo2loop"
  case ufoShot = "ufo_laser"
  case ufoWarpOut = "ufo_warpout"
  case transmission = "transmission"

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
  .ufoShot: 5,
  .ufoWarpOut: 3,
  .ufoEnginesBig: 0,
  .ufoEnginesMed: 0,
  .ufoEnginesSmall: 0,
  .playerEngines: 0
]

class Sounds {
  var audioPlayerCache = CyclicCache<SoundEffect, AVAudioPlayer>()
  var gameAudio = [SceneAudioInfo]()
  let soundQueue: DispatchQueue

  init() {
    do {
      logging("Activating shared audio session")
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      logging("Couldn't activate AVAudioSession, but whatevs")
      logging(error.localizedDescription)
    }
    soundQueue = DispatchQueue.global(qos: .background)
    for effect in SoundEffect.allCases {
      preload(effect)
    }
  }

  func preload(_ sound: SoundEffect) {
    audioPlayerCache.load(count: numSimultaneousSounds[sound] ?? 1, forKey: sound) { sound.player() }
  }

  func cachedPlayer(_ sound: SoundEffect) -> AVAudioPlayer {
    return audioPlayerCache.next(forKey: sound)
  }

  func execute(_ soundActions: @escaping () -> Void) {
    soundQueue.async(execute: soundActions)
  }
}

extension Globals {
  static let sounds = Sounds()
}

class SceneAudioInfo {
  weak var player: AVAudioPlayer?
  weak var atNode: SKNode? = nil
  var wasPlayingWhenPaused = false

  init(player: AVAudioPlayer, at node: SKNode? = nil) {
    self.player = player
    self.atNode = node
  }
}

struct PanInfo {
  let player: AVAudioPlayer
  let pan: Float
}

class SceneAudio {
  let stereoEffectsFrame: CGRect
  var sceneAudioInfo = [SceneAudioInfo]()

  init(stereoEffectsFrame: CGRect) {
    self.stereoEffectsFrame = stereoEffectsFrame
  }

  func playerFor(_ sound: SoundEffect, at node: SKNode? = nil) -> AVAudioPlayer {
    let player = sound.player()
    sceneAudioInfo.append(SceneAudioInfo(player: player, at: node))
    return player
  }

  func soundEffect(_ sound: SoundEffect, at position: CGPoint = .zero) {
    let player = Globals.sounds.cachedPlayer(sound)
    let pan = stereoBalance(position)
    Globals.sounds.execute {
      if player.pan != pan {
        player.pan = pan
      }
      player.play()
    }
  }

  func pause() {
    for audioInfo in sceneAudioInfo {
      guard let player = audioInfo.player else { continue }
      audioInfo.wasPlayingWhenPaused = player.isPlaying
      if audioInfo.wasPlayingWhenPaused {
        player.pause()
      }
    }
  }

  func resume() {
    for audioInfo in sceneAudioInfo {
      guard let player = audioInfo.player else { continue }
      if audioInfo.wasPlayingWhenPaused {
        Globals.sounds.execute { player.play() }
      }
    }
  }

  func stop() {
    for audioInfo in sceneAudioInfo {
      guard let player = audioInfo.player else { continue }
      player.stop()
    }
  }

  func stereoBalance(_ position: CGPoint) -> Float {
    guard stereoEffectsFrame.width != 0 else { return 0 }
    guard position.x <= stereoEffectsFrame.maxX else { return 1 }
    guard position.x >= stereoEffectsFrame.minX else { return -1 }
    let ideal = Float((position.x - stereoEffectsFrame.midX) / (0.5 * stereoEffectsFrame.width))
    return round(ideal * 8) / 8
  }

  func update() {
    // We try to avoid setting pan since that seems to be somewhat CPU intensive.  We
    // can leave it alone if either:
    // 1. A player's volume is 0
    // 2. The pan is already set to the right value (which often happens since
    //    stereoBalance rounds to a smallish number of discrete values.
    var panInfo = [PanInfo]()
    for audioInfo in sceneAudioInfo {
      guard let player = audioInfo.player, let node = audioInfo.atNode, player.volume > 0 else { continue }
      let pan = stereoBalance(node.position)
      if pan != player.pan {
        panInfo.append(PanInfo(player: player, pan: pan))
      }
    }
    if !panInfo.isEmpty {
      Globals.sounds.execute {
        for info in panInfo {
          info.player.pan = info.pan
        }
      }
    }
    sceneAudioInfo.removeAll { $0.player == nil }
  }
}
