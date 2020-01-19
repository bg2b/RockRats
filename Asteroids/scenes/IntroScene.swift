//
//  IntroScene.swift
//  Asteroids
//
//  Copyright © 2020 Daniel Long and David Long
//
//  License: MIT
//
//  See LICENSE.md in the top-level directory for full terms and discussion.
//

import SpriteKit
import AVFoundation
import os.log

// MARK: Introduction and conclusion

/// The scene for displaying the app's introduction
///
/// This is the first screen shown.  It consists of an "incoming transmission...", a
/// message header, and a message body.  The same scene is used (with different text)
/// for the concluding screen when they're promoted to Lt Commander.
class IntroScene: BasicScene {
  /// `true` if this is the conclusion scene instead of the intro scene
  let conclusion: Bool
  /// Attributes for the text being displayed
  let attributes = AttrStyles(fontName: AppAppearance.font, fontSize: 40)
  /// The initial "standby" part of the message
  let standBy = """
    Incoming transmission...
    Please stand by.
    """
  /// The header of the message
  let messageHeader: String
  /// The body of the message
  let introduction: String
  /// The label that displays the initial "incoming..." and the header
  var incomingLabel: SKLabelNode!
  /// The label that displays the main text (initially hidden)
  var introLabel: SKLabelNode!
  /// The button used to move on to the next scene
  var doneButton: Button!
  /// Some background sounds that are supposed to indicate data transmission
  var transmissionSounds: ContinuousPositionalAudio!

  // MARK: - Initialization

  /// Create the stuff in the introduction scene
  func initIntro() {
    let intro = SKNode()
    intro.name = "intro"
    intro.setZ(.info)
    addChild(intro)
    // Incoming transmission... and message header are narrow
    incomingLabel = SKLabelNode(attributedText: makeAttributed(text: standBy, until: standBy.startIndex, attributes: attributes))
    // 0 means multi-line
    incomingLabel.numberOfLines = 0
    incomingLabel.lineBreakMode = .byWordWrapping
    incomingLabel.preferredMaxLayoutWidth = 600
    incomingLabel.horizontalAlignmentMode = .center
    incomingLabel.verticalAlignmentMode = .center
    incomingLabel.position = CGPoint(x: gameFrame.midX, y: 0)
    intro.addChild(incomingLabel)
    // The main label that shows everything else is wider
    introLabel = SKLabelNode(attributedText: makeAttributed(text: introduction, until: introduction.startIndex, attributes: attributes))
    introLabel.numberOfLines = 0
    introLabel.lineBreakMode = .byWordWrapping
    introLabel.preferredMaxLayoutWidth = 900
    introLabel.horizontalAlignmentMode = .center
    introLabel.verticalAlignmentMode = .center
    introLabel.position = CGPoint(x: gameFrame.midX, y: 0)
    intro.addChild(introLabel)
    introLabel.isHidden = true
    // The button that ends the scene
    doneButton = Button(forText: (!conclusion ? "Find Out" : "Acknowledge"), fontSize: 50, size: CGSize(width: 100, height: 50))
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
    introLabel.position += CGVector(dx: 0, dy: desiredTopY - introFrame.maxY)
    // Put the bottom of the button at desiredBottomY
    doneButton.position += CGVector(dx: 0, dy: desiredBottomY - goFrame.minY)
    // Sounds that get modulated by the type-in effect of the labels
    transmissionSounds = audio.continuousAudio(.transmission, at: self)
    transmissionSounds.playerNode.volume = 0
    transmissionSounds.playerNode.play()
  }

  /// Create an intro or conclusion scene
  /// - Parameters:
  ///   - size: The size of the scene
  ///   - conclusion: `true` for the conclusion, `false` for the introduction
  init(size: CGSize, conclusion: Bool) {
    os_log("IntroScene init", log: .app, type: .debug)
    self.conclusion = conclusion
    if !conclusion {
      // They're a new recruit...
      messageHeader = """
      From: @Lt Cmdr Ivanova@
        Sector Head
      To: All @new recruits@
      CC: Central Command
      Subject: @Intro Briefing@
      """
      introduction = """
      It's tough working in @the belt@. Whether you're from Luna City, Mars Colony, \
      or good old Terra, out here you're a @long way@ from home. Cleaning the fields \
      from mining debris is a @dangerous@ job; the pay's good for a reason... \
      You're here because you're a @hotshot@ pilot, and Central suspects \
      you @MIGHT@ survive. At least if the pesky @UFOs@ don't get you... Do you \
      have what it takes to become one of us, the @Rock Rats@?
      """
    } else {
      // They got promoted...
      let playerName = Globals.gcInterface.playerName
      messageHeader = """
      From: @Cmdr Ivanova@
        Outgoing Sector Head
      To: @Lt Cmdr \(playerName)@
        Incoming Sector Head
      Subject: @Promotion@
      """
      introduction = """
      @Congratulations@ on your promotion to @Lt Commander@! I remember the day you \
      joined as a new recruit, still wet behind the ears, but confident that you \
      could make it as a @Rock Rat@. That confidence was justified, and then some. \
      Now you face a @new challenge@, training the next generation of superstar \
      pilots. You're probably @nervous@ - I was when I got the job - but I'm sure \
      you'll make it look easy. Best wishes Lt Commander, and keep the @Rock Rat@ \
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

  deinit {
    os_log("IntroScene deinit %{public}s", log: .app, type: .debug, "\(self.hash)")
  }

  // MARK: - Message display

  /// Displays "Incoming transmission..."
  func incoming() {
    incomingLabel.typeIn(text: standBy, attributes: attributes, sound: transmissionSounds) {
      self.wait(for: 3, then: self.header)
    }
  }

  /// Displays the message header
  func header() {
    incomingLabel.typeIn(text: messageHeader, attributes: attributes, sound: transmissionSounds) {
      self.wait(for: 5) {
        self.incomingLabel.isHidden = true
        self.intro()
      }
    }
  }

  /// Displays the main part of the message
  func intro() {
    introLabel.isHidden = false
    introLabel.typeIn(text: introduction, attributes: attributes, sound: transmissionSounds) {
      self.doneButton.run(.sequence([.unhide(), .fadeIn(withDuration: 0.5)]))
    }
  }

  /// Kick off the introduction
  /// - Parameter view: The view that will display the scene
  override func didMove(to view: SKView) {
    super.didMove(to: view)
    wait(for: 1, then: incoming)
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    endOfUpdate()
  }

  // MARK: - End of scene

  /// Handles clicks of the done button
  func done() {
    guard beginSceneSwitch() else { fatalError("Done button in IntroScene found scene switch already in progress???") }
    let getNextScene: () -> BasicScene
    if UserData.hasDoneIntro.value {
      // They're just replaying the intro (or conclusion) from the settings
      if conclusion {
        getNextScene = { CreditsScene(size: self.fullFrame.size) }
      } else {
        getNextScene = { Globals.menuScene }
      }
    } else {
      // First time the game has launched, take them through the tutorial
      getNextScene = { TutorialScene(size: self.fullFrame.size) }
    }
    UserData.hasDoneIntro.value = true
    switchWhenQuiescent(getNextScene)
  }
}
