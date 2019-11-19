//
//  TutorialScene.swift
//  Asteroids
//
//  Created by David Long on 9/24/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

class TutorialScene: GameTutorialScene {
  var instructionsLabel: SKLabelNode!
  var transmissionSounds: ContinuousPositionalAudio!
  var moveOnButton: Button? = nil
  let attributes = AttrStyles(fontName: AppColors.font, fontSize: 40)
  var maxThrust = CGFloat(0)
  var minThrust = CGFloat(0)
  var maxRotate = CGFloat(0)
  var observedMaxThrust = CGFloat(0)
  var observedMinThrust = CGFloat(0)
  var observedMinRotate = CGFloat(0)
  var observedMaxRotate = CGFloat(0)
  var observedLasersFired = 0
  var shootingEnabled = false
  var hyperspaceEnabled = false
  var deathCount = 0
  var hasJumped = false

  func initInstructions() {
    instructionsLabel = SKLabelNode(text: "")
    instructionsLabel.numberOfLines = 5
    instructionsLabel.lineBreakMode = .byWordWrapping
    instructionsLabel.setZ(.info)
    addChild(instructionsLabel)
    transmissionSounds = audio.continuousAudio(.transmission, at: self)
    transmissionSounds.playerNode.volume = 0
    transmissionSounds.playerNode.play()
  }

  func instructionGeometry(text: String, maxWidth: CGFloat, wantedHeight: CGFloat, horizontal: SKLabelHorizontalAlignmentMode, vertical: SKLabelVerticalAlignmentMode, position: CGPoint) {
    var width = maxWidth
    let attrText = makeAttributed(text: text, until: text.endIndex, attributes: attributes)
    let reset = ""
    let resetText = makeAttributed(text: reset, until: reset.endIndex, attributes: attributes)
    instructionsLabel.preferredMaxLayoutWidth = width
    instructionsLabel.attributedText = attrText
    let targetHeight = max(wantedHeight, instructionsLabel.frame.height + 1)
    while instructionsLabel.frame.height <= targetHeight {
      width -= 25
      instructionsLabel.preferredMaxLayoutWidth = width
      // It's necessary to muck in a nontrivial way with the text in order to get the
      // label to recalculate its size.
      instructionsLabel.attributedText = resetText
      instructionsLabel.attributedText = attrText
    }
    while width + 25 <= maxWidth && instructionsLabel.frame.height > targetHeight {
      width += 25
      instructionsLabel.preferredMaxLayoutWidth = width
      instructionsLabel.attributedText = resetText
      instructionsLabel.attributedText = attrText
    }
    print("final height \(instructionsLabel.frame.height) at width \(width)")
    instructionsLabel.horizontalAlignmentMode = horizontal
    instructionsLabel.verticalAlignmentMode = vertical
    instructionsLabel.position = position
  }

  func clampedJoystick() -> CGVector {
    let thrustDirection = CGVector(dx: 1, dy: 0)
    let rotateDirection = CGVector(dx: 0, dy: 1)
    let thrustAmount = max(min(joystickDirection.dotProd(thrustDirection), maxThrust), minThrust)
    let rotateAmount = max(min(joystickDirection.dotProd(rotateDirection), maxRotate), -maxRotate)
    observedMaxThrust = max(observedMaxThrust, thrustAmount)
    observedMinThrust = min(observedMinThrust, thrustAmount)
    observedMaxRotate = max(observedMaxRotate, rotateAmount)
    observedMinRotate = min(observedMinRotate, rotateAmount)
    return thrustDirection.scale(by: thrustAmount) + rotateDirection.scale(by: rotateAmount)
  }

  override func hyperspaceJump() {
    if hyperspaceEnabled {
      hasJumped = true
      super.hyperspaceJump()
    }
  }

  override func fireLaser() {
    if shootingEnabled {
      super.fireLaser()
      observedLasersFired += 1
    }
  }

