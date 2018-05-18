// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

/// The node of the [PrefixTree], it contains a reference to its label, value,
/// children, and whether or not a word ends at this node.
///
/// For each key-value pair that is inserted into the PrefixTree, the value is
/// stored in a node but the full key is not.
///
/// Instead, the node stores a 'label' that can be the entire key or a suffix of
/// the key.
/// The full key for the node is derived from joining the labels from the
/// root down to this node.
class _Node<T> {
  final List<_Node<T>> children = <_Node<T>>[];
  T value;
  String label;
  bool isWord;

  _Node({this.label, this.value, this.isWord = false});

  @override
  String toString() {
    return '( label: "$label", is word: $isWord, value: $value )';
  }
}

/// Contains the node path from the root to a specified key.
/// Also contains whether or not the key is contained in the path.
///
/// If the key is not contained in the path, [keyIndex] and [lastNodeIndex] will
/// point to the code unit where the key and the last node's label diverged.
class _TreePath<T> {
  /// Nodes in order from root, where the root is at index 0
  final List<_Node<T>> nodes = <_Node<T>>[];
  final String key;
  int keyIndex;
  int lastNodeIndex;

  _TreePath({
    this.key,
    this.lastNodeIndex,
    this.keyIndex,
  });

  _Node<T> get lastNodeParent {
    return nodes.isEmpty || nodes.length < 2 ? null : nodes[nodes.length - 2];
  }

  _Node<T> get lastNode => nodes.isEmpty ? null : nodes.last;

  void removeLastNode() {
    nodes.removeLast();
  }

  /// True if the path contains the entire key and the last node is a word
  bool get containsKey {
    return (lastNodeIndex == lastNode.label.length &&
        keyIndex == key.length &&
        lastNode.isWord);
  }
}

/// A Compressed [PrefixTree] implementation where the key is a [String] and the
/// value is a generic.
///
/// The tree is case sensitive, meaning "Abc" and "abc" are treated as distinct
/// keys.
class PrefixTree<T> {
  final _Node<T> _root = new _Node<T>(label: '', value: null);

  /// Set the specified key value pair, will update the value if the key
  /// already exists in the tree.
  void operator []=(String key, T value) {
    _validateKey(key);
    _insert(key, value);
  }

  /// Retrieve the value associated with the key.
  T operator [](String key) {
    if (!_isValidKey(key)) {
      return null;
    } else {
      _TreePath<T> path = _getPathToKey(key);
      return path.containsKey ? path.lastNode.value : null;
    }
  }

  /// Determine if the tree contains the given key.
  bool containsKey(String key) {
    return this[key] != null;
  }

  /// Adds a node to the tree if it is absent.
  void putIfAbsent(String key, T ifAbsent()) {
    _validateKey(key);

    if (!containsKey(key)) {
      _insert(key, ifAbsent());
    }
  }

  /// Remove the key and its value from the tree.
  void remove(String key) {
    _validateKey(key);

    _TreePath<T> path = _getPathToKey(key);
    if (path.containsKey) {
      // we found the key and can simply remove it if it doesn't have children
      if (path.lastNode.children.isEmpty) {
        path.lastNodeParent.children.remove(path.lastNode);
        path.removeLastNode();

        // traverse back up the parent tree and remove non-word nodes that have
        // no children
        while (path.nodes.isNotEmpty &&
            !path.nodes.last.isWord &&
            path.nodes.last.children.isEmpty) {
          if (path.nodes.length > 1) {
            path.nodes[path.nodes.length - 2].children.remove(path.nodes.last);
          }
          path.removeLastNode();
        }
      } else {
        // it has children, so let's leave it in place and no longer mark it as
        // a word
        path.lastNode.isWord = false;
      }
    }
  }

  /// Search for nodes matching the prefix, if the prefix is an empty string
  /// it will return all key value pairs in the tree.
  SplayTreeMap<String, T> search(String prefix) {
    SplayTreeMap<String, T> results;
    if (prefix != null) {
      results = new SplayTreeMap<String, T>();
      _TreePath<T> path = _getPathToKey(prefix);
      int prefixCharsThatOverlap = path.keyIndex;
      if (prefixCharsThatOverlap == prefix.length) {
        // The entire prefix is contained within the path of nodes
        String fullPrefix =
            '$prefix${path.lastNode.label.substring(path.lastNodeIndex)}';
        results.addAll(_getAllKeysInSubtree(fullPrefix, path.lastNode));
      }
    }
    return results;
  }

