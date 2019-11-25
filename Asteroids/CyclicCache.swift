//
//  CyclicCache.swift
//  Asteroids
//
//  Created by David Long on 10/8/19.
//  Copyright © 2019 David Long. All rights reserved.
//

import Foundation

/// A cache of values that get used repeatedly in a round-robin fashion
///
/// This is currently just used for `SKEmitterNode`s for asteroid splitting.  I grab
/// the next entry from the cache whenever an asteroid gets hit and then add it to
/// the playfield as an effect.  By the time that same emitter gets used again, it
/// will have expired and been removed from the playfield and be ready for reuse.
///
/// Originally this was also used for `AVAudioPlayer`s for sound effects, but then I
/// figured out how to use the audio engine correctly.
class CyclicCache<Key: Hashable, Value> {
  /// An entry in the cache has an array of values (of type `T`) and cycles through
  /// them
  class CyclicCacheEntries<T> {
    var items = [T]()
    var nextItem = -1

    var count: Int { return items.count }

    /// Add items to the cache
    /// - Parameter creator: A closure that makes an item
    func addItem(creator: () -> T) {
      items.append(creator())
    }

    /// Retrieve the next item and advance the internal item counter
    /// - Returns: The item to be reused
    func getNextItem() -> T {
      nextItem += 1
      if nextItem >= items.count {
        nextItem = 0
      }
      return items[nextItem]
    }
  }

  /// An ID just for debug printing
  let cacheId: String
  /// A dictionary mapping whatever key to an array of reusable items
  var cache = [Key: CyclicCacheEntries<Value>]()
  /// A count of how many items have been used, for debug printing
  var itemsUsed = 0

  /// Create a new cache
  /// - Parameter cacheId: Identifier for debugging
  init(cacheId: String) {
    self.cacheId = cacheId
  }

  /// Preload the cache
  ///
  /// The number of items should be large enough to ensure that reuse doesn't cause
  /// problems, so it's basically the maximum number of whatevs that should be needed
  /// simultaneously.  It's OK to call this again later if it turns out that more
  /// items are required.  Additional items will be created to bring the total up to
  /// `count`.
  ///
  /// - Parameters:
  ///   - count: The minimum number of items desired
  ///   - key: The key for the type of items
  ///   - creator: The item creation closure
  func load(count: Int, forKey key: Key, creator: () -> Value) {
    if cache[key] == nil {
      cache[key] = CyclicCacheEntries<Value>()
    }
    let entries = cache[key]!
    while entries.count < count {
      entries.addItem(creator: creator)
    }
  }

  /// Return the next item to reuse
  /// - Parameter key: The key for the type of item
  /// - Returns: The item to reuse
  func next(forKey key: Key) -> Value {
    guard let entries = cache[key] else { fatalError("\(cacheId) was not loaded for key \(key)") }
    itemsUsed += 1
    return entries.getNextItem()
  }

  /// Print some stats for debugging or tuning
  func stats() {
    var totalItems = 0
    for (_, entries) in cache {
      totalItems += entries.count
    }
    logging("\(cacheId) has \(totalItems) unique items, used \(itemsUsed)")
  }
}
