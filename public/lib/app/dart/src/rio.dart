// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file

import 'dart:typed_data';

import 'package:fidl/fidl.dart';
import 'package:zircon/zircon.dart';

// WARNING: RIO is deprecated; this code will be replaced with
// FIDL bindings soon.
void rioConnectToService(
    Channel directory, Channel request, String servicePath) {
  int pathLen = servicePath.length + (8 - servicePath.length % 8);
  final ByteData byteData = new ByteData(48 + pathLen);

  // struct zxrio_msg {
  //   zx_txid_t txid;
  //   uint32_t reserved0;
  //   uint32_t flags;
  //   uint32_t ordinal;
  //   uint32_t flags;
  //   uint32_t mode;
  //   uint64_t path_size;
  //   uintptr_t path_data;
  //   zx_handle_t object;
  //   uint32_t reserved;
  //   uint8_t[] path;
  // };

  final List<Handle> handles = <Handle>[];
  int offset = 0;

  // txid -> 0
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;

  // reserved0 -> 0
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;

  // flags -> 0
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;

  // ordinal -> ZXFIDL_OPEN
  byteData.setUint32(offset, 0x77E4CCEB, Endian.little);
  offset += 4;

  // flags -> ZX_FS_RIGHT_READABLE | ZX_FS_RIGHT_WRITABLE
  byteData.setInt32(offset, 0x00000003, Endian.little);
  offset += 4;

  // mode -> 0
  byteData.setInt32(offset, 0, Endian.little);
  offset += 4;

  // path_size -> length of servicePath
  byteData.setUint64(offset, servicePath.length, Endian.little);
  offset += 8;

  // path_marker
  byteData.setUint64(offset, kAllocPresent, Endian.little);
  offset += 8;

  // object
  handles.add(request.handle);
  byteData.setUint32(offset, kHandlePresent, Endian.little);
  offset += 4;

  // reserved
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;

  // data.
  for (int i = 0; i < servicePath.length; i++) {
    // TODO(ZX-1358) This would not work for non-ASCII. This will be
    // fixed when we move to FIDL.
    byteData.setUint8(offset, servicePath.codeUnitAt(i));
    offset += 1;
  }

  final int status = directory.write(byteData, handles);
  assert(status == ZX.OK);
}
