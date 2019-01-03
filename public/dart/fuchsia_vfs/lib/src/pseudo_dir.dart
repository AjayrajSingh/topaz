// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fidl/fidl.dart' as fidl;
import 'package:fidl_fuchsia_io/fidl_async.dart';
import 'package:quiver/collection.dart';
import 'package:zircon/zircon.dart';

import 'vnode.dart';

/// A [PseudoDir] is a directory-like object whose entries are constructed
/// by a program at runtime.  The client can lookup, enumerate, and watch these
/// directory entries but it cannot create, remove, or rename them.
///
/// This class is designed to allow programs to publish a relatively small number
/// of entries (up to a few hundreds) such as services, file-system roots,
/// debugging [PseudoFile].
///
/// This version doesn't support watchers, should support watchers if needed.
class PseudoDir extends Vnode {
  final HashMap<String, _Entry> _entries = HashMap();
  final AvlTreeSet<_Entry> _treeEntries =
      AvlTreeSet(comparator: (v1, v2) => v1.nodeId.compareTo(v2.nodeId));
  int _nextId = 1;
  final List<_DirConnection> _connections = [];

  /// Adds a directory entry associating the given [name] with [node].
  /// It is ok to add the same Vnode multiple times with different names.
  ///
  /// Returns `ZX.OK` on success.
  /// Returns `ZX.ERR_INVALID_ARGS` if name length is more than `maxFilename`.
  /// Returns `ZX.ERR_ALREADY_EXISTS` if there is already a node with the
  /// given name.
  int addNode(String name, Vnode node) {
    if (name.length > maxFilename) {
      return ZX.ERR_INVALID_ARGS;
    }
    if (_entries.containsKey(name)) {
      return ZX.ERR_ALREADY_EXISTS;
    }
    var id = _nextId++;
    var e = _Entry(node, name, id);
    _entries[name] = e;
    _treeEntries.add(e);
    return ZX.OK;
  }

  /// Connects to this instance of [PseudoDir] and serves
  /// [fushsia.io.Directory] over fidl.
  @override
  int connect(int flags, int mode, fidl.InterfaceRequest<Node> request,
      [int parentFlags = -1]) {
    // There should be no modeType* flags set, except for, possibly,
    // modeTypeDirectory when the target is a pseudo dir.
    if ((mode & ~modeProtectionMask) & ~modeTypeDirectory != 0) {
      sendErrorEvent(flags, ZX.ERR_INVALID_ARGS, request);
      return ZX.ERR_INVALID_ARGS;
    }

    // ignore parentFlags as every directory is readable even if flag is not passed.
    var status = _validateFlags(flags);
    if (status != ZX.OK) {
      sendErrorEvent(flags, status, request);
      return status;
    }
    var connection = _DirConnection(
        mode, flags, this, fidl.InterfaceRequest(request.passChannel()));

    _connections.add(connection);
    return ZX.OK;
  }

  @override
  int inodeNumber() {
    return inoUnknown;
  }

  /// Checks if directory is empty.
  bool isEmpty() {
    return _entries.isEmpty;
  }

  /// Returns names of the the nodes present in this directory.
  List<String> listNodeNames() {
    return _treeEntries.map((f) => f.name).toList();
  }

  /// Looks up a node for given `name`.
  ///
  /// Returns `null` if no node if found.
  Vnode lookup(String name) {
    var v = _entries[name];
    if (v != null) {
      return v.node;
    }
    return null;
  }

  @override
  void open(
      int flags, int mode, String path, fidl.InterfaceRequest<Node> request) {
    var p = path.trim();
    if (p.startsWith('/')) {
      sendErrorEvent(flags, ZX.ERR_BAD_PATH, request);
      return;
    }
    if (p == '' || p == '.') {
      connect(flags, mode, request);
    }
    var index = p.indexOf('/');
    var key = '';
    if (index == -1) {
      key = p;
    } else {
      key = p.substring(0, index);
    }
    if (_entries.containsKey(key)) {
      var e = _entries[key];
      // final element, open it
      if (index == -1) {
        e.node.connect(flags, mode, request);
      } else if (index == p.length - 1) {
        // '/' is at end, should be a directory, add flag
        e.node.connect(flags | openFlagDirectory, mode, request);
      } else {
        // forward request to child Vnode and let it handle rest of path.
        e.node.open(flags, mode, p.substring(index + 1), request);
      }
    }
  }

