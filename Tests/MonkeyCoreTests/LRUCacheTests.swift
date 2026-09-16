import Testing

@testable import MonkeyCore

@Suite struct LRUCacheTests {
  @Test func storesAndRetrievesValues() {
    var cache = LRUCache<String, Int>(capacity: 2)
    cache["a"] = 1
    #expect(cache["a"] == 1)
  }

  @Test func evictsLeastRecentlyUsedWhenOverCapacity() {
    var cache = LRUCache<String, Int>(capacity: 2)
    cache["a"] = 1
    cache["b"] = 2
    cache["c"] = 3

    #expect(cache["a"] == nil)
    #expect(cache["b"] == 2)
    #expect(cache["c"] == 3)
  }

  @Test func readingRefreshesRecency() {
    var cache = LRUCache<String, Int>(capacity: 2)
    cache["a"] = 1
    cache["b"] = 2
    _ = cache["a"]
    cache["c"] = 3

    #expect(cache["a"] == 1)
    #expect(cache["b"] == nil)
    #expect(cache["c"] == 3)
  }

  @Test func removeAllClearsEverything() {
    var cache = LRUCache<String, Int>(capacity: 2)
    cache["a"] = 1
    cache.removeAll()
    #expect(cache["a"] == nil)
  }
}
