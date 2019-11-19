//
//  IntroScene.swift
//  Asteroids
//
//  Created by David Long on 9/22/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit
import AVFoundation

class IntroScene: BasicScene {
  let conclusion: Bool
  let attributes = AttrStyles(fontName: AppColors.font, fontSize: 40)
  let standBy = """
  Incoming transmission...
  Please stand by.
  """
  let messageHeader: String
  let introduction: String
  var incomingLabel: SKLabelNode!
  var introLabel: SKLabelNode!
  var doneButton: Button!
  var transmissionSounds: ContinuousPositionalAudio!

  func initIntro() {
    let intro = SKNode()
    intro.name = "intro"
    intro.setZ(.info)
    addChild(intro)
    // It seems that numberOfLines needs to be set to something just to do the word
    // breaking on SKLabelNodes.  The value doesn't really matter though, and we'll
    // adjust the position of the node after computing sizes.
    incomingLabel = SKLabelNode(attributedText: makeAttributed(text: standBy, until: standBy.startIndex, attributes: attributes))
    incomingLabel.numberOfLines = 5
    incomingLabel.lineBreakMode = .byWordWrapping
    incomingLabel.preferredMaxLayoutWidth = 600
    incomingLabel.horizontalAlignmentMode = .center
    incomingLabel.verticalAlignmentMode = .center
    incomingLabel.position = CGPoint(x: gameFrame.midX, y: 0)
    intro.addChild(incomingLabel)
    //incomingLabel.isHidden = true
    introLabel = SKLabelNode(attributedText: makeAttributed(text: introduction, until: introduction.startIndex, attributes: attributes))
    introLabel.numberOfLines = 2
    introLabel.lineBreakMode = .byWordWrapping
    introLabel.preferredMaxLayoutWidth = 900
    introLabel.horizontalAlignmentMode = .center
    introLabel.verticalAlignmentMode = .center
    introLabel.position = CGPoint(x: gameFrame.midX, y: 0)
    intro.addChild(introLabel)
    introLabel.isHidden = true
    doneButton = Button(forText: (!conclusion ? "Find Out" : "Acknowledge"), fontSize: 50, size: CGSize(width: 350, height: 50))
    doneButton.position = CGPoint(x: fullFrame.midX, y: 0)
    doneButton.action = { [unowned self] in self.done() }
    intro.addChild(doneButton)
    doneButton.alpha = 0
    doneButton.isHidden = true
    // Calculate vertical positions for layout
    let introFrame = introLabel.frame
    let spacerHeight = 1.25 * introLabel.fontSize
    let goFrame = doneButton.calculateAccumulatedFrame()
    let totalHeight = introFrame.height + spacerHeight + goFrame.height
    let desiredTopY = gameFrame.maxY - 0.5 * (gameFrame.height - totalHeight)
    let desiredBottomY = gameFrame.minY + 0.5 * (gameFrame.height - totalHeight)
    // Put the top of the intro at desiredTopY
    introLabel.position = introLabel.position + CGVector(dx: 0, dy: desiredTopY - introFrame.maxY)
    // Put the bottom of the button at desiredBottomY
    doneButton.position = doneButton.position + CGVector(dx: 0, dy: desiredBottomY - goFrame.minY)
    transmissionSounds = audio.continuousAudio(.transmission, at: self)
    transmissionSounds.playerNode.volume = 0
    transmissionSounds.playerNode.play()
  }

  func incoming() {
    incomingLabel.typeIn(text: standBy, attributes: attributes, sounds: transmissionSounds) {
      self.wait(for: 3) { self.header() }
    }
  }

  func header() {
    incomingLabel.typeIn(text: messageHeader, attributes: attributes, sounds: transmissionSounds) {
      self.wait(for: 5) {
        self.incomingLabel.isHidden = true
        self.intro()
      }
    }
  }

  func intro() {
    introLabel.isHidden = false
    introLabel.typeIn(text: introduction, attributes: attributes, sounds: transmissionSounds) {
      self.doneButton.run(SKAction.sequence([SKAction.unhide(), SKAction.fadeIn(withDuration: 0.5)]))
    }
  }

  func done() {
    if userDefaults.hasDoneIntro.value {
      if conclusion {
        makeSceneInBackground { CreditsScene(size: self.fullFrame.size) }
      } else {
        nextScene = Globals.menuScene
      }
    } else {
      makeSceneInBackground { TutorialScene(size: self.fullFrame.size) }
    }
    userDefaults.hasDoneIntro.value = true
    switchWhenReady()
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

  init(size: CGSize, conclusion: Bool) {
    self.conclusion = conclusion
    if !conclusion {
      messageHeader = """
      From: @Lt Cmdr Ivanova@
        Sector Head
      To: All @new recruits@
      CC: Central Command
      Subject: @Intro Briefing@
      """
      introduction = """
      It's tough working in the belt. Whether you're from Luna City, Mars Colony, \
      or good old Terra, out here you're a @long way@ from home. Cleaning the fields \
      from mining debris is a @dangerous@ job; the pay's good for a reason... \
      You're here because you're a @hotshot@ pilot, and Central suspects \
      you @MIGHT@ survive. At least if the pesky @UFOs@ don't get you... Do you \
      have what it takes to become one of us, the @Rock Rats@?
      """
    } else {
      let playerID = userDefaults.currentPlayerID.value
      let playerName = userDefaults.playerNames.value[playerID] ?? "Anonymous"
      messageHeader = """
      From: @Cmdr Ivanova@
        Outgoing Sector Head
      To: @Lt Cmdr \(playerName)@
        Incoming Sector Head
      Subject: @Promotion!@
      """
      introduction = """
      @Congratulations on your promotion@ to Lt Cmdr! I remember the day you \
      joined as a new recruit, still wet behind the ears, but confident that you \
      could make it as a @Rock Rat@. That confidence was justified, and then some. \
      Now you face a @new challenge@, training the next generation of superstar \
      pilots. You're probably nervous (I was when I got the job), but I'm sure \
      you'll make it look easy. Best wishes commander, and keep the @Rock Rat@ \
      spirit strong!
      """
    }
    super.init(size: size)
    name = "introScene"
    initGameArea(avoidSafeArea: false)
    initIntro()
  }

  required init(coder aDecoder: NSCoder) {
    conclusion = false
    messageHeader = ""
    introduction = ""
    super.init(coder: aDecoder)
  }
}
