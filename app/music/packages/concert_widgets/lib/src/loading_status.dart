// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Loading status for network requests
enum LoadingStatus {
  /// The request is currently in progress
  inProgress,

  /// The request has failed
  failed,

  /// The request has completed
  completed,
}
