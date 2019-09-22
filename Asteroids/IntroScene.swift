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
  let introduction = """
  It's tough working in the belt. Whether you're from Luna City, Mars Colony, \
  or good old Terra, out here you're a @looong@ way from home. Cleaning the fields \
  from all the mining debris is a @dangerous@ job; the pay's good for a reason... \
  You're here because you're a hot enough pilot that Central Command suspects \
  you @MIGHT@ survive. At least if those pesky UFOs don't get you... Do you \
  think you've got what it takes to become one of us, the @Rock Rats@?
  """

  func makeAttributed(text: String, thru visibleIndex: String.Index) -> NSAttributedString {
    var highlighted = false
    let result = NSMutableAttributedString(string: "")
    var index = text.startIndex
    while index < text.endIndex {
      if text[index] == "@" {
        highlighted = !highlighted
      } else {
        if index <= visibleIndex {
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
    let introLabel = SKLabelNode(attributedText: makeAttributed(text: introduction, thru: introduction.endIndex))
    // It seems that numberOfLines needs to be set to something just to do the word
    // breaking.  Value doesn't really matter though, and we'll adjust the position
    // of the node to be properly centered in a moment.
    introLabel.numberOfLines = 5
    introLabel.lineBreakMode = .byWordWrapping
    introLabel.preferredMaxLayoutWidth = 900
    introLabel.horizontalAlignmentMode = .center
    introLabel.verticalAlignmentMode = .center
    introLabel.position = CGPoint(x: gameFrame.midX, y: 0)
    intro.addChild(introLabel)
    let goButton = Button(forText: "Find Out", size: CGSize(width: 250, height: 50), fontName: "Kenney Future Narrow")
    goButton.position = CGPoint(x: fullFrame.midX, y: 0)
    goButton.action = { [unowned self] in self.toMenu() }
    intro.addChild(goButton)
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
    goButton.alpha = 0
    goButton.isHidden = true
    wait(for: typeInDelay) {
      self.typeIn(text: self.introduction, at: self.introduction.startIndex, label: introLabel) {
        goButton.run(SKAction.sequence([SKAction.unhide(), SKAction.fadeIn(withDuration: 0.5)]))
      }
    }
  }

  func toMenu() {
    wait(for: 0.25) { self.switchScene(to: Globals.menuScene, withDuration: 3) }
  }

  func typeIn(text: String, at index: String.Index, label: SKLabelNode, whenDone: (() -> Void)?) {
    if index < text.endIndex {
      // This isn't very efficient, but it's safe and easy to understand
      label.attributedText = makeAttributed(text: text, thru: index)
      var delay = typeInDelay
      if index > text.startIndex && text[index] == " " {
        let previousChar = text[text.index(before: index)]
        if previousChar == "." || previousChar == ";" {
          delay = 50 * typeInDelay
        } else if previousChar == "," {
          delay = 25 * typeInDelay
        }
      }
      wait(for: delay) {
        self.typeIn(text: text, at: text.index(after: index), label: label, whenDone: whenDone)
      }
    } else {
      whenDone?()
    }
  }

  override func didMove(to view: SKView) {
    super.didMove(to: view)
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
