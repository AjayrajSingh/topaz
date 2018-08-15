// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:contacts_content_provider/store.dart';
import 'package:test/test.dart';

/// Key value pair class to help with tests
class _KVP<K, V> {
  final K key;
  final V value;

  _KVP({this.key, this.value});
}

/// Common function to test remove cases
void _testRemove(
  List<_KVP<String, int>> keyValuePairs,
  _KVP<String, int> target,
) {
  // Add key value pairs and check that all are present
  PrefixTree<int> testTree = new PrefixTree<int>();
  for (_KVP<String, int> kvp in keyValuePairs) {
    testTree[kvp.key] = kvp.value;
  }
  for (_KVP<String, int> kvp in keyValuePairs) {
    expect(testTree[kvp.key], equals(kvp.value));
  }

  // Remove target node
  testTree.remove(target.key);

  // Check that the rest are still present
  for (_KVP<String, int> kvp in keyValuePairs) {
    if (kvp != target) {
      expect(testTree[kvp.key], equals(kvp.value));
    }
  }
}

void main() {
  group('PrefixTree', () {
    // A tree populated with lots of values for retrieval and search tests
    PrefixTree<String> trieTree;
    List<_KVP<String, String>> trieTreeKVPs;

    setUp(() {
      trieTree = new PrefixTree<String>();
      trieTreeKVPs = <_KVP<String, String>>[
        new _KVP<String, String>(key: ' ', value: '-ay?'),
        new _KVP<String, String>(key: 'to', value: 'o-tay'),
        new _KVP<String, String>(key: 'hallway', value: 'allway-hay'),
        new _KVP<String, String>(key: 'toe', value: 'oe-tay'),
        new _KVP<String, String>(key: 'tomato', value: 'omato-tay'),
        new _KVP<String, String>(key: 'hail', value: 'ail-hay'),
        new _KVP<String, String>(key: 'hall', value: 'all-hay'),
        new _KVP<String, String>(key: 'test', value: 'est-tay'),
        new _KVP<String, String>(key: 'water', value: 'ater-way'),
        new _KVP<String, String>(key: 'Haiti', value: 'aiti-Hay'),
      ];
      for (_KVP<String, String> kvp in trieTreeKVPs) {
        trieTree[kvp.key] = kvp.value;
      }
    });

    tearDown(() {
      trieTreeKVPs = null;
      trieTree = null;
    });

    group('[] operator assignment', () {
      test('should throw argument error if key is null', () {
        expect(() {
          PrefixTree<int> emptyTree = new PrefixTree<int>();
          emptyTree[null] = 1;
        }, throwsA(const TypeMatcher<ArgumentError>()));
      });

      test('should throw argument error if key is an empty string', () {
        expect(() {
          PrefixTree<int> emptyTree = new PrefixTree<int>();
          emptyTree[''] = 1;
        }, throwsA(const TypeMatcher<ArgumentError>()));
      });

      test('should add the key value pair if they didn\'t exist', () {
        PrefixTree<int> testTree = new PrefixTree<int>();
        String key = 'one';
        expect(testTree[key], isNull);
        testTree[key] = 1;
        expect(testTree[key], equals(1));
      });

      test('should replace existing value if key exists', () {
        PrefixTree<int> testTree = new PrefixTree<int>();
        String key = 'two';
        expect(testTree[key], isNull);
        testTree[key] = 2;
        expect(testTree[key], equals(2));

        testTree[key] = 22;
        expect(testTree[key], equals(22));
      });

      test('should mark intermediate node as a word', () {
        PrefixTree<int> testTree = new PrefixTree<int>();
        testTree['totally'] = 1;
        testTree['tonality'] = 2;
        expect(testTree.containsKey('to'), isFalse);
        expect(testTree['to'], isNull);

        testTree['to'] = 3;
        expect(testTree.containsKey('to'), isTrue);
        expect(testTree['to'], 3);
      });
    });

    group('[] operator retrieval', () {
      test('should return null if the key is an empty string', () {
        PrefixTree<String> testTree = new PrefixTree<String>();
        expect(testTree[''], isNull);
      });

      test('should return null if the key is null', () {
        PrefixTree<String> testTree = new PrefixTree<String>();
        expect(testTree[null], isNull);
      });

      test('should return the value if the key exists', () {
        PrefixTree<String> testTree = new PrefixTree<String>();
        String key = 'apple';
        String value = 'fruit';
        expect(testTree.containsKey(key), isFalse);

        testTree[key] = value;
        expect(testTree[key], equals(value));
      });

      test('should return null if it doesn\'t contain the key', () {
        PrefixTree<String> testTree = new PrefixTree<String>();
        expect(testTree['apple'], isNull);
      });

      test('should be able to retrieve all inserted keys', () {
        for (_KVP<String, String> kvp in trieTreeKVPs) {
          expect(trieTree[kvp.key], equals(kvp.value));
        }
      });

      test('should return correct value if key is prefix of other words', () {
        expect(trieTree['to'], equals('o-tay'));
      });

      test('should return null if node exists but is not a word', () {
        expect(trieTree['t'], isNull);
        expect(trieTree['ha'], isNull);
      });
    });

    group('containsKey', () {
      test('should return true if the key exists', () {
        PrefixTree<String> testTree = new PrefixTree<String>();
        String key = 'apple';
        testTree['apple'] = 'pie';

        expect(testTree.containsKey(key), isTrue);
      });

      test('should return false if the key doesn\'t exist', () {
        PrefixTree<String> testTree = new PrefixTree<String>();
        String key = 'apple';

        expect(testTree.containsKey(key), isFalse);
      });

      test('should return false if the key is null', () {
        PrefixTree<String> testTree = new PrefixTree<String>();
        expect(testTree.containsKey(null), isFalse);
      });

      test('should return false if the key is empty', () {
        PrefixTree<String> testTree = new PrefixTree<String>();
        expect(testTree.containsKey(''), isFalse);
      });
    });

    group('putIfAbsent', () {
      test('should throw if key is null', () {
        expect(() {
          new PrefixTree<double>().putIfAbsent(null, () => 0.0);
        }, throwsA(const TypeMatcher<ArgumentError>()));
      });

      test('should throw if key is empty', () {
        expect(() {
          new PrefixTree<double>().putIfAbsent('', () => 0.0);
        }, throwsA(const TypeMatcher<ArgumentError>()));
      });

      test('should add key and value if they are not in the tree', () {
        PrefixTree<double> testTree = new PrefixTree<double>()
          ..putIfAbsent('pi', () => 3.14);
        expect(testTree['pi'], equals(3.14));
      });

      test('should not add the new value if the key is present', () {
        PrefixTree<double> testTree = new PrefixTree<double>();
        String key = 'pi';
        double value = 3.14;
        double newValue = 3.14159;
        testTree.putIfAbsent(key, () => value);
        expect(testTree[key], equals(value));

        testTree.putIfAbsent(key, () => newValue);
        expect(testTree[key], equals(value));
      });
    });

    group('remove', () {
      test('should throw if key is null', () {
        expect(() {
          new PrefixTree<double>().remove(null);
        }, throwsA(const TypeMatcher<ArgumentError>()));
      });

      test('should throw if key is empty', () {
        expect(() {
          new PrefixTree<double>().remove('');
        }, throwsA(const TypeMatcher<ArgumentError>()));
      });

      group('existing keys', () {
        test('should remove if the key is the only value', () {
          PrefixTree<int> testTree = new PrefixTree<int>();
          String seven = 'seven';
          testTree[seven] = 7;
          expect(testTree.containsKey(seven), isTrue);

          testTree.remove(seven);
          expect(testTree.containsKey(seven), isFalse);
        });

        List<_KVP<String, int>> keyValuePairs = <_KVP<String, int>>[
          new _KVP<String, int>(key: 'seven', value: 7),
          new _KVP<String, int>(key: 'seventeen', value: 17),
          new _KVP<String, int>(key: 'seventy', value: 70),
          new _KVP<String, int>(key: 'seventy-one', value: 71),
          new _KVP<String, int>(key: 'seventy-two', value: 72),
          new _KVP<String, int>(key: 'seven-hundred', value: 700),
        ];

        test('should remove if the key is the root', () {
          _testRemove(keyValuePairs, keyValuePairs[0]); //seven
        });

        test('should remove if the key is a inner node', () {
          _testRemove(keyValuePairs, keyValuePairs[2]); // seventy
        });

        test('should remove if the key is a leaf', () {
          _testRemove(keyValuePairs, keyValuePairs[3]); // seventy-one
        });

        test('should be able to remove all keys', () {
          PrefixTree<int> testTree = new PrefixTree<int>();
          for (_KVP<String, int> kvp in keyValuePairs) {
            testTree[kvp.key] = kvp.value;
          }

          // Check that all are present
          for (_KVP<String, int> kvp in keyValuePairs) {
            expect(testTree[kvp.key], equals(kvp.value));
          }

          for (_KVP<String, int> kvp in keyValuePairs) {
            testTree.remove(kvp.key);
          }

          Map<String, int> contents = testTree.search('');
          expect(contents, isEmpty);
        });
      });

      test('should do nothing if the key doesn\'t exist', () {
        PrefixTree<double> testTree = new PrefixTree<double>();
        String pi = 'pi';
        testTree.putIfAbsent(pi, () => 3.14);
        expect(testTree[pi], equals(3.14));

        // Check that the tree doesn't contain the key we're removing
        expect(testTree.containsKey('e'), isFalse);
        testTree.remove('e');

        // Check that the contents of the tree are untouched
        expect(testTree[pi], equals(3.14));
      });
    });

    group('search', () {
      test('should return null if prefix is null', () {
        Map<String, String> results = trieTree.search(null);
        expect(results, isNull);
      });

      test('should return everything if prefix is an empty string', () {
        Map<String, String> results = trieTree.search('');
        expect(results, hasLength(trieTreeKVPs.length));
        for (_KVP<String, String> kvp in trieTreeKVPs) {
          expect(results[kvp.key], equals(kvp.value));
        }
      });

      group('matches word that is not a prefix', () {
        test('should return 1 result if key is contained in a single node', () {
          PrefixTree<String> testTree = new PrefixTree<String>();
          testTree['hello'] = 'world';
          testTree['goodbye'] = 'to the world';

          Map<String, String> result = testTree.search('hello');
          expect(result, hasLength(1));
          expect(result['hello'], equals('world'));
        });

        test('should return 1 result if key is spread across nodes', () {
          Map<String, String> result = trieTree.search('tomato');
          expect(result, hasLength(1));
          expect(result['tomato'], equals('omato-tay'));
        });
      });

      test('should return return all keys that match the prefix', () {
        Map<String, String> results = trieTree.search('to');
        expect(results, hasLength(3));
        expect(results.containsKey('to'), isTrue);
        expect(results.containsKey('toe'), isTrue);
        expect(results.containsKey('tomato'), isTrue);
      });

      test('should return an empty map if nothing matches prefix', () {
        Map<String, String> result = trieTree.search('=====');
        expect(result, hasLength(0));
      });

      test('should be case sensitive', () {
        Map<String, String> results = trieTree.search('Ha');
        expect(results, hasLength(1));
        expect(results.containsKey('Haiti'), isTrue);

        Map<String, String> lowerCaseResults = trieTree.search('ha');
        expect(lowerCaseResults, hasLength(3));
        expect(lowerCaseResults.containsKey('hall'), isTrue);
        expect(lowerCaseResults.containsKey('hallway'), isTrue);
        expect(lowerCaseResults.containsKey('hail'), isTrue);
      });
    });

    test('should be case sensitive', () {
      PrefixTree<int> testTrie = new PrefixTree<int>();
      testTrie['true'] = 1;
      testTrie['True'] = 2;
      testTrie.putIfAbsent('TRUE', () => 3);

      expect(testTrie['true'], equals(1));
      expect(testTrie['True'], equals(2));
      expect(testTrie['TRUE'], equals(3));

      testTrie.remove('True');
      expect(testTrie.containsKey('true'), isTrue);
      expect(testTrie.containsKey('True'), isFalse);
      expect(testTrie.containsKey('TRUE'), isTrue);
    });
  });
}
