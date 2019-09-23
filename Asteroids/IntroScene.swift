//
//  IntroScene.swift
//  Asteroids
//
//  Created by David Long on 9/22/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class IntroScene: BasicScene {
  let typeInDelay = 2.0 / 60
  var textAttributes = [NSAttributedString.Key: Any]()
  var highlightTextAttributes = [NSAttributedString.Key: Any]()
  var hiddenAttributes = [NSAttributedString.Key: Any]()
  let standBy = """
  Incoming transmission...
  Please stand by.
  """
  let messageHeader = """
  From: @Lt Cmdr Ivanova@
    Sector Head
  To: All @new recruits@
  CC: Central Command
  Subject: @Intro Briefing@
  """
  let introduction = """
  It's tough working in the belt. Whether you're from Luna City, Mars Colony, \
  or good old Terra, out here you're a @long way@ from home. Cleaning the fields \
  from mining debris is a @dangerous@ job; the pay's good for a reason... \
  You're here because you're a @hotshot@ pilot, and Central suspects \
  you @MIGHT@ survive. At least if the @UFOs@ don't get you... Do you \
  have what it takes to become one of us, the @Rock Rats@?
  """
  var transmissionSounds: SKAudioNode!
  var incomingLabel: SKLabelNode!
  var introLabel: SKLabelNode!
  var goButton: Button!

  func makeAttributed(text: String, until visibleIndex: String.Index) -> NSAttributedString {
    var highlighted = false
    let result = NSMutableAttributedString(string: "")
    var index = text.startIndex
    while index < text.endIndex {
      if text[index] == "@" {
        highlighted = !highlighted
      } else {
        if index < visibleIndex {
          result.append(NSAttributedString(string: String(text[index]), attributes: highlighted ? highlightTextAttributes : textAttributes))
        } else {
          result.append(NSAttributedString(string: String(text[index]), attributes: hiddenAttributes))
        }
      }
      index = text.index(after: index)
    }
    return result
  }

  func initIntro() {
    let intro = SKNode()
    intro.name = "intro"
    intro.zPosition = LevelZs.info.rawValue
    addChild(intro)
    // It seems that numberOfLines needs to be set to something just to do the word
    // breaking on SKLabelNodes.  The value doesn't really matter though, and we'll
    // adjust the position of the node after computing sizes.
    incomingLabel = SKLabelNode(attributedText: makeAttributed(text: standBy, until: standBy.startIndex))
    incomingLabel.numberOfLines = 5
    incomingLabel.lineBreakMode = .byWordWrapping
    incomingLabel.preferredMaxLayoutWidth = 600
    incomingLabel.horizontalAlignmentMode = .center
    incomingLabel.verticalAlignmentMode = .center
    incomingLabel.position = CGPoint(x: gameFrame.midX, y: 0)
    intro.addChild(incomingLabel)
    //incomingLabel.isHidden = true
    introLabel = SKLabelNode(attributedText: makeAttributed(text: introduction, until: introduction.startIndex))
    introLabel.numberOfLines = 2
    introLabel.lineBreakMode = .byWordWrapping
    introLabel.preferredMaxLayoutWidth = 900
    introLabel.horizontalAlignmentMode = .center
    introLabel.verticalAlignmentMode = .center
    introLabel.position = CGPoint(x: gameFrame.midX, y: 0)
    intro.addChild(introLabel)
    introLabel.isHidden = true
    goButton = Button(forText: "Find Out", size: CGSize(width: 250, height: 50), fontName: "Kenney Future Narrow")
    goButton.position = CGPoint(x: fullFrame.midX, y: 0)
    goButton.action = { [unowned self] in self.toMenu() }
    intro.addChild(goButton)
    goButton.alpha = 0
    goButton.isHidden = true
    // Calculate vertical positions for layout
    let introFrame = introLabel.frame
    let spacerHeight = 1.25 * introLabel.fontSize
    let goFrame = goButton.calculateAccumulatedFrame()
    let totalHeight = introFrame.height + spacerHeight + goFrame.height
    let desiredTopY = gameFrame.maxY - 0.5 * (gameFrame.height - totalHeight)
    let desiredBottomY = gameFrame.minY + 0.5 * (gameFrame.height - totalHeight)
    // Put the top of the intro at desiredTopY
    introLabel.position = introLabel.position + CGVector(dx: 0, dy: desiredTopY - introFrame.maxY)
    print(introLabel.position)
    // Put the bottom of the button at desiredBottomY
    goButton.position = goButton.position + CGVector(dx: 0, dy: desiredBottomY - goFrame.minY)
    transmissionSounds = Globals.sounds.audioNodeFor(.transmission)
    transmissionSounds.autoplayLooped = true
    addChild(transmissionSounds)
    transmissionSounds.run(SKAction.pause())
  }

  func incoming() {
    transmissionSounds.run(SKAction.play())
    typeIn(text: self.standBy, at: self.standBy.startIndex, label: self.incomingLabel) {
      self.wait(for: 3) { self.header() }
    }
  }

  func header() {
    transmissionSounds.run(SKAction.play())
    typeIn(text: self.messageHeader, at: self.messageHeader.startIndex, label: self.incomingLabel) {
      self.wait(for: 5) {
        self.incomingLabel.isHidden = true
        self.intro()
      }
    }
  }

  func intro() {
    introLabel.isHidden = false
    transmissionSounds.run(SKAction.play())
    typeIn(text: self.introduction, at: self.introduction.startIndex, label: self.introLabel) {
      self.goButton.run(SKAction.sequence([SKAction.unhide(), SKAction.fadeIn(withDuration: 0.5)]))
    }
  }

  func toMenu() {
    wait(for: 0.25) { self.switchScene(to: Globals.menuScene, withDuration: 3) }
  }

  func typeIn(text: String, at index: String.Index, label: SKLabelNode, whenDone: (() -> Void)?) {
    if index < text.endIndex {
      // Probably it's not very efficient to regenerate the attributed text
      // constantly, but it's easy to understand and doesn't require too much mucking
      // with NSwhatevs...
      label.attributedText = makeAttributed(text: text, until: index)
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
        transmissionSounds.run(SKAction.pause())
      }
      wait(for: delay) {
        if muteAudio {
          self.transmissionSounds.run(SKAction.play())
        }
        self.typeIn(text: text, at: text.index(after: index), label: label, whenDone: whenDone)
      }
    } else {
      label.attributedText = makeAttributed(text: text, until: index)
      transmissionSounds.run(SKAction.stop())
      whenDone?()
    }
  }

  override func didMove(to view: SKView) {
    super.didMove(to: view)
    wait(for: 1) {
      self.incoming()
    }
    logging("\(name!) finished didMove to view")
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
  }

  required init(size: CGSize) {
    super.init(size: size)
    textAttributes[.font] = UIFont(name: "Kenney Future Narrow", size: 40)
    textAttributes[.foregroundColor] = AppColors.textColor
    highlightTextAttributes = textAttributes
    highlightTextAttributes[.foregroundColor] = AppColors.highlightTextColor
    hiddenAttributes = textAttributes
    hiddenAttributes[.foregroundColor] = UIColor.clear
    name = "introScene"
    initGameArea(limitAspectRatio: false)
    initIntro()
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by IntroScene")
  }
}
