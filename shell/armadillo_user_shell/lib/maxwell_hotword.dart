// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia.fidl.speech/speech.dart' as speech;
import 'package:lib.logging/logging.dart';

import 'rate_limited_retry.dart';

/// Listens for a hotword from Maxwell.
abstract class MaxwellHotword extends speech.HotwordListener {
  /// Retry limit for hotword detector failures.
  static final RateThreshold kMaxRetry =
      new RateThreshold(5, new Duration(seconds: 1));

  bool _startPending = false;
  speech.SpeechToTextProxy _speechToText;

  final speech.HotwordListenerBinding _hotwordListenerBinding =
      new speech.HotwordListenerBinding();

  final RateLimitedRetry _retry = new RateLimitedRetry(kMaxRetry);

  /// Sets the speech-to-text proxy. If speech capture had previously been
  /// requested but unable to start due to lack of a provider, it is initated.
  ///
  /// Even if the given proxy is the one already set, hotword listening is
  /// restarted if needed in case the proxy controller has been rebound.
  // TODO(rosswang): Is this really the best way to handle this?
  set speechToText(speech.SpeechToTextProxy speechToText) {
    _speechToText = speechToText;

    bool started = _hotwordListenerBinding.isBound;
    if (started) {
      _hotwordListenerBinding.close();
    }

    if (_startPending || started) {
      start();
    }
  }

  /// Starts listening for a hotword.
  void start() {
    if (_speechToText == null) {
      _startPending = true;
    } else if (!_hotwordListenerBinding.isBound) {
      log.info('Listening for hotword');
      _speechToText.listenForHotword(_hotwordListenerBinding.wrap(this));
      _hotwordListenerBinding.onConnectionError = () {
        onError();
        _hotwordListenerBinding.close();

        if (_retry.shouldRetry) {
          start();
        } else {
          log.warning(_retry.formatMessage(
              component: 'hotword listener', feature: 'hotword detection'));

          onFatal();
        }
      };
      _startPending = false;
    }
  }

  /// Stops listening for a hortword.
  void stop() {
    if (_hotwordListenerBinding.isBound) {
      log.info('Stopped listening for hotword');
      _hotwordListenerBinding.close();
    }
    _startPending = false;
  }

  /// Called when hotword detection encounters a recoverable error.
  void onError();

  /// Called when hotword detection encounters a fatal error.
  void onFatal();
}
