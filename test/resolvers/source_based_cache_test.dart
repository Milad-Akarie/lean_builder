import 'package:lean_builder/src/resolvers/source_based_cache.dart';
import 'package:test/test.dart';

void main() {
  group('SourceBasedCache', () {
    late SourceBasedCache<String> cache;

    setUp(() {
      cache = SourceBasedCache<String>();
    });

    test('should cache and retrieve values', () {
      cache.cache('source1', 'target1', 'value1');
      expect(cache.get('source1', 'target1'), equals('value1'));
    });

    test('should return null for non-existent values', () {
      expect(cache.get('source1', 'target1'), isNull);
    });

    test('should cache multiple values for same source', () {
      cache.cache('source1', 'target1', 'value1');
      cache.cache('source1', 'target2', 'value2');
      
      expect(cache.get('source1', 'target1'), equals('value1'));
      expect(cache.get('source1', 'target2'), equals('value2'));
    });

    test('should cache values for different sources', () {
      cache.cache('source1', 'target1', 'value1');
      cache.cache('source2', 'target1', 'value2');
      
      expect(cache.get('source1', 'target1'), equals('value1'));
      expect(cache.get('source2', 'target1'), equals('value2'));
    });

    test('should create compound key', () {
      final key = cache.keyFor('source1', 'target1');
      expect(key.source, equals('source1'));
      expect(key.target, equals('target1'));
    });

    test('should use bracket operator to get values', () {
      cache.cache('source1', 'target1', 'value1');
      final key = CompoundKey('source1', 'target1');
      expect(cache[key], equals('value1'));
    });

    test('should use bracket operator to set values', () {
      final key = CompoundKey('source1', 'target1');
      cache[key] = 'value1';
      expect(cache[key], equals('value1'));
    });

    test('should cache using compound key', () {
      final key = CompoundKey('source1', 'target1');
      cache.cacheKey(key, 'value1');
      expect(cache[key], equals('value1'));
    });

    test('should put if absent when value does not exist', () {
      final key = CompoundKey('source1', 'target1');
      final result = cache.putIfAbsent(key, () => 'value1');
      
      expect(result, equals('value1'));
      expect(cache[key], equals('value1'));
    });

    test('should not replace existing value with putIfAbsent', () {
      final key = CompoundKey('source1', 'target1');
      cache[key] = 'value1';
      
      final result = cache.putIfAbsent(key, () => 'value2');
      
      expect(result, equals('value1'));
      expect(cache[key], equals('value1'));
    });

    test('should remove value by compound key', () {
      final key = CompoundKey('source1', 'target1');
      cache[key] = 'value1';
      
      expect(cache[key], equals('value1'));
      cache.remove(key);
      expect(cache[key], isNull);
    });

    test('should handle removing non-existent key', () {
      final key = CompoundKey('source1', 'target1');
      expect(() => cache.remove(key), returnsNormally);
    });

    test('should remove source entry when last target is removed', () {
      final key1 = CompoundKey('source1', 'target1');
      final key2 = CompoundKey('source1', 'target2');
      
      cache[key1] = 'value1';
      cache[key2] = 'value2';
      
      cache.remove(key1);
      expect(cache[key1], isNull);
      expect(cache[key2], equals('value2'));
      
      cache.remove(key2);
      expect(cache[key2], isNull);
    });

    test('should clear all values', () {
      cache.cache('source1', 'target1', 'value1');
      cache.cache('source2', 'target2', 'value2');
      
      cache.clear();
      
      expect(cache.get('source1', 'target1'), isNull);
      expect(cache.get('source2', 'target2'), isNull);
    });

    test('should invalidate all values for a source', () {
      cache.cache('source1', 'target1', 'value1');
      cache.cache('source1', 'target2', 'value2');
      cache.cache('source2', 'target1', 'value3');
      
      cache.invalidateForSource('source1');
      
      expect(cache.get('source1', 'target1'), isNull);
      expect(cache.get('source1', 'target2'), isNull);
      expect(cache.get('source2', 'target1'), equals('value3'));
    });

    test('should have correct toString', () {
      cache.cache('source1', 'target1', 'value1');
      final str = cache.toString();
      expect(str, contains('SourceBasedCache'));
    });
  });

  group('CompoundKey', () {
    test('should create compound key', () {
      final key = CompoundKey('source1', 'target1');
      expect(key.source, equals('source1'));
      expect(key.target, equals('target1'));
    });

    test('should implement equality correctly', () {
      final key1 = CompoundKey('source1', 'target1');
      final key2 = CompoundKey('source1', 'target1');
      
      expect(key1, equals(key2));
      expect(key1.hashCode, equals(key2.hashCode));
    });

    test('should not be equal with different source', () {
      final key1 = CompoundKey('source1', 'target1');
      final key2 = CompoundKey('source2', 'target1');
      
      expect(key1, isNot(equals(key2)));
    });

    test('should not be equal with different target', () {
      final key1 = CompoundKey('source1', 'target1');
      final key2 = CompoundKey('source1', 'target2');
      
      expect(key1, isNot(equals(key2)));
    });

    test('should be equal to itself', () {
      final key = CompoundKey('source1', 'target1');
      expect(key, equals(key));
    });
  });
}
