// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.media.dart/timeline.dart';
import 'package:fidl_media_player/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:fidl_component/fidl.dart';
import 'package:fidl_fuchsia_math/fidl.dart' as geom;
import 'package:zircon/zircon.dart';

/// Type for |AudioPlayerController| update callbacks.
typedef UpdateCallback = void Function();

/// Controller for audio-only playback.
class AudioPlayerController {
  final NetMediaServiceProxy _netMediaService = new NetMediaServiceProxy();

  ServiceProvider _services;

  MediaPlayerProxy _mediaPlayer;

  bool _active = false;
  bool _loading = false;
  bool _playing = false;
  bool _ended = false;
  bool _hasVideo = false;
  bool _isRemote = false;

  TimelineFunction _timelineFunction;
  Problem _problem;

  MediaMetadata _metadata;

  bool _progressBarReady = false;
  int _progressBarMicrosecondsSinceEpoch;
  int _progressBarReferenceTime;
  int _durationNanoseconds;

  /// Constructs a AudioPlayerController.
  AudioPlayerController(ServiceProvider services) {
    _services = services;
    _close(); // Initialize stuff.
  }

  /// Called when properties have changed.
  UpdateCallback updateCallback;

  /// Opens a URI for playback. If there is no player or player proxy (because
  /// the controller has never been opened or has been closed), a new local
  /// player will be created. If there is a player or player proxy, the URL
  /// will be set on it. |serviceName| indicates the name under which the
  /// player will be published via NetConnector. It only applies when creating
  /// a new local player. If |serviceName| is not specified, the player will
  /// not be published.
  void open(Uri uri, {String serviceName}) {
    if (uri == null) {
      throw new ArgumentError.notNull('uri');
    }

    if (_active) {
      _mediaPlayer.setHttpSource(uri.toString());
      _hasVideo = false;
      _timelineFunction = null;
    } else {
      _active = true;

      _createLocalPlayer(uri, serviceName);
    }

    if (updateCallback != null) {
      scheduleMicrotask(() {
        updateCallback();
      });
    }
  }

  /// Connects to a remote media player.
  void connectToRemote({String device, String service}) {
    if (device == null) {
      throw new ArgumentError.notNull('device');
    }

    if (service == null) {
      throw new ArgumentError.notNull('service');
    }

    _close();
    _active = true;
    _isRemote = true;

    if (!_netMediaService.ctrl.isBound) {
      connectToService(_services, _netMediaService.ctrl);
    }

    _netMediaService.createMediaPlayerProxy(
        device, service, _mediaPlayer.ctrl.request());
    _mediaPlayer.ctrl.onConnectionError = _handleConnectionError;
    _mediaPlayer.statusChanged = _handleStatusChanged;

    if (updateCallback != null) {
      scheduleMicrotask(() {
        updateCallback();
      });
    }
  }

  /// Closes this controller, undoing a previous |open| or |connectToRemote|
  /// call. Does nothing if the controller is already closed.
  void close() {
    _close();

    if (updateCallback != null) {
      scheduleMicrotask(() {
        updateCallback();
      });
    }
  }

  /// Internal version of |close|.
  void _close() {
    _active = false;
    _isRemote = false;

    if (_mediaPlayer != null) {
      _mediaPlayer.ctrl.close();
      _mediaPlayer.ctrl.onConnectionError = null;
    }

    _mediaPlayer = new MediaPlayerProxy();

    _playing = false;
    _ended = false;
    _loading = true;
    _hasVideo = false;

    _problem = null;
    _metadata = null;

    _progressBarReady = false;
    _durationNanoseconds = 0;
  }

  /// Creates a local player.
  void _createLocalPlayer(Uri uri, String serviceName) {
    connectToService(_services, _mediaPlayer.ctrl);
    _mediaPlayer.statusChanged = _handleStatusChanged;

    onMediaPlayerCreated(_mediaPlayer);

    if (serviceName != null) {
      if (!_netMediaService.ctrl.isBound) {
        connectToService(_services, _netMediaService.ctrl);
      }

      MediaPlayerProxy mediaPlayer = new MediaPlayerProxy();
      _mediaPlayer.addBinding(mediaPlayer.ctrl.request());
      _netMediaService.publishMediaPlayer(
          serviceName, mediaPlayer.ctrl.unbind());
    }

    _mediaPlayer.ctrl.onConnectionError = _handleConnectionError;

    if (uri.isScheme('FILE')) {
      _mediaPlayer.setFileSource(new Channel.fromFile(uri.toFilePath()));
    } else {
      _mediaPlayer.setHttpSource(uri.toString());
    }
  }

  /// Indicates whether the player open or connected (as opposed to closed).
  bool get openOrConnected => _active;

  /// Indicates whether the player is in the process of loading content.
  bool get loading => _loading;

  /// Indicates whether the content has a video stream.
  bool get hasVideo => _hasVideo;

  /// Indicates whether the actual player is local (false) or remote (true).
  bool get isRemote => _isRemote;

  /// Indicates whether the player is currently playing.
  bool get playing => _playing;

  /// Indicates whether the player is at end-of-stream.
  bool get ended => _ended;

  /// Gets the current problem, if there is one. If this value is non-null,
  /// some issue is preventing playback, and this value describes what that
  /// issue is.
  Problem get problem => _problem;

  /// Gets the current content metadata, if any.
  MediaMetadata get metadata => _metadata;

