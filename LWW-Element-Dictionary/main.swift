//
//  main.swift
//  LWW-Element-Dictionary
//
//  Created by Lakshaya Chhabra on 17/11/20.
//

import Foundation

typealias DictonaryValue = [AnyHashable: AnyHashable]

// MARK: LWWGrowSet
struct LWWGrowSet<T: Hashable> {
  /// A dictionary that stores the time an element was added.
  private var timestamps = [T: Date]()
  
  // MARK: lookup
  /// Returns the time `item` was added to this set, if it was added.
  ///
  /// - Parameter item: The item to look up.
  /// - Returns: The time `item` was added or nil.
  func lookup(_ item: T) -> Date? {
    return timestamps[item]
  }
  
  // MARK: compare
  /// Returns whether this subset is a subset of the other set.
  ///
  /// - Parameter anotherSet: Another set to compare this set to.
  /// - Returns: Whether this set is a subset of the other set.
  func compare(anotherSet: LWWGrowSet<T>) -> Bool {
    return timestamps.allSatisfy { anotherSet.lookup($0.key) != nil }
  }
  
  // MARK: add
  /// Adds an item to this set.
  ///
  /// - Parameters:
  ///   - item: The item to add to this set.
  ///   - timestamp: The time at which `item` was added into this set. If not provided, defaults to the current system date/time.
  mutating func add(_ item: T, timestamp: Date = Date()) {
    if let previousAddTime = lookup(item), previousAddTime >= timestamp {
      return
    }
    timestamps[item] = timestamp
  }
  
  // MARK: merge
  /// Merges another set into this set, selecting the later timestamp if there are multiple for the same element.
  ///
  /// - Parameter anotherSet: The set to merge into this set.
  mutating func merge(anotherSet: LWWGrowSet<T>) {
    timestamps.merge(anotherSet.timestamps) { (current, new) in max(current, new) }
  }
}

// MARK: LWWElementSet
/// A LWW-Element-set implementation.
struct LWWElementSet<T: Hashable> {
  private var addSet = LWWGrowSet<T>()
  private var removeSet = LWWGrowSet<T>()
  
  // MARK: lookup
  /// Returns the time `item` was last added to this set, or nil if the item was removed or never added.
  ///
  /// - Parameter item: The item to look up.
  /// - Returns: The time `item` was added or nil.
  func lookup(_ item: T) -> Date? {
    if let addTime = addSet.lookup(item) {
      if let removeTime = removeSet.lookup(item) {
        if (addTime > removeTime) {
          return addTime
        }
        return nil
      }
      return addTime
    }
    return nil
  }
  
  // MARK: compare
  /// Returns whether this subset is a subset of the other set.
  ///
  /// - Parameter anotherSet: Another set to compare this set to.
  /// - Returns: Whether this set is a subset of the other set.
  func compare(anotherSet: LWWElementSet<T>) -> Bool {
    return addSet.compare(anotherSet: anotherSet.addSet) && removeSet.compare(anotherSet: anotherSet.removeSet)
  }
  
  // MARK: add
  /// Adds an item to this set.
  ///
  /// - Parameters:
  ///   - item: The item to add to this set.
  ///   - timestamp: The time at which `item` was added into this set. If not provided, defaults to the current system date/time.
  mutating func add(_ item: T, timestamp: Date = Date()) {
    addSet.add(item, timestamp: timestamp)
  }
  
  // MARK: remove
  /// Removes an item from this set. Noop if `item` is not in this set or has been removed after it was last added.
  ///
  /// - Parameters:
  ///   - item: The item to remove from this set.
  ///   - timestamp: The time at which `item` was removed from this set. If not provided, defaults to the current system date/time.
  mutating func remove(_ item: T, timestamp: Date = Date()) {
    guard lookup(item) != nil else {
      return
    }
    removeSet.add(item, timestamp: timestamp)
  }
  
  // MARK: merge
  /// Merges another set into this set.
  ///
  /// - Parameter anotherSet: The set to merge into this set.
  mutating func merge(anotherSet: LWWElementSet<T>) {
    addSet.merge(anotherSet: anotherSet.addSet)
    removeSet.merge(anotherSet: anotherSet.removeSet)
  }
}

// MARK: LWWElementSet Dictonary Specification
extension LWWElementSet where T == DictonaryValue {
  // MARK: Update Key
  /// Update Dictionary Value based on key.
  ///
  /// - Parameter newItem: The set to update keys if any are common.
  mutating func updateForDict(_ item: T, with newItem: T) {
    guard let lookupTime = lookup(item) else {
      self.add(newItem)
      return
    }
    self.remove(item, timestamp: lookupTime)
    self.add(newItem, timestamp: lookupTime)
  }
}



// MARK: #Tests
/// Timestamps for use in test cases below
///
/// Timestamps are separated 10 mins apart for easy viewing.
let timestamps = (0...5).map { return Date(timeIntervalSinceReferenceDate: TimeInterval($0 * 10 * 60)) }

// MARK: LWW Grow-only set tests
var gSet1 = LWWGrowSet<DictonaryValue>()
var gSet2 = LWWGrowSet<DictonaryValue>()

