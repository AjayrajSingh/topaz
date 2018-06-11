// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file

import 'dart:typed_data';

import 'package:zircon/zircon.dart';

void rioConnectToService(
    Channel directory, Channel request, String servicePath) {
  final ByteData byteData = new ByteData(56 + servicePath.length);

  // struct zxrio_msg {
  //   zx_txid_t txid;
  //   uint32_t reserved0;
  //   uint32_t flags;
  //   uint32_t op;
  //   uint32_t datalen;
  //   int32_t arg;
  //   union {
  //     int64_t off;
  //     uint32_t mode;
  //     uint32_t op;
  //   } arg2;
  //   int32_t reserved1;
  //   uint32_t hcount;
  //   zx_handle_t handle[4];
  //   uint8_t data[8192];
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

  // op -> ZXRIO_OPEN
  byteData.setUint32(offset, 0x103, Endian.little);
  offset += 4;

  // datalen -> length of servicePath
  byteData.setUint32(offset, servicePath.length, Endian.little);
  offset += 4;

  // arg -> ZX_FS_RIGHT_READABLE | ZX_FS_RIGHT_WRITABLE
  byteData.setInt32(offset, 0x00000003, Endian.little);
  offset += 4;

  // arg2 -> 493 (inside a 64 bit union)
  byteData.setUint32(offset, 493, Endian.little);
  offset += 4;
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;

  // reserved1 -> 0
  byteData.setInt32(offset, 0, Endian.little);
  offset += 4;

  // hcount -> 1
  byteData.setUint32(offset, 1, Endian.little);
  offset += 4;

  // handle[4]. The actual handle values don't matter.
  byteData.setUint32(offset, 0xFFFFFFFFF, Endian.little);
  handles.add(request.handle);
  offset += 4;
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;
  byteData.setUint32(offset, 0, Endian.little);
  offset += 4;
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
