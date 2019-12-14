//
//  Sounds.swift
//  Asteroids
//
//  Created by David Long on 8/17/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import AVFoundation

/// A sound effect (who'd have guessed?)
///
/// The raw values are the (base) file names associated with the effects, e.g.,
/// `playerShot` corresponds to the file "player_laser.wav"
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
  case firework1 = "firework1"
  case firework2 = "firework2"
  case firework3 = "firework3"
  case firework4 = "firework4"

  /// The URL for a sound effect file in the main bundle
  var url: URL {
    guard let url = Bundle.main.url(forResource: self.rawValue, withExtension: "wav") else {
      fatalError("Sound effect file \(self.rawValue) missing")
    }
    return url
  }

  /// Read the sound effect audio into a PCM buffer
  /// - Returns: A new buffer containing the audio data
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

/// A collection of all the sound effects used by the app
class Sounds {
  /// A dictionary mapping sound effects to audio buffers
  var audioBuffers = [SoundEffect: AVAudioPCMBuffer]()

  /// Preload all the sound effects into buffers
  init() {
    for effect in SoundEffect.allCases {
      audioBuffers[effect] = effect.audioBuffer()
    }
  }

  /// Get the buffer holding the sound effect's audio data
  /// - Parameter sound: The sound effect
  /// - Returns: A PCM buffer with the data
  func cachedAudioBuffer(_ sound: SoundEffect) -> AVAudioPCMBuffer {
    guard let buffer = audioBuffers[sound] else {
      fatalError("Audio buffer for \(sound.rawValue) was not preloaded")
    }
    return buffer
  }

  /// Display some debugging info
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
  /// All of the game's sound data
  static let sounds = Sounds()
}

/// An audio sound effect that is playing continuously and whose apparent position
/// should be moved around to follow an `SKNode`
struct ContinuousPositionalAudio {
  /// The player that's playing the effect
  let playerNode: AVAudioPlayerNode
  /// The sprite node whose position is being tracked.  This has to be `weak` since
  /// the node itself may hold on to a `ContinuousPositionalAudio` and that would
  /// otherwise create a retain cycle.
  weak var atNode: SKNode?
}

// MARK: -

/// An organizer for the audio of a scene
class SceneAudio {
  /// Positional effects adjust based on their node's position relative to this frame
  let stereoEffectsFrame: CGRect
  /// The scene's audio engine
  let audioEngine: AVAudioEngine
  /// Audio player nodes for playing sound effects
  var playerNodes = [AVAudioPlayerNode]()
  /// Index of the player node that should be used for the next sound effect
  var nextPlayerNode = 0
  /// An array of the positional effects that are following `SKNode`s around
  var sceneContinuousPositional = [ContinuousPositionalAudio]()

  // MARK: - Initialization

  /// Make a scene's audio organizer
  /// - Parameters:
  ///   - stereoEffectsFrame: Positional effects are based on node position relative to this frame
  ///   - audioEngine: The scene's audio engine
  init(stereoEffectsFrame: CGRect, audioEngine: AVAudioEngine) {
    self.stereoEffectsFrame = stereoEffectsFrame
    self.audioEngine = audioEngine
    // Warm up the audio engine and connect up the audio processing
    do {
      try audioEngine.start()
      // Grab a random buffer just to have the right `format` for connections
      let buffer = Globals.sounds.cachedAudioBuffer(.playerExplosion)
      // I got up to about 10 simultaneous sounds when really pushing the game
      for _ in 0 ..< 10 {
        let playerNode = AVAudioPlayerNode()
        playerNodes.append(playerNode)
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: buffer.format)
        // The player nodes are always running; to play an effect, just schedule a
        // buffer for the next one
        playerNode.play()
      }
      // Set the muted state based on the user's preference
      level = UserData.audioLevel.value
    } catch {
      logging("Cannot start audio engine, \(error.localizedDescription)")
    }
  }

  // MARK: - Audio control

  /// The audio level, 0 (off) - 3 (full)
  var level: Int {
    get { Int(audioEngine.mainMixerNode.outputVolume * 3) }
    set { audioEngine.mainMixerNode.outputVolume = Float(newValue) / 3 }
  }

  /// Pause all sounds
  func pause() {
    audioEngine.pause()
  }

  /// Resume playing all sounds
  func resume() {
    do {
      try audioEngine.start()
    } catch {
      logging("Unable to resume audio engine, \(error.localizedDescription)")
    }
  }

  /// Stop the audio (typically only done when the scene is being forced to quit in
  /// the middle)
  func stop() {
    audioEngine.stop()
  }

  /// Update positional audio
  ///
  /// This should be called from the scene's main `update` loop
  func update() {
    for continuous in sceneContinuousPositional {
      if let node = continuous.atNode {
        // The node still exists
        guard continuous.playerNode.volume > 0 else { continue }
        continuous.playerNode.pan = stereoBalance(node.position)
      } else {
        // The sprite node has been garbage collected; stop the player node and
        // remove it from the audio engine
        continuous.playerNode.stop()
        audioEngine.detach(continuous.playerNode)
      }
    }
    sceneContinuousPositional.removeAll { $0.atNode == nil }
  }

  // MARK: - Playing

  /// Play a sound effect
  /// - Parameters:
  ///   - sound: The sound effect to play
  ///   - position: Where the sound should appear to be (default center of the scene)
  func soundEffect(_ sound: SoundEffect, at position: CGPoint = .zero) {
    // Don't bother doing anything if the audio didn't initialize correctly or if the
    // scene is muted
    guard audioEngine.isRunning, level > 0 else { return }
    // Grab the buffer for the effect and schedule it on the next player
    let buffer = Globals.sounds.cachedAudioBuffer(sound)
    let playerNode = playerNodes[nextPlayerNode]
    nextPlayerNode = (nextPlayerNode + 1) % playerNodes.count
    playerNode.pan = stereoBalance(position)
    playerNode.scheduleBuffer(buffer)
  }

  /// Compute the stereo `pan` for a position
  /// - Parameter position: The position within `stereoEffectsFrame`
  /// - Returns: -1 for full left, +1 for full right
  func stereoBalance(_ position: CGPoint) -> Float {
    guard stereoEffectsFrame.width != 0 else { return 0 }
    guard position.x <= stereoEffectsFrame.maxX else { return 1 }
    guard position.x >= stereoEffectsFrame.minX else { return -1 }
    return Float((position.x - stereoEffectsFrame.midX) / (0.5 * stereoEffectsFrame.width))
  }

  /// Create a positional effect that repeats and seems to follow a node
  ///
  /// The `playerNode`'s `pan` will be set and tracked automatically.  Other
  /// properties like the volume are the responsibility of the caller.  The caller
  /// must also call `playerNode.play()` to start the audio.
  ///
  /// - Parameters:
  ///   - sound: The sound effect to play continously
  ///   - node: The node whose position should be tracked
  /// - Returns: The continuous positional audio information
  func continuousAudio(_ sound: SoundEffect, at node: SKNode) -> ContinuousPositionalAudio {
    // Make a new player node and connect it to the mixer
    let buffer = Globals.sounds.cachedAudioBuffer(sound)
    let playerNode = AVAudioPlayerNode()
    audioEngine.attach(playerNode)
    audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: buffer.format)
    // Set the starting pan based on the node's position
    playerNode.pan = stereoBalance(node.position)
    // Schedule the sound to repeatedly
    playerNode.scheduleBuffer(buffer, at: nil, options: [.loops])
    let result = ContinuousPositionalAudio(playerNode: playerNode, atNode: node)
    sceneContinuousPositional.append(result)
    return result
  }
}
