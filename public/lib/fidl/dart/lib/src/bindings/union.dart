// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of bindings;

// ignore_for_file: public_member_api_docs

// ignore: one_member_abstracts
abstract class Union {
  const Union();
  void encode(Encoder encoder, int offset);
}

class UnionError extends Error {}

class UnsetUnionTagError extends UnionError {
  final dynamic curTag;
  final dynamic requestedTag;

  UnsetUnionTagError(this.curTag, this.requestedTag);

  @override
  String toString() => 'Tried to read unset union member: $requestedTag '
      'current member: $curTag.';
}