  func spawnPlayer() {
    var spawnPosition = CGPoint(x: gameFrame.midX, y: gameFrame.midY)
    var attemptsRemaining = 5
    while attemptsRemaining > 0 && !isSafe(point: spawnPosition, forDuration: 5) {
      let spawnRegion = gameFrame.insetBy(dx: 0.33 * gameFrame.width, dy: 0.33 * gameFrame.height)
      spawnPosition = CGPoint(x: .random(in: spawnRegion.minX...spawnRegion.maxX),
                              y: .random(in: spawnRegion.minY...spawnRegion.maxY))
      attemptsRemaining -= 1
    }
    if attemptsRemaining == 0 {
      // We didn't find a safe position so wait a bit and try again.  This should't
      // really happen in the tutorial.
      wait(for: 0.5) { self.spawnPlayer() }
    } else {
      energyBar.fill()
      audio.soundEffect(.warpIn, at: spawnPosition)
      player.reset()
      player.warpIn(to: spawnPosition, atAngle: player.zRotation, addTo: playfield)
    }
  }

  func laserHit(laser: SKNode, asteroid: SKNode) {
    removeLaser(laser as! SKSpriteNode)
    splitAsteroid(asteroid as! SKSpriteNode)
  }

  func destroyPlayer() {
    let pieces = player.explode()
    addExplosion(pieces)
    audio.soundEffect(.playerExplosion)
    let messages = [
      "@No problem@, that'll buff right out. Take another ship.",
      "That's gotta be @painful@... Oh well, there's more ships where @that@ came from.",
      "You know they @dock your pay@ for that sort of thing? Just @sayin'@...",
      "Spacecraft get hit by @small@ debris all the time. @Unfortunately@, that wasn't small.",
      "@Much to learn@ you still have, hmmm?",
      "I think we'll give you the call sign @\"Crash\"@...",
      "It's usually better @NOT@ to destroy asteroids by @ramming@...",
      "Let me guess, you want to be known as @Han #YOLO@?"
    ]
    var message = messages[deathCount]
    deathCount += 1
    if asteroids.isEmpty {
      if deathCount != messages.count {
        message += " At least you cleared the debris."
      }
    }
    wait(for: 2) {
      self.topInstructions(message, height: 150)
      self.giveInstructions(text: message) {
        self.spawnPlayer()
      }
    }
  }

  func playerCollided(asteroid: SKNode) {
    splitAsteroid(asteroid as! SKSpriteNode)
    destroyPlayer()
  }

  func didBegin(_ contact: SKPhysicsContact) {
    when(contact, isBetween: .playerShot, and: .asteroid) { laserHit(laser: $0, asteroid: $1) }
    when(contact, isBetween: .player, and: .asteroid) { playerCollided(asteroid: $1) }
  }

  func giveInstructions(text: String, whenDone: (() -> Void)?) {
    instructionsLabel.attributedText = makeAttributed(text: text, until: text.startIndex, attributes: attributes)
    instructionsLabel.alpha = 1
    instructionsLabel.isHidden = false
    instructionsLabel.typeIn(text: text, attributes: attributes, sounds: transmissionSounds, whenDone: whenDone)
  }

  func showMoveOnButton(action: @escaping () -> Void) {
    removeMoveOnButton()
    let labelFrame = instructionsLabel.frame
    print("label frame \(labelFrame)")
    // Because the instructionsLabel is multi-line and left justified, it looks more
    // balanced with a small amount of extra space on the left.
    let button = Button(around: instructionsLabel, minSize: labelFrame.size)
    button.position = CGPoint(x: labelFrame.midX, y: labelFrame.midY)
    button.zPosition = instructionsLabel.zPosition
    button.action = action
    button.alpha = 0
    button.disable()
    button.run(SKAction.sequence([SKAction.fadeIn(withDuration: 0.25),
                                  SKAction.run { button.enable() }]))
    addChild(button)
    moveOnButton = button
  }

