/// A small, bounded least-recently-used cache. Not thread-safe on its own;
/// callers (e.g. an actor) are responsible for serializing access.
struct LRUCache<Key: Hashable, Value> {
  private let capacity: Int
  private var order: [Key] = []
  private var storage: [Key: Value] = [:]

  init(capacity: Int) {
    self.capacity = max(1, capacity)
  }

  subscript(key: Key) -> Value? {
    mutating get {
      guard let value = storage[key] else { return nil }
      touch(key)
      return value
    }
    set {
      guard let newValue else {
        storage.removeValue(forKey: key)
        order.removeAll { $0 == key }
        return
      }
      storage[key] = newValue
      touch(key)
      evictIfNeeded()
    }
  }

  mutating func removeAll() {
    storage.removeAll()
    order.removeAll()
  }

  private mutating func touch(_ key: Key) {
    order.removeAll { $0 == key }
    order.append(key)
  }

  private mutating func evictIfNeeded() {
    while order.count > capacity {
      let oldest = order.removeFirst()
      storage.removeValue(forKey: oldest)
    }
  }
}
