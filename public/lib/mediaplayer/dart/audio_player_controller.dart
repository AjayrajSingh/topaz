// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:fidl_fuchsia_media_playback/fidl_async.dart';
import 'package:fidl_fuchsia_net_oldhttp/fidl_async.dart';
import 'package:fidl_fuchsia_math/fidl_async.dart' as geom;
import 'package:fuchsia_services/services.dart';
import 'package:lib.mediaplayer.dart/timeline.dart' as tl;
import 'package:zircon/zircon.dart';

/// Type for |AudioPlayerController| update callbacks.
typedef UpdateCallback = void Function();

/// Controller for audio-only playback.
class AudioPlayerController {
  Incoming _services;

  PlayerProxy _player;

  bool _active = false;
  bool _loading = false;
  bool _playing = false;
  bool _ended = false;
  bool _hasVideo = false;

  tl.TimelineFunction _timelineFunction;
  Problem _problem;

  Map<String, String> _metadata;

  bool _progressBarReady = false;
  int _progressBarMicrosecondsSinceEpoch;
  int _progressBarReferenceTime;
  int _durationNanoseconds;
  double _deferredNormalizedSeek;

  /// Constructs a AudioPlayerController.
  AudioPlayerController(Incoming services) {
    _services = services;
    _close(); // Initialize stuff.
  }

  /// Called when properties have changed.
  UpdateCallback updateCallback;

  /// Opens a URI for playback. Only HTTP and FILE URIs are allowed. |headers|
  /// must only be supplied for HTTP/S URIs. Supplied headers will be added to
  /// every HTTP/S request issued to the URI.
  void open(Uri uri, {HttpHeaders headers}) {
    if (uri == null) {
      throw ArgumentError.notNull('uri');
    }
    if (uri.isScheme('FILE')) {
      if (headers != null) {
        throw ArgumentError.value(
            headers, 'headers', 'Not valid for FILE URIs.');
      }
    } else if (!uri.isScheme('HTTP') && !uri.isScheme('HTTPS')) {
      throw ArgumentError.value(
          uri, 'uri', 'Only HTTP/S and FILE protocols are supported.');
    }

    if (_active) {
      _setSource(uri, headers);
      _ended = false;
      _hasVideo = false;
      _timelineFunction = null;
      _loading = true;
      _durationNanoseconds = 0;
      _deferredNormalizedSeek = null;
    } else {
      _active = true;

      _createLocalPlayer(uri, headers);
    }

    if (updateCallback != null) {
      scheduleMicrotask(() {
        updateCallback();
      });
    }
  }

  /// Closes this controller, undoing a previous |open| call. Does nothing if
  /// the controller is already closed.
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

    if (_player != null) {
      _player.ctrl.close();
    }

    _player = PlayerProxy();

    _playing = false;
    _ended = false;
    _loading = true;
    _hasVideo = false;

    _problem = null;
    _metadata = null;

