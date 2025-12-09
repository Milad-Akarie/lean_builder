import 'dart:collection' show HashMap;

/// {@template source_based_cache}
/// A simple cache that uses two units as key, one for the source and one for the target.
///
/// This cache allows storing and retrieving values based on a source-target pair,
/// making it useful for invalidating all values for a given source.
/// {@endtemplate}
class SourceBasedCache<T> {
  /// Internal storage for the cached values.
  final HashMap<String, Map<String, T>> _cache = HashMap<String, Map<String, T>>();

  /// {@template source_based_cache.cache}
  /// Adds a value to the cache for the given source and target.
  ///
  /// @param source The source identifier
  /// @param target The target identifier
  /// @param value The value to cache
  /// @return The cached value
  /// {@endtemplate}
  T cache(String source, String target, T value) {
    return _cache.putIfAbsent(source, () => <String, T>{})[target] = value;
  }

  /// {@template source_based_cache.get}
  /// Retrieves a value from the cache for the given source and target.
  ///
  /// @param source The source identifier
  /// @param target The target identifier
  /// @return The cached value, or null if not found
  /// {@endtemplate}
  T? get(String source, String target) {
    return _cache[source]?[target];
  }

  /// {@template source_based_cache.contains}
  /// Checks if a value exists in the cache for the given compound key.
  ///
  /// @param key The compound key to check
  /// @return true if the key exists in the cache
  /// {@endtemplate}
  bool contains(CompoundKey key) {
    return _cache[key.source]?.containsKey(key.source) ?? false;
  }

  /// {@template source_based_cache.key_for}
  /// Creates a compound key for the given source and target.
  ///
  /// @param source The source identifier
  /// @param target The target identifier
  /// @return A compound key representing the source-target pair
  /// {@endtemplate}
  CompoundKey keyFor(String source, String target) {
    return CompoundKey(source, target);
  }

  /// {@template source_based_cache.operator_brackets}
  /// Retrieves a value from the cache using a compound key.
  ///
  /// @param key The compound key to look up
  /// @return The cached value, or null if not found
  /// {@endtemplate}
  T? operator [](CompoundKey key) {
    return _cache[key.source]?[key.target];
  }

  /// {@template source_based_cache.operator_brackets_equals}
  /// Adds a value to the cache using a compound key.
  ///
  /// @param key The compound key for the value
  /// @param value The value to cache
  /// {@endtemplate}
  void operator []=(CompoundKey key, T value) {
    _cache.putIfAbsent(key.source, () => <String, T>{})[key.target] = value;
  }

  /// {@template source_based_cache.put_if_absent}
  /// Adds a value to the cache for the given key if it doesn't already exist.
  ///
  /// @param key The compound key for the value
  /// @param value Function that produces the value to cache
  /// @return The existing or newly cached value
  /// {@endtemplate}
  T putIfAbsent(CompoundKey key, T Function() value) {
    return _cache.putIfAbsent(key.source, () => <String, T>{})[key.target] ??= value();
  }

  /// {@template source_based_cache.cache_key}
  /// Adds a value to the cache using a compound key.
  ///
  /// @param key The compound key for the value
  /// @param value The value to cache
  /// @return The cached value
  /// {@endtemplate}
  T cacheKey(CompoundKey key, T value) {
    return cache(key.source, key.target, value);
  }

  /// {@template source_based_cache.remove}
  /// Removes a value from the cache for the given compound key.
  ///
  /// If removing the value makes the source map empty, the source entry
  /// is also removed from the cache.
  ///
  /// @param key The compound key to remove
  /// {@endtemplate}
  void remove(CompoundKey key) {
    if (_cache.containsKey(key.source)) {
      _cache[key.source]?.remove(key.target);
      if (_cache[key.source]?.isEmpty ?? true) {
        _cache.remove(key.source);
      }
    }
  }

  /// {@template source_based_cache.clear}
  /// Removes all values from the cache.
  /// {@endtemplate}
  void clear() {
    _cache.clear();
  }

  /// {@template source_based_cache.invalidate_for_source}
  /// Removes all values from the cache for the given source.
  ///
  /// @param source The source identifier to invalidate
  /// {@endtemplate}
  void invalidateForSource(String source) {
    _cache.remove(source);
  }

  @override
  String toString() {
    return 'SourceBasedCache{_cache: $_cache}';
  }
}

/// {@template compound_key}
/// A key composed of two string identifiers: source and target.
///
/// Used for looking up values in a [SourceBasedCache] based on a pair
/// of identifiers that together uniquely identify a cached value.
/// {@endtemplate}
class CompoundKey {
  /// {@template compound_key.source}
  /// The source identifier part of this key.
  /// {@endtemplate}
  final String source;

  /// {@template compound_key.target}
  /// The target identifier part of this key.
  /// {@endtemplate}
  final String target;

  /// {@template compound_key.constructor}
  /// Creates a new compound key with the given source and target identifiers.
  ///
  /// @param source The source identifier
  /// @param target The target identifier
  /// {@endtemplate}
  const CompoundKey(this.source, this.target);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompoundKey && runtimeType == other.runtimeType && source == other.source && target == other.target;

  @override
  int get hashCode => source.hashCode ^ target.hashCode;
}
