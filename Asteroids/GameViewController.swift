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
    if let view = self.view as! SKView? {
      let aspect = view.frame.width / view.frame.height
      let size = CGSize(width: 768 * aspect, height: 768)
      Globals.gameScene = GameScene(size: size)
      Globals.menuScene = MenuScene(size: size)
      view.presentScene(Globals.gameScene)
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
}

extension Globals {
  static var menuScene: MenuScene!
  static var gameScene: GameScene!
}
