//
//  SpriteData.swift
//  Asteroids
//
//  Created by David Long on 7/7/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import SpriteKit

extension SKNode {
  func getUserDict() -> NSMutableDictionary {
    if let dict = self.userData {
      return dict
    } else {
      let dict = NSMutableDictionary()
      self.userData = dict
      return dict
    }
  }

  subscript<T>(key: String) -> T? {
    get {
      let dict = self.getUserDict()
      guard let result: T = dict[key] as? T else { return nil }
      return result
    }

    set(newVal) {
      self.getUserDict()[key] = newVal
    }
  }
}
