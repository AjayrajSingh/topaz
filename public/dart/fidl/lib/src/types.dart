// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:zircon/zircon.dart';

import 'error.dart';

// ignore_for_file: public_member_api_docs

void _throwIfNotNullable(bool nullable) {
  if (!nullable) {
    throw new FidlError('Found null for a non-nullable type');
  }
}

void _throwIfExceedsLimit(int count, int limit) {
  if (limit != null && count > limit) {
    throw new FidlError(
        'Found an object wth $count elements. Limited to $limit.');
  }
}

void _throwIfCountMismatch(int count, int expectedCount) {
  if (count != expectedCount) {
    throw new FidlError(
        'Found an array of count $count. Expected $expectedCount.');
  }
}

void _throwIfNotZero(int value) {
  if (value != 0) {
    throw new FidlError('Expected zero, got: $value');
  }
}

const int kAllocAbsent = 0;
const int kAllocPresent = 0xFFFFFFFFFFFFFFFF;
const int kHandleAbsent = 0;
const int kHandlePresent = 0xFFFFFFFF;

class FidlType {
  const FidlType();
}

class HandleType extends FidlType {
  const HandleType({this.nullable});

  final bool nullable;

  void validateEncoded(int encoded) {
    if (encoded == kHandleAbsent) {
      _throwIfNotNullable(nullable);
    } else if (encoded == kHandlePresent) {
      // Nothing to validate.
    } else {
      throw new FidlError('Invalid handle encoding.');
    }
  }
}

class StringType extends FidlType {
  const StringType({
    this.maybeElementCount,
    this.nullable,
  });

  final int maybeElementCount;
  final bool nullable;

  void validate(String value) {
    if (value == null) {
      _throwIfNotNullable(nullable);
      return;
    }
    _throwIfExceedsLimit(value.length, maybeElementCount);
  }

  void validateEncoded(int size, int data) {
    if (data == kHandleAbsent) {
      _throwIfNotNullable(nullable);
      _throwIfNotZero(size);
    } else if (data == kAllocPresent) {
      _throwIfExceedsLimit(size, maybeElementCount);
    } else {
      throw new FidlError('Invalid string encoding.');
    }
  }
}

class PointerType extends FidlType {
  const PointerType({
    this.element,
    this.elementSize,
  });

  final FidlType element;
  final int elementSize;

  void validateEncoded(int encoded) {
    if (encoded != kHandleAbsent && encoded != kHandlePresent) {
      throw new FidlError('Invalid pointer encoding.');
    }
  }
}

class MemberType extends FidlType {
  const MemberType({
    this.type,
    this.offset,
  });

  final FidlType type;
  final int offset;
}

class StructType extends FidlType {
  const StructType({
    this.members,
  });

  final List<MemberType> members;
}

class UnionType extends FidlType {
  const UnionType({
    this.members,
  });

  final List<MemberType> members;
}

class MethodType extends FidlType {
  const MethodType({
    this.members,
  });

  final List<MemberType> members;
}

class VectorType extends FidlType {
  const VectorType({
    this.element,
    this.maybeElementCount,
    this.elementSize,
    this.nullable,
  });

  final FidlType element;
  final int maybeElementCount;
  final int elementSize;
  final bool nullable;

  void validate(List<Object> value) {
    if (value == null) {
      _throwIfNotNullable(nullable);
      return;
    }
    _throwIfExceedsLimit(value.length, maybeElementCount);
  }

  void validateEncoded(int count, int data) {
    if (data == kAllocAbsent) {
      _throwIfNotNullable(nullable);
      _throwIfNotZero(count);
    } else if (data == kAllocPresent) {
      _throwIfExceedsLimit(count, maybeElementCount);
    } else {
      throw new FidlError('Invalid vector encoding.');
    }
  }
}

class ArrayType extends FidlType {
  const ArrayType({
    this.element,
    this.elementCount,
    this.elementSize,
  });

  final FidlType element;
  final int elementCount;
  final int elementSize;

  void validate(List<Object> value) {
    _throwIfCountMismatch(value.length, elementCount);
  }
}