  /// Removes all directory entries.
  void removeAllNodes() {
    _entries.clear();
    _treeEntries.clear();
  }

  /// Removes a directory entry with the given `name`.
  ///
  /// Returns `ZX.OK` on success.
  /// Returns `ZX.RR_NOT_FOUND` if there is no node with the given name.
  int removeNode(String name) {
    var e = _entries.remove(name);
    if (e == null) {
      return ZX.ERR_NOT_FOUND;
    }
    _treeEntries.remove(e);
    return ZX.OK;
  }

  @override
  int type() {
    return direntTypeDirectory;
  }

  void _onClose(_DirConnection obj) {
    assert(_connections.remove(obj));
  }

  int _validateFlags(int flags) {
    var allowedFlags = openRightReadable |
        openRightWritable |
        openFlagDirectory |
        openFlagDescribe;
    var prohibitedFlags = openFlagCreate |
        openFlagCreateIfAbsent |
        openFlagTruncate |
        openFlagAppend;

    // TODO(ZX-3251) : do not allow openRightWritable.

    // Pseudo directories do not allow mounting, at this point.
    if (flags & openRightAdmin != 0) {
      return ZX.ERR_ACCESS_DENIED;
    }
    if (flags & prohibitedFlags != 0) {
      return ZX.ERR_INVALID_ARGS;
    }
    if (flags & ~allowedFlags != 0) {
      return ZX.ERR_NOT_SUPPORTED;
    }
    return ZX.OK;
  }
}

/// Implementation of fuchsia.io.Directory for pseudo directory.
///
/// This class should not be used directly, but by [fuchsia_vfs.PseudoDirectory].
class _DirConnection extends Directory {
  final DirectoryBinding _binding = DirectoryBinding();

  // reference to current Directory object;
  PseudoDir _dir;
  int _mode;
  int _flags;

  /// Position in directory where [#readDirents] should start searching. If less
  /// than 0, means first entry should be dot('.').
  ///
  /// All the entires in [PseudoDir] are greater then 0.
  /// We will get key after `_seek` and traverse in the TreeMap.
  int _seek = -1;

  bool _closed = false;

  /// Constructor
  _DirConnection(this._mode, this._flags, this._dir,
      fidl.InterfaceRequest<Directory> request)
      : assert(_dir != null),
        assert(request != null) {
    _binding.bind(this, request);
    _binding.whenClosed.then((_) {
      return close();
    });
  }

  @override
  Stream<Directory$OnOpen$Response> get onOpen {
    if ((_flags & openFlagDescribe) == 0) {
      return null;
    }
    NodeInfo nodeInfo = _describe();
    var d = Directory$OnOpen$Response(ZX.OK, nodeInfo);
    return Stream.fromIterable([d]);
  }

  @override
  Future<void> clone(int flags, fidl.InterfaceRequest<Node> object) async {
    _dir.connect(flags, _mode, object);
  }

  @override
  Future<int> close() async {
    if (_closed) {
      return ZX.OK;
    }
    _dir._onClose(this);
    _closed = true;

    return ZX.OK;
  }

  @override
  Future<NodeInfo> describe() async {
    return _describe();
  }

  @override
  Future<Directory$GetAttr$Response> getAttr() async {
    var n = NodeAttributes(
      mode: modeTypeDirectory | modeProtectionMask,
      id: inoUnknown,
      contentSize: 0,
      storageSize: 0,
      linkCount: 1,
      creationTime: 0,
      modificationTime: 0,
    );
    return Directory$GetAttr$Response(ZX.OK, n);
  }

  @override
  Future<Directory$GetToken$Response> getToken() async {
    return Directory$GetToken$Response(ZX.ERR_NOT_SUPPORTED, null);
  }

