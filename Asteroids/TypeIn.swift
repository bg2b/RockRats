//
//  AttrString.swift
//  Asteroids
//
//  Created by David Long on 9/23/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import AVFoundation

extension SKLabelNode {
  /// Helper routine for `typeIn(text:attributes:sound:whenDone:)`
  /// - Parameters:
  ///   - text: The text to show
  ///   - index: Start the effect from this position (pass `startIndex` initially)
  ///   - attributes: Attributes for formatting the text
  ///   - sound: The sound to play while the effect is running
  ///   - delay: Time between characters
  ///   - whenDone: A closure to run when the effect finishes
  func typeIn(text: String, at index: String.Index, attributes: AttrStyles,
              sound: ContinuousPositionalAudio, delay: Double, whenDone: (() -> Void)?) {
    if index == text.startIndex {
      sound.playerNode.volume = 1
    }
    if index < text.endIndex {
      // Probably it's not very efficient to regenerate the attributed text
      // constantly, but it's easy to understand and doesn't require too much mucking
      // with NSwhatevs...
      attributedText = makeAttributed(text: text, until: index, attributes: attributes)
      var duration = delay
      var muteAudio = false
      if index > text.startIndex && text[index] == " " {
        let previousChar = text[text.index(before: index)]
        if previousChar == "." || previousChar == ";" || previousChar == "!" || previousChar == "?" {
          duration *= 50
          muteAudio = true
        } else if previousChar == "," || previousChar == "-" {
          duration *= 10
          muteAudio = true
        }
      } else if text[index] == "\n" {
        duration *= 50
        muteAudio = true
      }
      if muteAudio {
        sound.playerNode.volume = 0
      }
      wait(for: duration) {
        if muteAudio {
          sound.playerNode.volume = 1
        }
        self.typeIn(text: text, at: text.index(after: index), attributes: attributes,
                    sound: sound, delay: delay, whenDone: whenDone)
      }
    } else {
      attributedText = makeAttributed(text: text, until: index, attributes: attributes)
      sound.playerNode.volume = 0
      whenDone?()
    }
  }

  /// Reveal some formatted text in a label node while playing a sound.  This is
  /// intended to give an incoming-transmission type of effect.
  /// - Parameters:
  ///   - text: The text to show
  ///   - attributes: Attributes for formatting the text
  ///   - sound: A sound to play while the effect is running
  ///   - whenDone: A closure to run when the effect finishes
  func typeIn(text: String, attributes: AttrStyles, sound: ContinuousPositionalAudio, whenDone: (() -> Void)?) {
    let delay = 2.0 / 60
    typeIn(text: text, at: text.startIndex, attributes: attributes, sound: sound, delay: delay, whenDone: whenDone)
  }
}
