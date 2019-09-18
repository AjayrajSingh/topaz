// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Error thrown due to a bug in Sledge's implementation.
class InternalSledgeError extends Error {
  final String _message;

  /// Default constructor.
  InternalSledgeError(this._message);

  @override
  String toString() => 'Sledge internal error: `$_message`. Please file a bug.';
}
