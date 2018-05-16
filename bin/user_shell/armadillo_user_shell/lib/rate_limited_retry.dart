// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Rate limit (failure count in a time period) for [RateLimitedRetry]. More
/// than [count] retries in a [period] will not be allowed.
class RateThreshold {
  /// The maximum number of retries allowed within a [period].
  final int count;

  /// The time period over which to count retries.
  final Duration period;

  /// Constructs a threshold limiting to [count] retries per [period].
  RateThreshold(this.count, this.period);
}

/// Keeps track of a retry scheme where infinite retries are allowed unless an
/// operation fails many times in a short interval. This can be used to enable a
/// decent user experience in the face of a flaky dependency without undue churn
/// or log spamming if an unrecoverable failure has occurred.
class RateLimitedRetry {
  final RateThreshold _threshold;
  int _failureSeriesCount = 0;
  DateTime _failureSeriesStart;

  /// Constructs a retry tracker where retry should occur as long as no more
  /// than [RateThreshold.count] failures have occurred within a
  /// [RateThreshold.period].
  ///
  /// As an example, an allowance of 1 failure per second will allow retries if
  /// failures occur no more frequently than exactly once every second.
  RateLimitedRetry(this._threshold);

  /// Determines whether a failure should be retried.
  ///
  /// Call when the operation you are tracking fails, to determine whether a
  /// retry should be attempted. Returns false if called more than
  /// [RateThreshold.count] times within a [RateThreshold.period].
  bool get shouldRetry {
    final DateTime now = new DateTime.now();
    if (_failureSeriesCount == 0 ||
        now.difference(_failureSeriesStart) >= _threshold.period) {
      _failureSeriesStart = now;
      _failureSeriesCount = 0;
    }

    if (_failureSeriesCount >= _threshold.count) {
      return false;
    } else {
      ++_failureSeriesCount;
      return true;
    }
  }

  /// Formats a message suitable for logging when [shouldRetry] is false.
  ///
  /// The message is of the form *'$component $failure more than
  /// ${threshold.count} times in ${threshold.period}. $feature disabled.'*
  /// [component] and [feature] will be capitalized appropriately.
  ///
  /// [component] describes the component that failed. [failure] describes the
  /// failure mode (e.g. 'crashed') and defaults to 'failed'. [feature]
  /// describes the feature that will be disabled as a result of the component
  /// having failed and defaults to [component].
  String formatMessage(
      {String component, String failure = 'failed', String feature}) {
    final String capComponent =
        '${component[0].toUpperCase()}${component.substring(1)}';
    final String capFeature = feature == null
        ? capComponent
        : '${feature[0].toUpperCase()}${feature.substring(1)}';

    return '$capComponent $failure more than ${_threshold.count} times in '
        '${_threshold.period}. $capFeature disabled.';
  }
}
