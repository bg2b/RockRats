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

  func audioBuffer() -> AVAudioPCMBuffer {
    guard let file = try? AVAudioFile(forReading: self.url) else {
      fatalError("Unable to instantiate AVAudioFile")
    }
    guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
      fatalError("Unable to instantiate AVAudioPCMBuffer")
    }
    do {
      try file.read(into: buffer)
    } catch {
      fatalError("Unable to read audio file into buffer, \(error.localizedDescription)")
    }
    return buffer
  }
}

class Sounds {
  var audioBuffers = [SoundEffect: AVAudioPCMBuffer]()
  var gameAudio = [SceneAudioInfo]()
  let soundQueue: DispatchQueue

  init() {
    soundQueue = DispatchQueue.global(qos: .background)
    for effect in SoundEffect.allCases {
      preload(effect)
    }
  }

  func preload(_ sound: SoundEffect) {
    audioBuffers[sound] = sound.audioBuffer()
  }

  func cachedAudioBuffer(_ sound: SoundEffect) -> AVAudioPCMBuffer {
    guard let buffer = audioBuffers[sound] else {
      fatalError("Audio buffer for \(sound.rawValue) was not preloaded")
    }
    return buffer
  }

  func execute(_ soundActions: @escaping () -> Void) {
    soundQueue.async(execute: soundActions)
  }

  func stats() {
    var bytes = UInt32(0)
    for (_, buffer) in audioBuffers {
      if buffer.floatChannelData != nil {
        bytes += buffer.frameCapacity * 4
      }
      if buffer.int16ChannelData != nil {
        bytes += buffer.frameCapacity * 2
      }
      if buffer.int32ChannelData != nil {
        bytes += buffer.frameCapacity * 4
      }
    }
    bytes /= 1024
    logging("Sound data \(bytes) KB for \(audioBuffers.count) sounds")
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

class SceneAudioNodeInfo {
  weak var playerNode: AVAudioPlayerNode?
  weak var atNode: SKNode? = nil

  init(playerNode: AVAudioPlayerNode, at node: SKNode? = nil) {
    self.playerNode = playerNode
    self.atNode = node
  }
}

struct PanInfo {
  let player: AVAudioPlayer
  let pan: Float
}

class SceneAudio {
  let stereoEffectsFrame: CGRect
  let audioEngine: AVAudioEngine
  var playerNodes = [AVAudioPlayerNode]()
  var nextPlayerNode = 0
  var sceneAudioInfo = [SceneAudioInfo]()
  var sceneAudioNodeInfo = [SceneAudioNodeInfo]()

  init(stereoEffectsFrame: CGRect, audioEngine: AVAudioEngine) {
    self.stereoEffectsFrame = stereoEffectsFrame
    self.audioEngine = audioEngine
    do {
      try audioEngine.start()
      let buffer = Globals.sounds.cachedAudioBuffer(.playerExplosion)
      // We got up to about 10 simultaneous sounds when really pushing the game
      for _ in 0 ..< 10 {
        let playerNode = AVAudioPlayerNode()
        playerNodes.append(playerNode)
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: buffer.format)
        playerNode.play()
      }
    } catch {
      logging("Cannot start audio engine, \(error.localizedDescription)")
    }
  }

  func soundEffect(_ sound: SoundEffect, at position: CGPoint = .zero) {
    guard audioEngine.isRunning else { return }
    let buffer = Globals.sounds.cachedAudioBuffer(sound)
    let playerNode = playerNodes[nextPlayerNode]
    nextPlayerNode = (nextPlayerNode + 1) % playerNodes.count
    let pan = stereoBalance(position)
    playerNode.pan = pan
    playerNode.scheduleBuffer(buffer)
  }

  func stereoBalance(_ position: CGPoint) -> Float {
    guard stereoEffectsFrame.width != 0 else { return 0 }
    guard position.x <= stereoEffectsFrame.maxX else { return 1 }
    guard position.x >= stereoEffectsFrame.minX else { return -1 }
    return Float((position.x - stereoEffectsFrame.midX) / (0.5 * stereoEffectsFrame.width))
  }

  func playerFor(_ sound: SoundEffect, at node: SKNode? = nil) -> AVAudioPlayer {
    let player = sound.player()
    sceneAudioInfo.append(SceneAudioInfo(player: player, at: node))
    return player
  }

  func pause() {
    for audioInfo in sceneAudioInfo {
      guard let player = audioInfo.player else { continue }
      audioInfo.wasPlayingWhenPaused = player.isPlaying
      if audioInfo.wasPlayingWhenPaused {
        player.pause()
      }
    }
    audioEngine.pause()
  }

  func resume() {
    for audioInfo in sceneAudioInfo {
      guard let player = audioInfo.player else { continue }
      if audioInfo.wasPlayingWhenPaused {
        Globals.sounds.execute { player.play() }
      }
    }
    do {
      try audioEngine.start()
    } catch {
      logging("Unable to resume audio engine, \(error.localizedDescription)")
    }
  }

  func stop() {
    for audioInfo in sceneAudioInfo {
      guard let player = audioInfo.player else { continue }
      player.stop()
    }
    audioEngine.stop()
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
      if abs(pan - player.pan) > 0.125 {
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
