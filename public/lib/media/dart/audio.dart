// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_media/fidl_async.dart';
import 'package:fidl_fuchsia_media_audio/fidl_async.dart';
import 'package:fuchsia_services/services.dart';
import 'package:fuchsia_logger/logger.dart';

/// Type for |Audio| update callbacks.
typedef UpdateCallback = void Function();

/// System audio.
/// TODO: Persist audio changes in the device settings.
class Audio {
  static const double _minLevelGainDb = -60.0;
  static const double _unityGainDb = 0.0;
  static const double _initialGainDb = -12.0;

  // These values determine what counts as a 'significant' change when deciding
  // whether to call |updateCallback|.
  static const double _minDbDiff = 0.006;
  static const double _minPerceivedDiff = 0.0001;

  final AudioProxy _audioService = AudioProxy();

  double _systemAudioGainDb = _initialGainDb;
  bool _systemAudioMuted = false;
  double _systemAudioPerceivedLevel = gainToLevel(_initialGainDb);

  /// Constructs an Audio object.
  Audio() {
    try {
      StartupContext.fromStartupInfo().incoming.connectToService(_audioService);
    } on Exception catch (error) {
      log.severe('Unable to connect to audio service', error);
    }

    _audioService.systemGainMuteChanged.forEach(_handleGainMuteChanged);
  }

  /// Called when properties have changed significantly.
  UpdateCallback updateCallback;

  /// Disposes this object.
  void dispose() {
    if (_audioService.ctrl.isClosed) {
      log.warning('Audio service is already closed');
      return;
    }

    _audioService.ctrl.close();
  }

  /// Gets the system-wide audio gain in decibels. Gain values are in the range
  /// -160db to 0db inclusive.
  double get systemAudioGainDb => _systemAudioGainDb;

  /// Sets the system-wide audio gain in db. |value| is clamped to the range
  /// -160db to 0db inclusive. When gain is set to -160db, |systemAudioMuted| is
  /// implicitly set to true. When gain is changed from -160db to a higher
  /// value, |systemAudioMuted| is implicitly set to false.
  Future<void> setSystemAudioGainDb(double value) async {
    double clampedValue = value.clamp(mutedGainDb, _unityGainDb);
    if (_systemAudioGainDb == clampedValue) {
      return;
    }

    _systemAudioGainDb = clampedValue;
    _systemAudioPerceivedLevel = gainToLevel(clampedValue);

    if (_systemAudioGainDb == mutedGainDb) {
      _systemAudioMuted = true;
    }

    await _audioService
        .setSystemGain(_systemAudioGainDb)
        .catchError((_) => log.warning('Could not set the audio system gain.'));
  }

  /// Gets system-wide audio muted state. |systemAudioMuted| is always true
  /// when |systemAudioGainDb| is -160db.
  bool get systemAudioMuted => _systemAudioMuted;

  /// Sets system-wide audio muted state. Setting this value to false when
  /// |systemAudioGainDb| is -160db has no effect.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setSystemAudioMuted(bool value) async {
    bool muted = value || _systemAudioGainDb == mutedGainDb;
    if (_systemAudioMuted == muted) {
      return;
    }

    _systemAudioMuted = muted;
    await _audioService.setSystemMute(_systemAudioMuted);
  }

  /// Gets the perceived system-wide audio level in the range [0,1]. This value
  /// is intended to be used for volume sliders. If there is no separate mute
  /// control, use (systemAudioMuted ? 0.0 : systemAudioPerceivedLevel).
  double get systemAudioPerceivedLevel => _systemAudioPerceivedLevel;

  /// Sets the perceived system-wide audio level in the range [0,1]. When this
  /// property is set to 0.0, |systemAudioGainDb| is set to -160db.
  Future<void> setSystemAudioPerceivedLevel(double value) async {
    _systemAudioPerceivedLevel = value.clamp(0.0, 1.0);
    _systemAudioGainDb = levelToGain(_systemAudioPerceivedLevel);

    await _audioService.setSystemGain(_systemAudioGainDb);
  }

  // Handles a status update from the audio service.
  void _handleGainMuteChanged(Audio$SystemGainMuteChanged$Response response) {
    bool callUpdate = _systemAudioMuted != response.muted ||
        (_systemAudioGainDb - response.gainDb).abs() > _minDbDiff;

    _systemAudioGainDb = response.gainDb;
    _systemAudioMuted = response.muted;

    double newPerceivedLevel = gainToLevel(_systemAudioGainDb);
    if ((_systemAudioPerceivedLevel - newPerceivedLevel).abs() >
        _minPerceivedDiff) {
      _systemAudioPerceivedLevel = newPerceivedLevel;
      callUpdate = true;
    }

    if (callUpdate && updateCallback != null) {
      updateCallback();
    }
  }

  void setRoutingPolicy(AudioOutputRoutingPolicy policy) {
    _audioService.setRoutingPolicy(policy);
  }

  /// Converts a gain in db to an audio 'level' in the range 0.0 to 1.0
  /// inclusive.
  static double gainToLevel(double gainDb) {
    if (gainDb <= _minLevelGainDb) {
      return 0.0;
    }

    if (gainDb >= _unityGainDb) {
      return 1.0;
    }

    return 1.0 - gainDb / _minLevelGainDb;
  }

  /// Converts an audio 'level' in the range 0.0 to 1.0 inclusive to a gain in
  /// db.
  static double levelToGain(double level) {
    if (level <= 0.0) {
      return mutedGainDb;
    }

    if (level >= 1.0) {
      return _unityGainDb;
    }

    return (1.0 - level) * _minLevelGainDb;
  }
}
