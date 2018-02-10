// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:matcher/matcher.dart';
import 'package:matcher/src/util.dart';
import 'package:test/src/frontend/expect.dart';
import 'package:test/test.dart';

// TODO(youngseokyoon): consider putting this file under //apps/test_runner.

final Future<Null> _emptyFuture = new Future<Null>.value();

/// Assert that [actual] matches [matcher].
///
/// This version of [expect] function is a reduced version which doesn't require
/// an enclosing `test()` method. This version doesn't support an async matcher.
void expect(
  Object actual,
  Object matcher, {
  String reason,
}) {
  _expect(actual, matcher, reason: reason);
}

Future<Null> _expect(
  Object actual,
  Matcher matcher, {
  String reason,
}) {
  Matcher effectiveMatcher = wrapMatcher(matcher);

  dynamic matchState = <dynamic, dynamic>{};
  try {
    if (effectiveMatcher.matches(actual, matchState)) {
      return _emptyFuture;
    }
  } on Exception catch (e, trace) {
    reason ??= '$e at $trace';
  }
  fail(_format(actual, effectiveMatcher, reason, matchState, false));
}

String _format(
  Object actual,
  Matcher matcher,
  String reason,
  Object matchState,
  bool verbose,
) {
  Object mismatchDescription = new StringDescription();
  matcher.describeMismatch(actual, mismatchDescription, matchState, verbose);

  // ignore: deprecated_member_use
  return formatFailure(matcher, actual, mismatchDescription.toString(),
      reason: reason);
}
