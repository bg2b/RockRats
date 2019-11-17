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
      Globals.conformingPhysicsCache.preload()
      let size = CGSize(width: 768 * aspect, height: 768)
      Globals.menuScene = MenuScene(size: size)
      Globals.gcInterface = GameCenterInterface(leaderboardID: "org.davidlong.Asteroids.normalScores",
                                                presenter: { vc in Globals.menuScene.setGameCenterAuth(viewController: vc) })
      let toPresent = userDefaults.hasDoneIntro.value ? Globals.menuScene! : IntroScene(size: size, conclusion: false)
      logging("viewDidLoad will present \(toPresent.name!)")
      view.presentScene(toPresent)
      view.preferredFramesPerSecond = 120
      view.ignoresSiblingOrder = true
      view.showsFPS = true
      view.showsNodeCount = true
      view.showsDrawCount = true
    }
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    logging("viewWillLayoutSubviews saving safe area")
    Globals.safeAreaPaddingLeft = view.safeAreaInsets.left * Globals.ptsToGameUnits
    Globals.safeAreaPaddingRight = view.safeAreaInsets.right * Globals.ptsToGameUnits
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
  static var gcInterface: GameCenterInterface!
  static var ptsToGameUnits = CGFloat(1)
  static var menuScene: MenuScene!
  static var safeAreaPaddingLeft = CGFloat(0)
  static var safeAreaPaddingRight = CGFloat(0)
}
