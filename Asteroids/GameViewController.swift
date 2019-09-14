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
  var gameScene: GameScene!

  override func viewDidLoad() {
    super.viewDidLoad()
    if let view = self.view as! SKView? {
      let aspect = view.frame.width / view.frame.height
      gameScene = GameScene(size: CGSize(width: 768 * aspect, height: 768))
      view.presentScene(gameScene)
      view.preferredFramesPerSecond = 120
      view.ignoresSiblingOrder = true
      view.showsFPS = true
      view.showsNodeCount = true
      view.showsDrawCount = true
    }
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    let leftPadding = view.safeAreaInsets.left * gameScene.size.width / view.frame.width
    let rightPadding = view.safeAreaInsets.right * gameScene.size.width / view.frame.width
    gameScene.setSafeArea(left: leftPadding, right: rightPadding)
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