  @override
  Future<Directory$Ioctl$Response> ioctl(
      int opcode, int maxOut, List<Handle> handles, Uint8List in$) async {
    return Directory$Ioctl$Response(ZX.ERR_NOT_SUPPORTED, null, null);
  }

  @override
  Future<int> link(String src, Handle dstParentToken, String dst) async {
    return ZX.ERR_NOT_SUPPORTED;
  }

  @override
  Future<void> open(int flags, int mode, String path,
      fidl.InterfaceRequest<Node> object) async {
    _dir.open(flags, mode, path, object);
  }

  @override
  Future<Directory$ReadDirents$Response> readDirents(int maxBytes) async {
    var buf = Uint8List(maxBytes);
    var bData = ByteData.view(buf.buffer);
    var firstOne = true;
    var index = 0;

    // add dot
    if (_seek < 0) {
      var bytes = _encodeDirent(
          bData, index, maxBytes, inoUnknown, direntTypeDirectory, '.');
      if (bytes == -1) {
        return Directory$ReadDirents$Response(
            ZX.ERR_BUFFER_TOO_SMALL, Uint8List(0));
      }
      firstOne = false;
      index += bytes;
      _seek = 0;
    }

    var status = ZX.OK;

    // add entries
    var entry = _dir._treeEntries.nearest(_Entry(null, '', _seek),
        nearestOption: TreeSearch.GREATER_THAN);

    if (entry != null) {
      var iterator = _dir._treeEntries.fromIterator(entry);
      while (iterator.moveNext()) {
        entry = iterator.current;
        // we should only send entries > _seek
        if (entry.nodeId <= _seek) {
          continue;
        }
        var bytes = _encodeDirent(bData, index, maxBytes,
            entry.node.inodeNumber(), entry.node.type(), entry.name);
        if (bytes == -1) {
          if (firstOne) {
            status = ZX.ERR_BUFFER_TOO_SMALL;
          }
          break;
        }
        firstOne = false;
        index += bytes;
        status = ZX.OK;
        _seek = entry.nodeId;
      }
    }
    return Directory$ReadDirents$Response(
        status, Uint8List.view(buf.buffer, 0, index));
  }

  @override
  Future<int> rename(String src, Handle dstParentToken, String dst) async {
    return ZX.ERR_NOT_SUPPORTED;
  }

  @override
  Future<int> rewind() async {
    _seek = -1;
    return ZX.OK;
  }

  @override
  Future<int> setAttr(int flags, NodeAttributes attributes) async {
    return ZX.ERR_NOT_SUPPORTED;
  }

  @override
  Future<int> sync() async {
    return ZX.ERR_NOT_SUPPORTED;
  }

  @override
  Future<int> unlink(String path) async {
    return ZX.ERR_NOT_SUPPORTED;
  }

  @override
  Future<int> watch(int mask, int options, Channel watcher) async {
    return ZX.ERR_NOT_SUPPORTED;
  }

  NodeInfo _describe() {
    return NodeInfo.withDirectory(DirectoryObject(reserved: 0));
  }

  /// returns number of bytes written
  int _encodeDirent(ByteData buf, int startIndex, int maxBytes, int inodeNumber,
      int type, String name) {
    List<int> charBytes = utf8.encode(name);
    var len = 8 /*ino*/ + 1 /*size*/ + 1 /*type*/ + charBytes.length;
    // cannot fit in buffer
    if (maxBytes - startIndex < len) {
      return -1;
    }
    var index = startIndex;
    buf.setUint64(index, inodeNumber, Endian.little);
    index += 8;
    buf..setUint8(index++, charBytes.length)..setUint8(index++, type);
    for (int i = 0; i < charBytes.length; i++) {
      buf.setUint8(index++, charBytes[i]);
    }
    return len;
  }
}

/// _Entry class to store in pseudo directory.
class _Entry {
  /// Vnode
  Vnode node;

  /// node name
  String name;

  /// node id: defines insertion order
  int nodeId;

  /// Constructor
  _Entry(this.node, this.name, this.nodeId);
}
