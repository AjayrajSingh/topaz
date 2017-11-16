// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:armadillo/next.dart';
import 'package:lib.suggestion.fidl/suggestion_provider.fidl.dart' as maxwell;
import 'package:lib.suggestion.fidl/speech_to_text.fidl.dart' as maxwell;
import 'package:lib.logging/logging.dart';

/// Listens for a hotword from Maxwell.
class MaxwellHotword extends Hotword with maxwell.HotwordListener {
  static final Duration _kCriticalFailurePeriod = new Duration(seconds: 1);
  static const int _kCriticalFailureCount = 5;

  bool _startPending = false;
  maxwell.SuggestionProviderProxy _suggestionProviderProxy;

  final maxwell.HotwordListenerBinding _hotwordListenerBinding =
      new maxwell.HotwordListenerBinding();

  DateTime _lastFailure;
  int _failureCount;

  /// Sets the suggestion provider proxy. If speech capture had previously been
  /// requested but unable to start due to lack of a suggestion provider, it is
  /// initated.
  set suggestionProvider(
      maxwell.SuggestionProviderProxy suggestionProviderProxy) {
    _suggestionProviderProxy = suggestionProviderProxy;
    if (_startPending) {
      start();
    }
  }

  /// Starts listening for a hotword.
  @override
  void start() {
    if (_suggestionProviderProxy == null) {
      _startPending = true;
    } else if (!_hotwordListenerBinding.isBound) {
      log.info('Listening for hotword');
      _suggestionProviderProxy
          .listenForHotword(_hotwordListenerBinding.wrap(this));
      _hotwordListenerBinding.onConnectionError = () {
        _hotwordListenerBinding.close();

        final DateTime now = new DateTime.now();
        if (_lastFailure == null ||
            now.difference(_lastFailure) >= _kCriticalFailurePeriod) {
          _lastFailure = now;
          _failureCount = 1;
        } else if (_failureCount <= _kCriticalFailureCount) {
          _failureCount++;
        } else {
          log.warning('Speech capture failed more than '
              '$_kCriticalFailureCount times in $_kCriticalFailurePeriod; '
              'disabling hotword detection');
          return;
        }
        start();
      };
      _startPending = false;
    }
  }

  /// Stops listening for a hortword.
  @override
  void stop() {
    if (_hotwordListenerBinding.isBound) {
      log.info('Stopped listening for hotword');
      _hotwordListenerBinding.close();
    }
    _startPending = false;
  }
}
