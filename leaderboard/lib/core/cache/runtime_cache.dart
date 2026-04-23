class RuntimeCacheEntry<T> {
  RuntimeCacheEntry(this.value, this.expiresAt);
  final T value;
  final DateTime expiresAt;
}

class RuntimeCache {
  RuntimeCache._();
  static final RuntimeCache instance = RuntimeCache._();

  final Map<String, RuntimeCacheEntry<dynamic>> _store = {};

  T? get<T>(String key) {
    final item = _store[key];
    if (item == null) return null;
    if (DateTime.now().isAfter(item.expiresAt)) {
      _store.remove(key);
      return null;
    }
    return item.value as T?;
  }

  void put<T>(String key, T value, Duration ttl) {
    _store[key] = RuntimeCacheEntry<T>(
      value,
      DateTime.now().add(ttl),
    );
  }

  void invalidate(String key) {
    _store.remove(key);
  }

  void invalidatePrefix(String prefix) {
    final keys = _store.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      _store.remove(key);
    }
  }

  void clear() {
    _store.clear();
  }
}
