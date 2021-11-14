import 'dart:collection';

class Cache<K, V> {
  Cache(this.limit);

  final int limit;

  final LinkedHashMap<K, V> _internal = LinkedHashMap<K, V>();

  void remove(K key) => _internal.remove;

  V? operator [](K key) {
    final val = _internal[key];

    if (val != null) {
      _internal.remove(key);
      _internal[key] = val;
    }

    return val;
  }

  void operator []=(K key, V val) {
    _internal[key] = val;

    if (_internal.length > limit) {
      _internal.remove(_internal.values.first);
    }
  }

  V doCache(K key, V Function() f) {
    if (_internal.containsKey(key)) {
      return this[key]!;
    }

    final val = f();
    this[key] = val;
    return val;
  }
}
