// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library zircon;

import 'dart:async';
import 'dart:typed_data';

import 'src/mocks/zircon_mocks.dart'
  if (dart.library.zircon) 'dart:zircon';

export 'src/mocks/zircon_mocks.dart'
  if (dart.library.zircon) 'dart:zircon';

part 'src/channel.dart';
part 'src/channel_reader.dart';
part 'src/constants.dart';
part 'src/errors.dart';
part 'src/handle_wrapper.dart';
part 'src/socket.dart';
part 'src/socket_reader.dart';
part 'src/vmo.dart';
