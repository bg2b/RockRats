//
//  CyclicCache.swift
//  Asteroids
//
//  Created by David Long on 10/8/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import Foundation

class CyclicCacheEntries<T> {
  var items = [T]()
  var nextItem = -1

  var count: Int { return items.count }

  func addItem(creator: () -> T) {
    items.append(creator())
  }

  func getNextItem() -> T {
    nextItem += 1
    if nextItem >= items.count {
      nextItem = 0
    }
    return items[nextItem]
  }
}

class CyclicCache<Key: Hashable, Value> {
  let cacheId: String
  var cache = [Key: CyclicCacheEntries<Value>]()
  var itemsUsed = 0

  init(cacheId: String) {
    self.cacheId = cacheId
  }

  func load(count: Int, forKey key: Key, creator: () -> Value) {
    if cache[key] == nil {
      cache[key] = CyclicCacheEntries<Value>()
    }
    let entries = cache[key]!
    while entries.count < count {
      entries.addItem(creator: creator)
    }
  }

  func next(forKey key: Key) -> Value {
    guard let entries = cache[key] else { fatalError("\(cacheId) was not loaded for key \(key)") }
    itemsUsed += 1
    return entries.getNextItem()
  }

  func stats() {
    var totalItems = 0
    for (_, entries) in cache {
      totalItems += entries.count
    }
    logging("\(cacheId) has \(totalItems) unique items, used \(itemsUsed)")
  }
}
