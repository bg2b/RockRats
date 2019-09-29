//
//  AttrString.swift
//  Asteroids
//
//  Created by David Long on 9/23/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import AVFoundation

struct AttrStyles {
  let textAttributes: [NSAttributedString.Key: Any]
  let highlightTextAttributes: [NSAttributedString.Key: Any]
  let hiddenAttributes: [NSAttributedString.Key: Any]

  init(fontName: String, fontSize: CGFloat) {
    var attributes = [NSAttributedString.Key: Any]()
    attributes[.font] = UIFont(name: fontName, size: fontSize)
    attributes[.foregroundColor] = AppColors.textColor
    self.textAttributes = attributes
    attributes[.foregroundColor] = AppColors.highlightTextColor
    self.highlightTextAttributes = attributes
    attributes[.foregroundColor] = UIColor.clear
    self.hiddenAttributes = attributes
  }
}

func makeAttributed(text: String, until invisibleIndex: String.Index, attributes: AttrStyles) -> NSAttributedString {
  var highlighted = false
  let result = NSMutableAttributedString(string: "")
  var index = text.startIndex
  while index < text.endIndex {
    if text[index] == "@" {
      highlighted = !highlighted
    } else {
      if index < invisibleIndex {
        if highlighted {
          result.append(NSAttributedString(string: String(text[index]), attributes: attributes.highlightTextAttributes))
        } else {
          result.append(NSAttributedString(string: String(text[index]), attributes: attributes.textAttributes))
        }
      } else {
        result.append(NSAttributedString(string: String(text[index]), attributes: attributes.hiddenAttributes))
      }
    }
    index = text.index(after: index)
  }
  return result
}

extension SKLabelNode {
  // This method reveals the (formatted) text in a label node while playing some sound.
  // It's supposed to give an incoming-transmission type of effect.
  func typeIn(text: String, at index: String.Index, attributes: AttrStyles,
              sounds: AVAudioPlayer, delay: Double, whenDone: (() -> Void)?) {
    if index == text.startIndex {
      sounds.play()
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
        } else if previousChar == "," {
          duration *= 10
          muteAudio = true
        }
      } else if text[index] == "\n" {
        duration *= 50
        muteAudio = true
      }
      if muteAudio {
        sounds.pause()
      }
      wait(for: duration) {
        if muteAudio {
          sounds.play()
        }
        self.typeIn(text: text, at: text.index(after: index), attributes: attributes,
                    sounds: sounds, delay: delay, whenDone: whenDone)
      }
    } else {
      attributedText = makeAttributed(text: text, until: index, attributes: attributes)
      sounds.stop()
      whenDone?()
    }
  }

  func typeIn(text: String, attributes: AttrStyles, whenDone: (() -> Void)?) {
    let sounds = Globals.sounds.audioPlayerFor(.transmission)
    sounds.numberOfLoops = -1
    sounds.volume = 0
    sounds.play()
    let delay = 2.0 / 60
    // This is incredibly ugly, but for some reason if I don't kick the audio by
    // trying to play it and then waiting a bit and stopping, the first instance of
    // using typeIn will stutter.  After the fist call everything would work without
    // this hackery, though it doesn't hurt.  But that's just because audioPlayerFor
    // is returning the same (cached) player for every new call.  I can reproduce the
    // problem on every call if I get a completely new audio player each time;
    // instead of calling audioPlayerFor, just use SoundEffect.transmission.player().
    // So presumably it's something I don't understand about the AVAudioPlayer
    // itself.  It somehow gets created in a state that makes it not start playing
    // cleanly until after I call stop() on it.  After that, it's fine on play().  I
    // tried dumping the prepareToPlay() in the creation, but that didn't help.
    wait(for: 3 * delay) {
      sounds.stop()
      sounds.volume = 1
      self.typeIn(text: text, at: text.startIndex, attributes: attributes, sounds: sounds, delay: delay, whenDone: whenDone)
    }
  }
}
