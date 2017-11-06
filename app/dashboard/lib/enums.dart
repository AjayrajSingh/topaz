// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// Enumeration helper class
@immutable
abstract class Enum<T> {
  /// The value of this enum.
  final T value;

  /// The relative order of this enum.
  ///
  /// This can be used for comparison of enum values.
  final int order;

  /// Const constructor.
  @literal
  const Enum(this.value, this.order);
}

/// An [Enum] indicating the status of a build.
///
/// Values are taken from https://github.com/kharland/dart-buildbucket
@immutable
class BuildStatusEnum extends Enum<String> {
  /// Indicates the build is complete.
  static const BuildStatusEnum completed =
      const BuildStatusEnum._('COMPLETED', 0);

  /// Indicates the build is scheduled.
  static const BuildStatusEnum scheduled =
      const BuildStatusEnum._('SCHEDULED', 1);

  /// Indicates the build is started.
  static const BuildStatusEnum started = const BuildStatusEnum._('STARTED', 2);

  @literal
  const BuildStatusEnum._(String name, int value) : super(name, value);

  static final Map<String, BuildStatusEnum> _valueToEnum =
      <String, BuildStatusEnum>{
    completed.value: completed,
    scheduled.value: scheduled,
    started.value: started,
  };

  /// Returns a [BuildStatusEnum] from its [value].
  static BuildStatusEnum from(String value) => _valueToEnum[value];
}

/// An [Enum] Indicating the result of a build.
///
/// Values are taken from https://github.com/kharland/dart-buildbucket
@immutable
class BuildResultEnum extends Enum<String> {
  /// Indicates the build was successful.
  static const BuildResultEnum success = const BuildResultEnum._('SUCCESS', 0);

  /// Indicates the build was cancelled.
  static const BuildResultEnum cancelled =
      const BuildResultEnum._('CANCELLED', 1);

  /// Indicates the build failed.
  static const BuildResultEnum failure = const BuildResultEnum._('FAILURE', 2);

  @literal
  const BuildResultEnum._(String name, int value) : super(name, value);

  static final Map<String, BuildResultEnum> _valueToEnum =
      <String, BuildResultEnum>{
    success.value: success,
    cancelled.value: cancelled,
    failure.value: failure,
  };

  /// Returns a [BuildStatusEnum] from its [value].
  static BuildResultEnum from(String value) => _valueToEnum[value];
}
