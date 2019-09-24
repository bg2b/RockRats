//
//  AttrString.swift
//  Asteroids
//
//  Created by David Long on 9/23/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

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
              sounds: SKAudioNode, typeInDelay: Double, whenDone: (() -> Void)?) {
    if index == text.startIndex {
      sounds.run(SKAction.play())
    }
    if index < text.endIndex {
      // Probably it's not very efficient to regenerate the attributed text
      // constantly, but it's easy to understand and doesn't require too much mucking
      // with NSwhatevs...
      attributedText = makeAttributed(text: text, until: index, attributes: attributes)
      var delay = typeInDelay
      var muteAudio = false
      if index > text.startIndex && text[index] == " " {
        let previousChar = text[text.index(before: index)]
        if previousChar == "." || previousChar == ";" {
          delay = 50 * typeInDelay
          muteAudio = true
        } else if previousChar == "," {
          delay = 10 * typeInDelay
          muteAudio = true
        }
      } else if text[index] == "\n" {
        delay = 50 * typeInDelay
        muteAudio = true
      }
      if muteAudio {
        sounds.run(SKAction.pause())
      }
      wait(for: delay) {
        if muteAudio {
          sounds.run(SKAction.play())
        }
        self.typeIn(text: text, at: text.index(after: index), attributes: attributes,
                    sounds: sounds, typeInDelay: typeInDelay, whenDone: whenDone)
      }
    } else {
      attributedText = makeAttributed(text: text, until: index, attributes: attributes)
      sounds.run(SKAction.stop())
      whenDone?()
    }
  }
}