  /// Retrieves all the key value pairs in the subtree at n.
  ///
  /// Appends the prefix to all the nodes that are words to derive their keys.
  /// [prefix] includes the label of [_Node] n.
  SplayTreeMap<String, T> _getAllKeysInSubtree(String prefix, _Node<T> n) {
    SplayTreeMap<String, T> results = new SplayTreeMap<String, T>();
    for (_Node<T> child in n.children) {
      results.addAll(_getAllKeysInSubtree('$prefix${child.label}', child));
    }
    if (n.isWord) {
      results[prefix] = n.value;
    }
    return results;
  }

  bool _isValidKey(String key) => (key != null && key.isNotEmpty);

  /// Checks that the key is valid otherwise throws an [ArgumentError]
  void _validateKey(String key) {
    if (!_isValidKey(key)) {
      throw new ArgumentError('PrefixTree key cannot be null or empty');
    }
  }

  /// Retrieves the path of nodes that match the prefix of key or matches the
  /// key entirely.
  _TreePath<T> _getPathToKey(String key) {
    _TreePath<T> treePath = new _TreePath<T>(key: key);
    _Node<T> curr = _root;
    int currNodeIndex = 0;
    int keyIndex = 0;
    bool hasNext = true;

    while (hasNext) {
      hasNext = false;

      // Find overlap with current node
      while (currNodeIndex < curr.label.length &&
          keyIndex < key.length &&
          curr.label[currNodeIndex] == key[keyIndex]) {
        currNodeIndex++;
        keyIndex++;
      }

      // No longer any overlapping characters with the current node's label,
      // determine if there is a child that overlaps with the remainder of key
      if (currNodeIndex == curr.label.length && keyIndex < key.length) {
        for (_Node<T> child in curr.children) {
          if (child.label[0] == key[keyIndex]) {
            treePath.nodes.add(curr);
            curr = child;
            currNodeIndex = 0;
            hasNext = true;
          }
        }
      }
    }
    treePath
      ..nodes.add(curr)
      ..lastNodeIndex = currNodeIndex
      ..keyIndex = keyIndex;

    return treePath;
  }

  void _insert(String key, T value) {
    _TreePath<T> path = _getPathToKey(key);
    _Node<T> prev = path.lastNodeParent;
    _Node<T> curr = path.lastNode;
    int keyCharsCompared = path.keyIndex;
    int currNodeIndex = path.lastNodeIndex;

    // No longer any overlapping characters, we can insert the new node
    if (currNodeIndex == curr.label.length) {
      if (keyCharsCompared == key.length) {
        // This key already exists, we will update its value
        curr
          ..value = value
          ..isWord = true;
      } else {
        // New key is longer than current node's label, we can add as a child
        _Node<T> newNode = new _Node<T>(
          label: key.substring(keyCharsCompared),
          value: value,
          isWord: true,
        );
        curr.children.add(newNode);
      }
    } else {
      if (keyCharsCompared == key.length) {
        // The new key is a prefix of the current node
        _Node<T> newNode = new _Node<T>(
          label: curr.label.substring(0, currNodeIndex),
          value: value,
          isWord: true,
        );
        curr.label = curr.label.substring(currNodeIndex);
        newNode.children.add(curr);
        prev.children.remove(curr);
        prev.children.add(newNode);
      } else {
        // The new key and the current node share a prefix
        _Node<T> sharedPrefixNode = new _Node<T>(
          label: curr.label.substring(0, currNodeIndex),
          value: null,
        );
        _Node<T> newNode = new _Node<T>(
          label: key.substring(keyCharsCompared),
          value: value,
          isWord: true,
        );
        curr.label = curr.label.substring(currNodeIndex);
        sharedPrefixNode.children.add(curr);
        sharedPrefixNode.children.add(newNode);
        prev.children.remove(curr);
        prev.children.add(sharedPrefixNode);
      }
    }
  }

  @override
  String toString() {
    StringBuffer stringBuffer = new StringBuffer()..write('{ ');

    ListQueue<_Node<T>> q = new ListQueue<_Node<T>>()..add(_root);
    while (q.isNotEmpty) {
      _Node<T> curr = q.removeFirst();
      curr.children.forEach(q.add);
      stringBuffer.write('${curr.toString()} ');
    }
    stringBuffer.write('}');

    return stringBuffer.toString();
  }
}
