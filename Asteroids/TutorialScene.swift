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
  var continueButton: Button? = nil
  let attributes = AttrStyles(fontName: "Kenney Future Narrow", fontSize: 40)
  var maxThrust = CGFloat(0)
  var minThrust = CGFloat(0)
  var maxRotate = CGFloat(0)
  var observedMaxThrust = CGFloat(0)
  var observedMinThrust = CGFloat(0)
  var observedMinRotate = CGFloat(0)
  var observedMaxRotate = CGFloat(0)
  var shootingEnabled = false
  var hyperspaceEnabled = false

  func initInstructions() {
    instructionsLabel = SKLabelNode(text: "")
    instructionsLabel.numberOfLines = 5
    instructionsLabel.lineBreakMode = .byWordWrapping
    instructionsLabel.zPosition = LevelZs.info.rawValue
    addChild(instructionsLabel)
    instructionGeometry(width: 600, horizontal: .center, vertical: .center, position: CGPoint(x: gameFrame.midX, y: gameFrame.midY))
  }

  func instructionGeometry(width: CGFloat, horizontal: SKLabelHorizontalAlignmentMode, vertical: SKLabelVerticalAlignmentMode, position: CGPoint) {
    instructionsLabel.preferredMaxLayoutWidth = width
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
      super.hyperspaceJump()
    }
  }

  override func fireLaser() {
    if shootingEnabled {
      super.fireLaser()
    }
  }

  func spawnPlayer(at preferredPosition: CGPoint) {
    var spawnPosition = preferredPosition
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
      wait(for: 0.5) { self.spawnPlayer(at: preferredPosition) }
    } else {
      energyBar.fill()
      Globals.sounds.soundEffect(.warpIn)
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
    Globals.sounds.soundEffect(.playerExplosion)
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
    instructionsLabel.typeIn(text: text, attributes: attributes, whenDone: whenDone)
  }

  func showContinueButton(action: @escaping () -> Void) {
    removeContinueButton()
    let labelFrame = instructionsLabel.frame
    // Because the instructionsLabel is multi-line and left justified, it looks more
    // balanced with a small amount of extra space on the left.
    let button = Button(around: instructionsLabel, minSize: labelFrame.size, extraLeft: 5)
    button.position = CGPoint(x: labelFrame.midX, y: labelFrame.midY)
    button.zPosition = instructionsLabel.zPosition
    button.action = action
    button.alpha = 0
    button.disable()
    button.run(SKAction.sequence([SKAction.fadeIn(withDuration: 0.25),
                                  SKAction.run { button.enable() }]))
    addChild(button)
    continueButton = button
  }

  func removeContinueButton() {
    guard let button = continueButton else { return }
    button.disable()
    button.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.25),
                                  SKAction.removeFromParent()]))
    continueButton = nil
  }

  func fadeOutInstructions(then action: @escaping () -> Void) {
    removeContinueButton()
    instructionsLabel.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.25),
                                             SKAction.hide()]), completion: action)
  }

  func continueThen(action: @escaping () -> Void) -> (() -> Void) {
    return { self.showContinueButton { self.fadeOutInstructions { action() } } }
  }

  func giveSimpleInstructions(text: String, then action: @escaping () -> Void) {
    giveInstructions(text: text, whenDone: continueThen(action: action))
  }

  func tutorial1() {
    instructionGeometry(width: 600, horizontal: .center, vertical: .center, position: CGPoint(x: gameFrame.midX, y: gameFrame.midY))
    let instructions = """
    I'm @Lt Starbuck@, welcome aboard! I'm going to show you the ropes. \
    Touch here when you're ready to begin your training.
    """
    giveSimpleInstructions(text: instructions) { self.tutorial2() }
  }

  func tutorial2() {
    let spawnX = 0.25 * gameFrame.minX + 0.75 * gameFrame.maxX
    spawnPlayer(at: CGPoint(x: spawnX, y: gameFrame.midY))
    let instructionX = 0.5 * (gameFrame.minX + spawnX)
    instructionGeometry(width: (instructionX - gameFrame.minX - 100) * 2, horizontal: .center, vertical: .center,
                        position: CGPoint(x: instructionX, y: gameFrame.midY))
    let instructions = """
    This is your ship, a @Viper Mark II@. They're old, but reliable. If you \
    prove competent (and don't die), maybe someday you'll be trusted with a new \
    @Mark VII@.
    """
    wait(for: 1) {
      self.giveSimpleInstructions(text: instructions) { self.tutorial3() }
    }
  }

  func tutorial3() {
    let instructions = """
    In this exercise, I'll activate your ship's systems one by one so that you \
    can get the feel of them.  Follow my instructions to try them out.  Don't worry, \
    there's nothing @too@ dangerous around, so you should be OK.
    """
    giveSimpleInstructions(text: instructions) { self.tutorial4() }
  }

  func tutorial4() {
    instructionGeometry(width: 600, horizontal: .left, vertical: .top,
                        position: CGPoint(x: gameFrame.minX + 50, y: gameFrame.maxY - 50))
    let instructions = """
    Touch and swipe on this side of the screen somewhere below these \
    instructions to control the ship. \
    @Swipe left and right@ to rotate. Do that now. After you succeed \
    you'll be able to continue.
    """
    giveInstructions(text: instructions) {
      self.maxRotate = .infinity
      self.observeRotate()
    }
  }

  func observeRotate() {
    wait(for: 1) {
      if self.observedMinRotate < -0.75 && self.observedMaxRotate > 0.75 {
        (self.continueThen { self.tutorial5() })()
      } else {
        self.observeRotate()
      }
    }
  }

  func tutorial5() {
    let instructions = """
    You also need to be able to move, so I'm going to enable the engines. \
    @Touch and swipe upwards@ to thrust forward.  Build up a bit of speed and \
    and then you'll be able to continue.
    """
    giveInstructions(text: instructions) {
      self.maxThrust = .infinity
      self.observeThrust()
    }
  }

  func observeThrust() {
    wait(for: 1) {
      if self.observedMaxThrust > 0.5 && self.player.requiredPhysicsBody().velocity.norm2() > 100 {
        (self.continueThen { self.tutorial6() })()
      } else {
        self.observeThrust()
      }
    }
  }

  func tutorial6() {

  }

  override func didMove(to view: SKView) {
    super.didMove(to: view)
    joystickTouch = nil
    fireOrWarpTouches.removeAll()
    removeAllAsteroids()
    energyBar.isHidden = true
    livesDisplay.isHidden = true
    initSounds()
    Globals.gameConfig = loadGameConfig(forMode: "normal")
    Globals.gameConfig.currentWaveNumber = 0
    score = 0
    energyBar.fill()
    replenishEnergy()
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

  required init(size: CGSize) {
    super.init(size: size)
    name = "tutorialScene"
    initInstructions()
    player = Ship(color: "blue", getJoystickDirection: { [unowned self] in return self.clampedJoystick() })
    physicsWorld.contactDelegate = self
  }

  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented by TutorialScene")
  }
}
