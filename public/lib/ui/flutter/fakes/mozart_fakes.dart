// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library mozart_fakes;

// ignore_for_file: public_member_api_docs

import 'package:zircon/zircon.dart';

class ScenicStartupInfo {
  static Handle takeViewContainer() {
    return null;
  }
}

class Scenic {
  static void offerServiceProvider(Handle handle, List<String> services) {
    throw new UnimplementedError(
        'offerServiceProvider is not implemented on this platform.');
  }
}
