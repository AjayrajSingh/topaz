// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;
import 'package:fidl/fidl.dart' as fidl;

class FakePageWatcherInterfaceHandle
    extends fidl.InterfaceHandle<ledger.PageWatcher> {
  ledger.PageWatcher _pageWatcher;
  FakePageWatcherInterfaceHandle(this._pageWatcher) : super(null);

  Future<fidl.InterfaceRequest<ledger.PageSnapshot>> onChange(
      ledger.PageChange pageChange, ledger.ResultState resultState) {
    return _pageWatcher.onChange(pageChange, resultState);
  }
}

class FakePageWatcherBinding extends ledger.PageWatcherBinding {
  @override
  fidl.InterfaceHandle<ledger.PageWatcher> wrap(
      ledger.PageWatcher pageWatcher) {
    return FakePageWatcherInterfaceHandle(pageWatcher);
  }
}
