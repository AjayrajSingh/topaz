// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_media/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:settings_protos/audio.pb.dart' as stored_audio;
import 'package:settings_protos/setting_store.dart';
import 'package:settings_protos/setting_store_factory.dart';

/// Type for |Audio| update callbacks.
typedef UpdateCallback = void Function();

/// System audio.
class Audio {
  static const double _minLevelGainDb = -60.0;
  static const double _unityGainDb = 0.0;
  static const double _initialGainDb = -12.0;

  // These values determine what counts as a 'significant' change when deciding
  // whether to call |updateCallback|.
  static const double _minDbDiff = 0.006;
  static const double _minPerceivedDiff = 0.0001;

  final AudioProxy _audioService = new AudioProxy();

  double _systemAudioGainDb = _initialGainDb;
  bool _systemAudioMuted = false;
  double _systemAudioPerceivedLevel = gainToLevel(_initialGainDb);

  SettingStore<stored_audio.Audio> _store;

  /// Constructs an Audio object.
  Audio(ServiceProvider services) {
    connectToService(services, _audioService.ctrl);
    _audioService.ctrl.onConnectionError = _handleConnectionError;
    _audioService.ctrl.error
        .then((ProxyError error) => _handleConnectionError(error: error));
    _audioService.systemGainMuteChanged = _handleGainMuteChanged;
    _store = new SettingStoreFactory(services).createAudioStore()
      ..addlistener(_onSettingChanged)
      ..connect();
  }

  /// Called when properties have changed significantly.
  UpdateCallback updateCallback;

  void _onSettingChanged(stored_audio.Audio value) {
    systemAudioGainDb = value.gain;
    systemAudioMuted = value.muted;
  }

  /// Disposes this object.
  void dispose() {
    _audioService.ctrl.close();
  }

  /// Gets the system-wide audio gain in decibels. Gain values are in the range
  /// -160db to 0db inclusive.
  double get systemAudioGainDb => _systemAudioGainDb;

  /// Sets the system-wide audio gain in db. |value| is clamped to the range
  /// -160db to 0db inclusive. When gain is set to -160db, |systemAudioMuted| is
  /// implicitly set to true. When gain is changed from -160db to a higher
  /// value, |systemAudioMuted| is implicitly set to false.
  set systemAudioGainDb(double value) {
    double clampedValue = value.clamp(mutedGainDb, _unityGainDb);
    if (_systemAudioGainDb == clampedValue) {
      return;
    }

    _systemAudioGainDb = clampedValue;
    _systemAudioPerceivedLevel = gainToLevel(clampedValue);

    if (_systemAudioGainDb == mutedGainDb) {
      _systemAudioMuted = true;
    }

    _audioService.setSystemGain(_systemAudioGainDb);
  }

  /// Gets system-wide audio muted state. |systemAudioMuted| is always true
  /// when |systemAudioGainDb| is -160db.
  bool get systemAudioMuted => _systemAudioMuted;

  /// Sets system-wide audio muted state. Setting this value to false when
  /// |systemAudioGainDb| is -160db has no effect.
  set systemAudioMuted(bool value) {
    bool muted = value || _systemAudioGainDb == mutedGainDb;
    if (_systemAudioMuted == muted) {
      return;
    }

    _systemAudioMuted = muted;
    _audioService.setSystemMute(_systemAudioMuted);

    _persistUserSetting();
  }

  void _persistUserSetting() {
    final stored_audio.Audio audio = new stored_audio.Audio()
      ..clear()
      ..muted = _systemAudioMuted
      ..gain = _systemAudioGainDb;
    _store.commit(audio);
  }

  /// Gets the perceived system-wide audio level in the range [0,1]. This value
  /// is intended to be used for volume sliders. If there is no separate mute
  /// control, use (systemAudioMuted ? 0.0 : systemAudioPerceivedLevel).
  double get systemAudioPerceivedLevel => _systemAudioPerceivedLevel;

  /// Sets the perceived system-wide audio level in the range [0,1]. When this
  /// property is set to 0.0, |systemAudioGainDb| is set to -160db.
  set systemAudioPerceivedLevel(double value) {
    _systemAudioPerceivedLevel = value.clamp(0.0, 1.0);
    _systemAudioGainDb = levelToGain(_systemAudioPerceivedLevel);

    _persistUserSetting();
    _audioService.setSystemGain(_systemAudioGainDb);
  }

  // Handles a status update from the audio service. Call with
  // kInitialStatus, null to initiate status updates.
  void _handleGainMuteChanged(double gainDb, bool muted) {
    bool callUpdate = _systemAudioMuted != muted ||
        (_systemAudioGainDb - gainDb).abs() > _minDbDiff;

    _systemAudioGainDb = gainDb;
    _systemAudioMuted = muted;

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

  /// Handles connection error to the audio service.
  void _handleConnectionError({ProxyError error}) {
    log.severe('Unable to connect to audio service', error);
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
