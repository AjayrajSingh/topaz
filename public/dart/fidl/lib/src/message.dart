// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:zircon/zircon.dart';

// ignore_for_file: public_member_api_docs

const int kMessageHeaderSize = 16;
const int kMessageTxidOffset = 0;
const int kMessageOrdinalOffset = 12;

class Message {
  Message(this.data, this.handles, this.dataLength, this.handlesLength);
  Message.fromReadResult(ReadResult result)
      : data = result.bytes,
        handles = result.handles,
        dataLength = result.bytes.lengthInBytes,
        handlesLength = result.handles.length,
        assert(result.status == ZX.OK);

  final ByteData data;
  final List<Handle> handles;
  final int dataLength;
  final int handlesLength;

  int get txid => data.getUint32(kMessageTxidOffset, Endian.little);
  set txid(int value) =>
      data.setUint32(kMessageTxidOffset, value, Endian.little);

  int get ordinal => data.getUint32(kMessageOrdinalOffset, Endian.little);
  set ordinal(int value) =>
      data.setUint32(kMessageOrdinalOffset, value, Endian.little);

  void hexDump() {
    Uint8List list = new Uint8List.view(data.buffer, 0);
    StringBuffer buffer = new StringBuffer();
    for (int i = 0; i < list.length; ++i) {
      if (i > 0) {
        if (i % 8 == 0)
          buffer.write(' ');
        if (i % 32 == 0)
          buffer.write('\n');
      }
      int v = list[i];
      String s = v.toRadixString(16);
      if (s.length == 1)
        buffer.write('0$s ');
      else
        buffer.write('$s ');
    }
    print('==================================================\n'
          '$buffer\n'
          '==================================================');
  }

  void closeHandles() {
    if (handles != null) {
      for (int i = 0; i < handles.length; ++i) {
        handles[i].close();
      }
    }
  }

  @override
  String toString() {
    return 'Message(numBytes=$dataLength, numHandles=$handlesLength)';
  }
}

typedef void MessageSink(Message message);