  /// Gets the duration of the content.
  Duration get duration =>
      new Duration(microseconds: _durationNanoseconds ~/ 1000);

  /// Gets current playback progress.
  Duration get progress {
    if (!_progressBarReady) {
      return Duration.zero;
    }

    return new Duration(
        microseconds:
            _progressNanoseconds.clamp(0, _durationNanoseconds) ~/ 1000);
  }

  /// Gets current playback progress normalized to the range 0.0 to 1.0.
  double get normalizedProgress {
    int durationInMicroseconds = duration.inMicroseconds;

    if (durationInMicroseconds == 0) {
      return 0.0;
    }

    return progress.inMicroseconds / durationInMicroseconds;
  }

  /// Gets current playback progress in nanoseconds.
  int get _progressNanoseconds {
    // Estimate FrameInfo::presentationTime.
    if (_timelineFunction == null) {
      return 0;
    }

    int microseconds = (new DateTime.now()).microsecondsSinceEpoch -
        _progressBarMicrosecondsSinceEpoch;
    int referenceNanoseconds = microseconds * 1000 + _progressBarReferenceTime;
    return _timelineFunction(referenceNanoseconds);
  }

  /// Starts or resumes playback.
  void play() {
    if (!_active || _playing) {
      return;
    }

    if (_ended) {
      _mediaPlayer.seek(0);
    }

    _mediaPlayer.play();
  }

  /// Pauses playback.
  void pause() {
    if (!_active || !_playing) {
      return;
    }

    _mediaPlayer.pause();
  }

  /// Seeks to a position expressed as a Duration.
  void seek(Duration position) {
    if (!_active) {
      return;
    }

    int positionNanoseconds = (position.inMicroseconds * 1000).round();

    _mediaPlayer.seek(positionNanoseconds);
  }

  /// Seeks to a position expressed as a normalized value in the range 0.0 to
  /// 1.0.
  void normalizedSeek(double normalizedPosition) {
    int durationInMicroseconds = duration.inMicroseconds;

    if (durationInMicroseconds == 0) {
      return;
    }

    seek(new Duration(
        microseconds: (normalizedPosition * durationInMicroseconds).round()));
  }

  // Overridden by subclasses to get access to the local player.
  void onMediaPlayerCreated(MediaPlayerProxy mediaPlayer) {}

  void onVideoGeometryUpdated(
      geom.Size videoSize, geom.Size pixelAspectRatio) {}

  // Handles a status update from the player.
  void _handleStatusChanged(MediaPlayerStatus status) {
    if (!_active) {
      return;
    }

    // When the timeline function changes, its reference time is likely to
    // correspond to system time, so we take the opportunity to calibrate
    // the progress bar.
    bool prepare = false;

    if (status.timelineTransform != null) {
      TimelineFunction oldTimelineFunction = _timelineFunction;

      _timelineFunction =
          new TimelineFunction.fromTransform(status.timelineTransform);

      prepare = oldTimelineFunction != _timelineFunction;
    }

    _hasVideo = status.contentHasVideo;
    _ended = status.endOfStream;

    _playing = !ended &&
        _timelineFunction != null &&
        _timelineFunction.subjectDelta != 0;

    _problem = status.problem;
    _metadata = status.metadata;

    if (_metadata != null) {
      _loading = false;
      _durationNanoseconds = _metadata.duration;
    }

    if (_progressBarReady && _progressNanoseconds < 0) {
      // We thought the progress bar was ready, but we're getting negative
      // progress values. That means our assumption about reference time
      // correlation is probably wrong. We need to prepare the progress bar
      // again. See the comment in |_prepareProgressBar|.
      // TODO(dalesat): Remove once we're given access to presentation time.
      // https://fuchsia.atlassian.net/browse/US-130
      _progressBarReady = false;
    }

    if (_timelineFunction != null &&
        _timelineFunction.referenceTime != 0 &&
        (!_progressBarReady || prepare)) {
      _prepareProgressBar();
    }

    if (status.videoSize != null && status.pixelAspectRatio != null) {
      onVideoGeometryUpdated(status.videoSize, status.pixelAspectRatio);
    }

    if (updateCallback != null) {
      scheduleMicrotask(() {
        updateCallback();
      });
    }
  }

  /// Called when the connection to the NetMediaPlayer fails.
  void _handleConnectionError() {
    _problem = const Problem(type: kProblemConnectionFailed);

    if (updateCallback != null) {
      scheduleMicrotask(() {
        updateCallback();
      });
    }
  }

  /// Captures information required to implement the progress bar.
  void _prepareProgressBar() {
    // Capture the correlation between the system clock and the reference time
    // from the timeline function, which we assume to be roughly 'now' in the
    // FrameInfo::presentationTime sense. This is a rough approximation and
    // could break for any number of reasons. We currently have to do this
    // because flutter doesn't provide access to FrameInfo::presentationTime.
    // TODO(dalesat): Fix once we're given access to presentation time.
    // https://fuchsia.atlassian.net/browse/US-130
    // One instance in which our correlation assumption falls down is when
    // we're connecting to a (remote) player whose current timeline was
    // established some time ago. In this case, the reference time in the
    // timeline function correlates to a past time, and the progress values we
    // get will be negative. When that happens, this function should be called
    // again.
    _progressBarMicrosecondsSinceEpoch =
        (new DateTime.now()).microsecondsSinceEpoch;
    _progressBarReferenceTime = _timelineFunction.referenceTime;
    _progressBarReady = true;
  }
}
