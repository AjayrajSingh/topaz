// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_media/fidl_async.dart' as media;

/// Immutable rate of a subject timeline with respect to a reference timeline
/// (subject / reference) expressed as the ratio of two ints.
class TimelineRate {
  /// The change in subject time that correlates to referenceDelta.
  final int subjectDelta;

  /// The change in reference time that correlates to subjectDelta. May not
  /// be zero.
  final int referenceDelta;

  // A multiplier for float-to-TimelineRate conversions chosen because doubles
  // have a 52-bit mantissa.
  static const int _floatFactor = 1 << 52;

  /// Constructs a TimelineRate from a subject delta and a reference delta.
  factory TimelineRate({
    int subjectDelta = 0,
    int referenceDelta = 1,
  }) {
    assert(referenceDelta != 0);
    int gcd = subjectDelta.gcd(referenceDelta);
    return TimelineRate._(subjectDelta ~/ gcd, referenceDelta ~/ gcd);
  }

  /// Constructs a TimelineRate from a double.
  factory TimelineRate.fromDouble(double asDouble) {
    if (asDouble > 1.0) {
      return TimelineRate(
        subjectDelta: _floatFactor,
        referenceDelta: (_floatFactor * asDouble).toInt(),
      );
    } else {
      return TimelineRate(
        subjectDelta: _floatFactor ~/ asDouble,
        referenceDelta: _floatFactor,
      );
    }
  }

  /// Internal constructor.
  const TimelineRate._(this.subjectDelta, this.referenceDelta);

  /// A rate of 0 / 1.
  static const TimelineRate zero = TimelineRate._(0, 1);

  /// The number of nanoseconds in a second.
  static const TimelineRate nanosecondsPerSecond =
      TimelineRate._(1000000000, 1);

  /// The inverse of this rate. Asserts if this.subjectDelta is zero.
  TimelineRate get inverse => TimelineRate(
        subjectDelta: referenceDelta,
        referenceDelta: subjectDelta,
      );

  /// Returns the product of this TimelineRate with another TimelineRate.
  TimelineRate product(TimelineRate other) => TimelineRate(
        subjectDelta: subjectDelta * other.subjectDelta,
        referenceDelta: referenceDelta * other.referenceDelta,
      );

  /// Returns the product of this TimelineRate with an int as an int.
  int operator *(int value) => (value * subjectDelta) ~/ referenceDelta;

  @override
  int get hashCode => subjectDelta.hashCode ^ referenceDelta.hashCode;

  @override
  bool operator ==(Object other) =>
      other is TimelineRate &&
      subjectDelta == other.subjectDelta &&
      referenceDelta == other.referenceDelta;

  @override
  String toString() => '$subjectDelta/$referenceDelta';
}

/// Immutable linear function that produces a subject time from a reference
/// time.
class TimelineFunction {
  /// The subject time that corresponds to referenceTime.
  final int subjectTime;

  /// The reference time that corresponds to subjectTime.
  final int referenceTime;

  /// The slope of the function (subject / reference).
  final TimelineRate rate;

  /// Constructs a TimelineFunction from a pair of correlated values and a
  /// TimelineRate.
  const TimelineFunction({
    this.subjectTime = 0,
    this.referenceTime = 0,
    this.rate = TimelineRate.zero,
  });

  /// Constructs a TimelineFunction from a FIDL TimelineFunction struct.
  TimelineFunction.fromFidl(media.TimelineFunction timelineFunction)
      : subjectTime = timelineFunction.subjectTime,
        referenceTime = timelineFunction.referenceTime,
        rate = TimelineRate(
          subjectDelta: timelineFunction.subjectDelta,
          referenceDelta: timelineFunction.referenceDelta,
        );

  /// The change in subject time that correlates to referenceDelta.
  int get subjectDelta => rate.subjectDelta;

  /// The change in reference time that correlates to subjectDelta. Never zero.
  int get referenceDelta => rate.referenceDelta;

  /// Applies the function to an int.
  int call(int referenceInput) => apply(referenceInput);

  /// Applies the function to an int.
  int apply(int referenceInput) =>
      rate * (referenceInput - referenceTime) + subjectTime;

  /// Applies the inverse of the function to an int. Asserts if subjectDelta is
  /// zero.
  int applyInverse(int subjectInput) {
    assert(rate.subjectDelta != 0);
    return rate.inverse * (subjectInput - subjectTime) + referenceTime;
  }

  /// Gets the inverse of this function. sserts if subjectDelta is zero.
  TimelineFunction get inverse {
    assert(rate.subjectDelta != 0);
    return TimelineFunction(
      subjectTime: referenceTime,
      referenceTime: subjectTime,
      rate: rate.inverse,
    );
  }

  /// Composes this TimelineFunction with another TimelineFunction.
  TimelineFunction operator *(TimelineFunction other) => TimelineFunction(
        subjectTime: apply(other.subjectTime),
        referenceTime: other.referenceTime,
        rate: rate.product(other.rate),
      );

  @override
  int get hashCode =>
      subjectTime.hashCode ^ referenceTime.hashCode ^ rate.hashCode;

  @override
  bool operator ==(Object other) =>
      other is TimelineFunction &&
      subjectTime == other.subjectTime &&
      referenceTime == other.referenceTime &&
      rate == other.rate;

  @override
  String toString() => '$subjectTime:$referenceTime@$rate';
}