  func removeMoveOnButton() {
    guard let button = moveOnButton else { return }
    button.disable()
    button.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.25),
                                  SKAction.removeFromParent()]))
    moveOnButton = nil
  }

  func fadeOutInstructions(then action: @escaping () -> Void) {
    removeMoveOnButton()
    instructionsLabel.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.25),
                                             SKAction.hide()]), completion: action)
  }

  func moveOnThen(action: @escaping () -> Void) -> (() -> Void) {
    return { self.showMoveOnButton { self.fadeOutInstructions { action() } } }
  }

  func giveSimpleInstructions(text: String, then action: @escaping () -> Void) {
    giveInstructions(text: text, whenDone: moveOnThen(action: action))
  }

  func topInstructions(_ instructions: String, height: CGFloat = 200) {
    instructionGeometry(text: instructions, maxWidth: gameFrame.width - 100, wantedHeight: height,
                        horizontal: .center, vertical: .top, position: CGPoint(x: gameFrame.midX, y: gameFrame.maxY - 50))
  }

  func tutorial1() {
    let instructions = """
    I'm @Lt Carla Grace@, welcome aboard! I'm going to show you the ropes. \
    @Touch here@ when you're ready to @begin your training@.
    """
    instructionGeometry(text: instructions, maxWidth: gameFrame.width - 100, wantedHeight: 300,
                        horizontal: .center, vertical: .center, position: CGPoint(x: gameFrame.midX, y: gameFrame.midY))
    giveSimpleInstructions(text: instructions) { self.tutorial2() }
  }

  func tutorial2() {
    spawnPlayer()
    let instructions = """
    This is your ship, an old @Piper Mark II@. If you \
    prove competent (and @don't die@), maybe someday you'll be trusted with a new \
    @Mark VII@.
    """
    topInstructions(instructions)
    giveSimpleInstructions(text: instructions) { self.tutorial3() }
  }

  func tutorial3() {
    let instructions = """
    I'll activate your ship's systems @one by one@ so that you \
    can get the feel of them. @Follow my instructions@ to try them out.
    """
    topInstructions(instructions)
    giveSimpleInstructions(text: instructions) { self.tutorial4() }
  }

  func tutorial4() {
    let instructions = """
    You @touch and swipe on this side of the screen@ to control the ship. \
    @The position@ where you initially touch @doesn't matter@. @The direction of \
    the swipe@ is what determines how the ship @responds@.
    """
    instructionGeometry(text: instructions, maxWidth: gameFrame.width / 2 - 100, wantedHeight: 200,
                        horizontal: .left, vertical: .center, position: CGPoint(x: gameFrame.minX + 50, y: gameFrame.midY))
    giveSimpleInstructions(text: instructions) { self.tutorial5() }
  }

  func tutorial5() {
    let instructions = """
    @Touch and swipe left and right@ to rotate. Try out @both directions@. \
    When you @succeed@, we'll continue.
    """
    topInstructions(instructions)
    giveInstructions(text: instructions) {
      self.maxRotate = .infinity
      self.observeRotate()
    }
  }

  func observeRotate() {
    wait(for: 1) {
      if self.observedMinRotate < -0.75 && self.observedMaxRotate > 0.75 {
        (self.moveOnThen { self.tutorial6() })()
      } else {
        self.observeRotate()
      }
    }
  }

  func tutorial6() {
    let instructions = """
    @Touch and swipe upwards@ to thrust forward. @Larger@ swipes give @more throttle@. \
    @Build up some speed@ in order to move on.
    """
    topInstructions(instructions)
    giveInstructions(text: instructions) {
      self.maxThrust = .infinity
      self.observeThrust()
    }
  }

  func observeThrust() {
    wait(for: 1) {
      if self.observedMaxThrust > 0.75 && self.player.requiredPhysicsBody().velocity.norm2() > 200 {
        (self.moveOnThen { self.tutorial7() })()
      } else {
        self.observeThrust()
      }
    }
  }

  func tutorial7() {
    let instructions = """
    Notice that @you'll keep moving@ even if you @stop thrusting@. To stop, \
    @turn around and thrust@ in the @opposite@ direction. Try to stop now.
    """
    topInstructions(instructions)
    giveInstructions(text: instructions) {
      self.observeStop()
    }
  }

  func observeStop() {
    wait(for: 1) {
      if self.player.requiredPhysicsBody().velocity.norm2() < 50 {
        (self.moveOnThen { self.tutorial8() })()
      } else {
        self.observeStop()
      }
    }
  }

  func tutorial8() {
    let instructions = """
    It's best to @go easy on the thrust@ most of the time. \
    Get going @too@ fast and you'll probably be a @rock splat@ instead of a @Rock Rat@.
    """
    topInstructions(instructions)
    giveSimpleInstructions(text: instructions) { self.tutorial9() }
  }

  func tutorial9() {
    let instructions = """
    You also have @reverse@ thrusters, though they're @weak@. @Touch and swipe down@ to try them.
    """
    topInstructions(instructions)
    giveInstructions(text: instructions) {
      self.minThrust = -.infinity
      self.observeReverse()
    }
  }

  func observeReverse() {
    wait(for: 1) {
      if self.observedMinThrust < -0.75 {
        (self.moveOnThen { self.tutorial10() })()
      } else {
        self.observeReverse()
      }
    }
  }

  func tutorial10() {
    let instuctions = """
    Space in this quadrant has some @weird curvature@, \
    so objects wrap across edges. Probably nothing to do with the nearby @black holes@.
    """
    topInstructions(instuctions)
    giveSimpleInstructions(text: instuctions) { self.tutorial11() }
  }
  
  func tutorial11() {
    let instuctions = """
    It's @nothing to worry about@, but it can be @disorienting@. Try to stay near the @center@ to avoid getting @blindsided@.
    """
    topInstructions(instuctions)
    giveSimpleInstructions(text: instuctions) { self.tutorial12() }
  }
  
  func tutorial12() {
    let instructions = """
    We also gave you a bit of @weaponry@, which you control using @this side@ of the screen... \
    And please, do be careful.
    I get a raise if my @mortality rate@ is low.
    """
    instructionGeometry(text: instructions, maxWidth: gameFrame.width / 2 - 100, wantedHeight: 200,
                        horizontal: .right, vertical: .center, position: CGPoint(x: gameFrame.maxX - 50, y: gameFrame.midY))
    giveSimpleInstructions(text: instructions) { self.tutorial13() }
  }
  
  func tutorial13() {
    let instructions = """
    @Single taps@ will fire the lasers. @Fire some shots@ to get a feel for it, and then we'll continue.
    """
    topInstructions(instructions)
    giveInstructions(text: instructions) {
      self.shootingEnabled = true
      self.observeFiring()
    }
  }
  
  func observeFiring() {
    wait(for: 1) {
      if self.observedLasersFired > 5 {
        (self.moveOnThen { self.tutorial14() })()
      } else {
        self.observeFiring()
      }
    }
  }
  
  func tutorial14() {
    let instuctions = """
    Regulations limit the number of @simultaneous@ laser pulses per ship, to avoid @crossing the streams@. Why? @It would be bad@...
    """
    topInstructions(instuctions)
    giveSimpleInstructions(text: instuctions) { self.tutorial15() }
  }
  
  func tutorial15() {
    let instructions = """
    You'll use the lasers primarily to @clear asteroid debris@. Speaking of such, here comes some now. @Cleanup on aisle 6@ please.
    """
    topInstructions(instructions)
    giveInstructions(text: instructions) {
      self.spawnAsteroid(size: "med")
      self.observeAsteroids { self.tutorial16() }
    }
  }
  
  func observeAsteroids(_ whenCleared: @escaping () -> Void) {
    wait(for: 1) {
      if self.asteroids.isEmpty && self.player.parent != nil{
        (self.moveOnThen { whenCleared() })()
      } else {
        self.observeAsteroids(whenCleared)
      }
    }
  }
  
  func tutorial16() {
    let instructions = """
    @Small@ debris is not much trouble, but some pieces are @bigger@. You'll \
    need @multiple shots@ to @completely@ destroy them.
    """
    topInstructions(instructions)
      giveInstructions(text: instructions) {
        self.spawnAsteroid(size: "huge")
        self.observeAsteroids { self.tutorial17() }
      }
  }
  
  func tutorial17() {
    let instructions = """
    One other minor tidbit. Producing @laser pulses@ \
    takes @energy@, and your reactor has a @limited generation@ rate.
    """
    topInstructions(instructions)
    giveSimpleInstructions(text: instructions) { self.tutorial18() }
  }
  
  func tutorial18() {
    let instructions = """
    This bar shows your @energy reserves@. Fire some shots and @observe the bar@.
    """
    instructionGeometry(text: instructions, maxWidth: gameFrame.width / 2 - 100, wantedHeight: 200,
                        horizontal: .right, vertical: .top, position: CGPoint(x: gameFrame.maxX - 50, y: energyBar.position.y - 50))
    giveSimpleInstructions(text: instructions) { self.tutorial19() }
    energyBar.isHidden = false
  }
  
  func tutorial19() {
    let instructions = """
    Energy for shooting won't usually be a @problem@, but there's one @other@ \
    capability that I @hesitate@ to mention...
    """
    topInstructions(instructions)
    giveSimpleInstructions(text: instructions) { self.tutorial20() }
  }
  
  func tutorial20() {
    let instructions = """
    If you get into a @tight@ spot, you can try jumping into @hyperspace@. You might \
    @become one with an asteroid@ though, and it needs a lot of @energy@.
    """
    topInstructions(instructions)
    giveSimpleInstructions(text: instructions) { self.tutorial21() }
  }
  
  func tutorial21() {
    let instructions = """
    A quick @swipe-and-release@ on this side will activate the @jump@.  Watch your @energy \
    bar@ and see what happens. Just let me @get clear@ and I'll enable the @hyperdrive@.
    """
    instructionGeometry(text: instructions, maxWidth: gameFrame.width / 2 - 100, wantedHeight: 200,
                        horizontal: .right, vertical: .center, position: CGPoint(x: gameFrame.maxX - 50, y: gameFrame.midY))
    giveSimpleInstructions(text: instructions) { self.tutorial22() }
  }
  
  func tutorial22() {
    let instructions = """
    Ok, you are @go for launch@. Assuming no @spontaneous combustion@ occurs, we'll continue when you're back.
    """
    topInstructions(instructions)
    giveInstructions(text: instructions) {
      self.hyperspaceEnabled = true
      self.observeJump()
    }
  }
  
  func observeJump() {
    wait(for: 1) {
      if self.hasJumped {
        (self.moveOnThen { self.tutorial23() })()
      } else {
        self.observeJump()
      }
    }
  }
  
  func tutorial23() {
    let instructions = """
    We do have @quite a few@ Mark II's, so you're allocated some @reserve \
    ships@, and if you're performing well, @Central@ will provide \
    @more@.
    """
    topInstructions(instructions)
    giveSimpleInstructions(text: instructions) { self.tutorial24() }
  }
  
  func tutorial24() {
    let instructions = """
    The @number@ of reserves you have is @shown@ up in this corner.
    """
    livesDisplay.isHidden = false
    instructionGeometry(text: instructions, maxWidth: gameFrame.width / 2 - 100, wantedHeight: 200,
                        horizontal: .left, vertical: .top, position: CGPoint(x: gameFrame.minX + 50, y: livesDisplay.position.y - 50))
    giveSimpleInstructions(text: instructions) { self.finishTutorial() }
  }
  
  func finishTutorial() {
    let instructions = """
    That concludes your training. @Good luck@, and I'll see you out in the fields!
    """
    topInstructions(instructions)
    giveSimpleInstructions(text: instructions) { self.switchScene(to: Globals.menuScene) }
  }

  func startInTheMiddleOfTheTutorial() {
    // This is just for testing.  It has the various controls things enabled in the
    // order that matches the tutorial.  Comment out whatever is not appropriate and
    // then call this before jumping to an intermediate tutorial stage.
    spawnPlayer()
    maxRotate = .infinity
    maxThrust = .infinity
    minThrust = -.infinity
    shootingEnabled = true
    energyBar.isHidden = false
    hyperspaceEnabled = true
    livesDisplay.isHidden = false
  }

  override func didMove(to view: SKView) {
    super.didMove(to: view)
    joystickTouch = nil
    fireOrWarpTouches.removeAll()
    clearPlayfield()
    energyBar.isHidden = true
    livesDisplay.isHidden = true
    Globals.gameConfig = loadGameConfig(forMode: "normal")
    Globals.gameConfig.currentWaveNumber = 1
    score = 0
    energyBar.fill()
    replenishEnergy()
    livesDisplay.showLives(3)
    deathCount = 0
    wait(for: 1) {
      self.tutorial1()
    }
    logging("\(name!) finished didMove to view")
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    player.fly()
    playfield.wrapCoordinates()
  }

  override init(size: CGSize) {
    super.init(size: size)
    name = "tutorialScene"
    initInstructions()
    player = Ship(color: "blue", getJoystickDirection: { [unowned self] in return self.clampedJoystick() }, audio: audio)
    physicsWorld.contactDelegate = self
  }

  required init(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}
