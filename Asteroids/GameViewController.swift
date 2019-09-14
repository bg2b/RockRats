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
  weak var scene: BasicScene? = nil

  override func viewDidLoad() {
    super.viewDidLoad()
    if let view = self.view as! SKView? {
      let aspect = view.frame.width / view.frame.height
      let scene = GameScene(size: CGSize(width: 768 * aspect, height: 768))
      scene.scaleMode = .aspectFill
      scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
      scene.physicsWorld.gravity = .zero
      self.scene = scene
      view.presentScene(scene)
      view.preferredFramesPerSecond = 120
      view.ignoresSiblingOrder = true
      view.showsFPS = true
      view.showsNodeCount = true
      view.showsDrawCount = true
    }
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    if let scene = scene {
      let leftPadding = view.safeAreaInsets.left * scene.frame.width / view.frame.width
      let rightPadding = view.safeAreaInsets.right * scene.frame.width / view.frame.width
      scene.setSafeArea(left: leftPadding, right: rightPadding)
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