// MARK:  Single set tests
gSet1.add([1:1], timestamp: timestamps[0])
gSet1.add([2:2], timestamp: timestamps[0])
gSet1.add([2:2], timestamp: timestamps[1])
gSet1.add([3:3], timestamp: timestamps[1])
gSet1.add([3:3], timestamp: timestamps[0])
assert(gSet1.lookup([1:1]) == timestamps[0], "Expect timestamp to be returned if item was added")
assert(gSet1.lookup([2:2]) == timestamps[1], "Expect timestamp to be updated if the second add has a higher timestamp")
assert(gSet1.lookup([3:3]) == timestamps[1], "Expect timestamp not to be updated if the second add has a lower timestamp")
assert(gSet1.lookup([4:4]) == nil, "Expect nil if item was not added")

// MARK: Set compare tests
gSet2.add([2:2], timestamp: timestamps[0])
gSet2.add([3:3], timestamp: timestamps[2])

assert(gSet1.compare(anotherSet: gSet1) == true, "Expect sets to be subsets of themselves")
assert(LWWGrowSet<DictonaryValue>().compare(anotherSet: gSet1) == true, "Expect empty sets to always be subsets")
assert(gSet1.compare(anotherSet: gSet2) == false, "Expect set 1 not to be a subset of set 2") // Set 1 has the extra element 1
assert(gSet2.compare(anotherSet: gSet1) == true, "Expect set 1 to be a subset of set 2")

// MARK: Set compare tests
gSet2.add([4:4], timestamp: timestamps[0])
gSet1.merge(anotherSet: gSet2)

assert(gSet1.lookup([1:1]) == timestamps[0], "Expect item not in the other set to be unchanged")
assert(gSet1.lookup([2:2]) == timestamps[1], "Expect item timestamps to be correct - should not be updated if timestamp in the other set was before this set's entry")
assert(gSet1.lookup([3:3]) == timestamps[2], "Expect item timestamps to be correct - should be updated if timestamp in the other set was after this set's entry")
assert(gSet1.lookup([4:4]) == timestamps[0], "Expect item to be added if it was not present")
assert(gSet1.lookup([5:5]) == nil, "Expect nil if item was not in both sets")


// MARK: LWW Element set tests
var lwwESet1 = LWWElementSet<DictonaryValue>()
var lwwESet2 = LWWElementSet<DictonaryValue>()

// MARK: Single set tests
lwwESet1.remove([1:1], timestamp: timestamps[3])
assert(lwwESet1.lookup([1:1]) == nil, "Expect item not to be added or removed if the item is not already in the set")

lwwESet1.add([1:1], timestamp: timestamps[1])
assert(lwwESet1.lookup([1:1]) == timestamps[1], "Expect timestamp to be returned if item was added")

lwwESet1.add([1:1], timestamp: timestamps[0])
assert(lwwESet1.lookup([1:1]) == timestamps[1], "Expect timestamp not to be updated if an item was added with an older timestamp")

lwwESet1.remove([1:1], timestamp: timestamps[0])
assert(lwwESet1.lookup([1:1]) == timestamps[1], "Expect item not to be removed if it was added again after")

lwwESet1.remove([1:1], timestamp: timestamps[1])
assert(lwwESet1.lookup([1:1]) == nil, "Expect item to be removed if it was removed at exactly the same time as it was added")

lwwESet1.add([1:1], timestamp: timestamps[2])
assert(lwwESet1.lookup([1:1]) == timestamps[2], "Expect item to be present if it was added after it was removed")

lwwESet1.remove([1:1], timestamp: timestamps[3])
assert(lwwESet1.lookup([1:1]) == nil, "Expect item to be removed if it was removed after it was added")

// MARK: Set compare tests
// Set up set 2
lwwESet2.add([1:1], timestamp: timestamps[0])
lwwESet2.remove([1:1], timestamp: timestamps[5])
lwwESet2.add([2:2], timestamp: timestamps[1])
lwwESet2.remove([2:2], timestamp: timestamps[0])

assert(lwwESet1.compare(anotherSet: lwwESet1) == true, "Expect sets to be subsets of themselves")
assert(LWWElementSet<DictonaryValue>().compare(anotherSet: lwwESet1) == true, "Expect empty sets to always be subsets")
assert(lwwESet1.compare(anotherSet: lwwESet2) == true, "Expect set 1 to be a subset of set 2")
assert(lwwESet2.compare(anotherSet: lwwESet1) == false, "Expect set 1 not to be a subset of set 2") // Set 2 has the extra element 2
// MARK: Set merge tests
lwwESet1.add([1:1], timestamp: timestamps[4])
lwwESet1.merge(anotherSet: lwwESet2)

assert(lwwESet1.lookup([1:1]) == nil, "Expect item that was added in one set and removed later in another to be removed")
assert(lwwESet1.lookup([2:2]) == timestamps[1], "Expect item to be added if it was not present")

// MARK: Dictionary update tests
lwwESet1.add([4:4], timestamp: timestamps[5])
lwwESet1.updateForDict([4:4], with: [4:5])

assert(lwwESet1.lookup([4:4]) == nil, "Expect item that was added in one set is updated to new item")
assert(lwwESet1.lookup([4:5]) == timestamps[5], "Expect updated item to be present on same time stamp of original item")
