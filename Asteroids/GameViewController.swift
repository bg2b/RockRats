//
//  GameViewController.swift
//  Asteroids
//
//  Created by David Long on 7/7/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    /*
    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let file = directory.appendingPathComponent("ourdata.txt")
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try "hello world".write(to: file, atomically: true, encoding: String.Encoding.utf8)
    } catch {
      print(error)
    }
    do {
      let contents = try String(contentsOf: file)
      print(contents)
    } catch {
      print(error)
    }
     */
    if let lang = Locale.preferredLanguages.first {
      logging("Preferred language \(lang)")
    }
    if let view = self.view as! SKView? {
      let aspect = view.frame.width / view.frame.height
      // Save the scaling for use with control motions.  We want to specify motions
      // in terms of pts, since those correspond approximately to physical distances
      // that the user's fingers should move.
      Globals.ptsToGameUnits = 768 / view.frame.height
      logging("\(Globals.ptsToGameUnits) game units per pt")
      let size = CGSize(width: 768 * aspect, height: 768)
      Globals.gameScene = GameScene(size: size)
      Globals.menuScene = MenuScene(size: size)
      Globals.tutorialScene = TutorialScene(size: size)
      let introScene = IntroScene(size: size)
      logging("viewDidLoad will present \(introScene.name!)")
      view.presentScene(Globals.menuScene)
      view.preferredFramesPerSecond = 120
      view.ignoresSiblingOrder = true
      view.showsFPS = true
      view.showsNodeCount = true
      view.showsDrawCount = true
    }
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    if let gameScene = Globals.gameScene {
      logging("viewWillLayoutSubviews calling setSafeArea for gameScene")
      let leftPadding = view.safeAreaInsets.left * gameScene.size.width / view.frame.width
      let rightPadding = view.safeAreaInsets.right * gameScene.size.width / view.frame.width
      gameScene.setSafeArea(left: leftPadding, right: rightPadding)
    }
  }

  override var shouldAutorotate: Bool {
    return true
  }

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .landscape
  }

  override var prefersStatusBarHidden: Bool {
    return true
  }

  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    return UIRectEdge.bottom
  }
}

extension Globals {
  static var ptsToGameUnits = CGFloat(1)
  static var menuScene: MenuScene!
  static var gameScene: GameScene!
  static var tutorialScene: TutorialScene!
}