    _progressBarReady = false;
    _durationNanoseconds = 0;
    _deferredNormalizedSeek = null;
  }

  /// Creates a local player.
  void _createLocalPlayer(Uri uri, HttpHeaders headers) {
    _services.connectToService(_player);
    _player.onStatusChanged.listen(_handleStatusChanged);

    onMediaPlayerCreated(_player);

    _setSource(uri, headers);
  }

  // Sets the source uri on the media player.
  void _setSource(Uri uri, HttpHeaders headers) {
    if (uri.isScheme('FILE')) {
      _player
          .setFileSource(Channel.fromFile(uri.toFilePath()))
          .catchError(_handleConnectionError);
    } else {
      _player
          .setHttpSource(uri.toString(), _convertHeaders(headers))
          .catchError(_handleConnectionError);
    }
  }

  List<HttpHeader> _convertHeaders(HttpHeaders headers) {
    List<HttpHeader> result = [];
    if (headers != null) {
      headers.forEach((name, values) {
        for (String value in values) {
          HttpHeader header = HttpHeader(name: name, value: value);
          result.add(header);
        }
      });
    }

    return result;
  }

  /// Indicates whether the player open or connected (as opposed to closed).
  bool get openOrConnected => _active;

  /// Indicates whether the player is in the process of loading content.
  /// A transition to false signals that the content is viable and has a
  /// duration. Metadata may arrive before or after loading transitions to
  /// false.
  bool get loading => _loading;

  /// Indicates whether the content has a video stream.
  bool get hasVideo => _hasVideo;

  /// Indicates whether the player is currently playing.
  bool get playing => _playing;

  /// Indicates whether the player is at end-of-stream.
  bool get ended => _ended;

  /// Gets the current problem, if there is one. If this value is non-null,
  /// some issue is preventing playback, and this value describes what that
  /// issue is.
  Problem get problem => _problem;

  /// Gets the current content metadata, if any.
  Map<String, String> get metadata => _metadata;

  /// Gets the duration of the content.
  Duration get duration => Duration(microseconds: _durationNanoseconds ~/ 1000);

  /// Gets current playback progress.
  Duration get progress {
    if (!_progressBarReady) {
      return Duration.zero;
    }

    return Duration(
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

    int microseconds = (DateTime.now()).microsecondsSinceEpoch -
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
      _player.seek(0).catchError(_handleConnectionError);
    }

    _player.play().catchError(_handleConnectionError);
  }

  /// Pauses playback.
  void pause() {
    if (!_active || !_playing) {
      return;
    }

    _player.pause().catchError(_handleConnectionError);
  }

  /// Seeks to a position expressed as a Duration.
  void seek(Duration position) {
    if (!_active) {
      return;
    }

    int positionNanoseconds = (position.inMicroseconds * 1000).round();

    _player.seek(positionNanoseconds).catchError(_handleConnectionError);
  }

  /// Seeks to a position expressed as a normalized value in the range 0.0 to
  /// 1.0.
  void normalizedSeek(double normalizedPosition) {
    int durationInMicroseconds = duration.inMicroseconds;

    if (durationInMicroseconds == 0) {
      _deferredNormalizedSeek = normalizedPosition;
      return;
    }

    seek(Duration(
        microseconds: (normalizedPosition * durationInMicroseconds).round()));
  }

  // Overridden by subclasses to get access to the local player.
  void onMediaPlayerCreated(PlayerProxy player) {}

  void onVideoGeometryUpdated(
      geom.Size videoSize, geom.Size pixelAspectRatio) {}

  // Handles a status update from the player.
  void _handleStatusChanged(PlayerStatus status) {
    if (!_active) {
      return;
    }

    // When the timeline function changes, its reference time is likely to
    // correspond to system time, so we take the opportunity to calibrate
    // the progress bar.
    bool prepare = false;

    if (status.timelineFunction != null) {
      tl.TimelineFunction oldTimelineFunction = _timelineFunction;

      _timelineFunction = tl.TimelineFunction.fromFidl(status.timelineFunction);

      prepare = oldTimelineFunction != _timelineFunction;
    }

    _hasVideo = status.hasVideo;
    _ended = status.endOfStream;

    _playing = !ended &&
        _timelineFunction != null &&
        _timelineFunction.subjectDelta != 0;

    _problem = status.problem;

    if (status.metadata != null) {
      _metadata = Map.fromIterable(status.metadata.properties,
          key: (property) => property.label,
          value: (property) => property.value);
    } else {
      _metadata = null;
    }

    _durationNanoseconds = status.duration;

    if (status.duration != 0) {
      _loading = false;
      if (_deferredNormalizedSeek != null) {
        normalizedSeek(_deferredNormalizedSeek);
        _deferredNormalizedSeek = null;
      }
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
  void _handleConnectionError(Object _) {
    _problem = Problem(type: problemConnectionFailed);

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
    _progressBarMicrosecondsSinceEpoch =
        (DateTime.now()).microsecondsSinceEpoch;
    _progressBarReferenceTime = _timelineFunction.referenceTime;
    _progressBarReady = true;
  }
}
