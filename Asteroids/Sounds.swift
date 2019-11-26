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
  case heartbeatHigh = "heartbeat1"
  case heartbeatLow = "heartbeat2"
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

  init() {
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

struct ContinuousPositionalAudio {
  let playerNode: AVAudioPlayerNode
  weak var atNode: SKNode?
}

class SceneAudio {
  let stereoEffectsFrame: CGRect
  let audioEngine: AVAudioEngine
  var playerNodes = [AVAudioPlayerNode]()
  var nextPlayerNode = 0
  var sceneContinuousPositional = [ContinuousPositionalAudio]()

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
      muted = UserData.audioIsMuted.value
    } catch {
      logging("Cannot start audio engine, \(error.localizedDescription)")
    }
  }

  var muted: Bool {
    get { audioEngine.mainMixerNode.outputVolume == 0 }
    set { audioEngine.mainMixerNode.outputVolume = (newValue ? 0 : 1) }
  }

  func soundEffect(_ sound: SoundEffect, at position: CGPoint = .zero) {
    guard audioEngine.isRunning, !muted else { return }
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

  func continuousAudio(_ sound: SoundEffect, at node: SKNode) -> ContinuousPositionalAudio {
    let buffer = Globals.sounds.cachedAudioBuffer(sound)
    let playerNode = AVAudioPlayerNode()
    audioEngine.attach(playerNode)
    audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: buffer.format)
    playerNode.pan = stereoBalance(node.position)
    playerNode.scheduleBuffer(buffer, at: nil, options: [.loops])
    let result = ContinuousPositionalAudio(playerNode: playerNode, atNode: node)
    sceneContinuousPositional.append(result)
    return result
  }

  func pause() {
    audioEngine.pause()
  }

  func resume() {
    do {
      try audioEngine.start()
    } catch {
      logging("Unable to resume audio engine, \(error.localizedDescription)")
    }
  }

  func stop() {
    audioEngine.stop()
  }

  func update() {
    for continuous in sceneContinuousPositional {
      if let node = continuous.atNode {
        guard continuous.playerNode.volume > 0 else { continue }
        continuous.playerNode.pan = stereoBalance(node.position)
      } else {
        continuous.playerNode.stop()
        audioEngine.detach(continuous.playerNode)
      }
    }
    sceneContinuousPositional.removeAll { $0.atNode == nil }
  }
}
