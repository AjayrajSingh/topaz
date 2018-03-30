// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show json;

import 'package:fuchsia.fidl.auth/auth.dart';
import 'package:lib.logging/logging.dart';

import 'package:config/config.dart';
import 'package:eventsource/eventsource.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:fuchsia.fidl.chat_content_provider/chat_content_provider.dart';

import 'exceptions.dart';

const Duration _kInitDebounceWindow = const Duration(seconds: 5);
const Duration _kHealthCheckPeriod = const Duration(minutes: 3);

/// The implementation class for [FirebaseDbClient] FIDL interface.
class FirebaseDbClientImpl implements FirebaseDbClient {
  /// Config object obtained from the `/system/data/modules/config.json` file.
  Config _config;

  /// The primary email address of this user.
  String _email;

  /// Firebase auth token obtained from the identity toolkit api.
  String _firebaseAuthToken;

  /// [EventSource] connection for wathcing the incoming messages from Firebase.
  EventSource _eventSource;

  /// [StreamSubscription] for canceling the subscription when needed.
  StreamSubscription<Event> _eventSourceSubscription;

  /// The [TokenProvider] obtained from the framework.
  final TokenProvider _tokenProvider;

  /// The [FirebaseDbWatcher] provided by a client.
  final FirebaseDbWatcher watcher;

  /// An http client for making requests to the Firebase DB server. This same
  /// client should be used for all https calls, so that data such as the DNS
  /// lookup results can be cached and reused.
  final http.Client _client = new http.Client();

  /// A [Completer] which completes when the Firebase initialization is done. In
  /// case of an error, this also completes with an error.
  Completer<Null> _readyCompleter = new Completer<Null>();

  /// Stores the last time [initialize()] is called, used for debouncing the
  /// [initialize()] call.
  DateTime _lastInitializeStartTime;

  /// [Timer] for periodic health check. Normally, the Firebase event stream
  /// sends the 'keep-alive' event every 30 seconds to notify that the stream
  /// connection is still alive. Therefore, this timer is reset every time when
  /// a new event is sent from the Firebase event stream. When this timer
  /// triggers, it will try to re-establish the connection to the event stream.
  /// This way, the agent can be more resilient to any potential network errors.
  Timer _healthCheckTimer;

  /// Creates a new instance of [FirebaseDbClientImpl].
  FirebaseDbClientImpl({
    @required TokenProvider tokenProvider,
    this.watcher,
  })
      : _tokenProvider = tokenProvider;

  // HACK(jimbe) The fidl declaration won't accept null, so the workaround is
  // to return an empty string. Returning null is probably better, but I don't
  // have time to chase it down.
  /// Gets the email address of the currently logged in user.
  String get currentUserEmail => _email ?? '';

  /// Gets a [Future] which completes when the Firebase initialization is done.
  /// In case of an error, this alos completes with an error.
  Future<Null> get ready => _readyCompleter.future;

  /// Gets a [Future] that contains the listen path. Only used when the watcher
  /// is provided.
  Future<String> get listenPath {
    Completer<String> pathCompleter = new Completer<String>();
    watcher.getListenPath(pathCompleter.complete);
    return pathCompleter.future;
  }

  /// Sign in to the firebase DB using the given google auth credentials.
  @override
  Future<Null> initialize(void callback(FirebaseStatus status)) async {
    log.fine('initialize() start');
    FirebaseStatus status = FirebaseStatus.ok;

    try {
      // The initialize() method can be called by multiple reasons; the
      // 'auth_revoked' event from the event source, and any 401 unauthorized
      // status code returned from a DB update operation.
      // To prevent parallel running initialize() method, only allow running the
      // initialization logic once within the debounce window.
      DateTime now = new DateTime.now();
      if (_lastInitializeStartTime != null &&
          now.difference(_lastInitializeStartTime) < _kInitDebounceWindow) {
        log.fine('debouncing initialize() call');
        return _readyCompleter.future;
      }
      _lastInitializeStartTime = now;

      if (watcher != null) {
        _resetHealthCheckTimer();
      }

      if (_readyCompleter.isCompleted) {
        _readyCompleter = new Completer<Null>();
      }

      if (_tokenProvider == null) {
        throw new Exception('TokenProvider is not provided.');
      }

      FirebaseToken firebaseToken;
      try {
        // See if the required config values are all provided.
        Config config = await Config.read('/system/data/modules/config.json');
        List<String> keys = <String>[
          'chat_firebase_api_key',
          'chat_firebase_project_id',
        ];

        config.validate(keys);
        _config = config;

        Completer<FirebaseToken> tokenCompleter =
            new Completer<FirebaseToken>();
        AuthErr authErr;
        _tokenProvider.getFirebaseAuthToken(
          _config.get('chat_firebase_api_key'),
          (FirebaseToken token, AuthErr err) {
            tokenCompleter.complete(token);
            authErr = err;
          },
        );

        firebaseToken = await tokenCompleter.future;
        if (firebaseToken == null ||
            firebaseToken.idToken == null ||
            firebaseToken.idToken.isEmpty) {
          throw new Exception('Could not obtain the Firebase token.');
        }

        if (authErr.status != Status.ok) {
          throw new Exception(
              'Error fetching firebase token:${authErr.message}');
        }
      } on Object catch (e) {
        throw new FirebaseUnrecoverableException('Initialization failed', e);
      }

      _email = _normalizeEmail(firebaseToken.email);
      _firebaseAuthToken = firebaseToken.idToken;

      if (watcher != null) {
        await _connectToEventStream();

        // We would like to start listeneing to the events but not necessarily
        // await for the stream to be completed. Just ignore the lint rule here.
        // ignore: unawaited_futures
        _startProcessingEventStream();
      }

      _readyCompleter.complete();
    } on FirebaseUnrecoverableException catch (e) {
      log.warning('Sending unrecoverable error', e);
      status = FirebaseStatus.unrecoverableError;
      _readyCompleter.completeError(e);
    } on Exception catch (e) {
      log.warning('Sending authentication error', e);
      status = FirebaseStatus.authenticationError;
      FirebaseAuthenticationException cae = new FirebaseAuthenticationException(
        'Firebase authentication failed.',
        e,
      );
      _readyCompleter.completeError(cae);
    } finally {
      callback(status);
    }
  }

  Future<Null> _connectToEventStream() async {
    if (_eventSource != null) {
      _eventSource.client.close();
    }

    try {
      _eventSource = await EventSource.connect(
        _getFirebaseUrl(await listenPath),
      );
    } on EventSourceSubscriptionException catch (e) {
      log.severe('Event Source Subscription Exception: ${e.data}');
    }
  }

  Future<Null> _reconnectToEventStream() async {
    await terminate(() {});
    await initialize((FirebaseStatus status) {
      if (status != FirebaseStatus.ok) {
        log.warning('Failed to reconnect to event stream.');
      }
    });
  }

  Future<Null> _startProcessingEventStream() async {
    assert(_eventSource != null);

    _eventSourceSubscription = _eventSource.listen(
      (Event event) async {
        _resetHealthCheckTimer();

        String eventType = event.event?.toLowerCase();

        // Don't spam with the keep-alive event.
        if (eventType != 'keep-alive') {
          log..fine('Event Received: $eventType')..fine('Data: ${event.data}');
        }

        switch (eventType) {
          case 'put':
          case 'patch':
            NotificationType type = eventType == 'put'
                ? NotificationType.put
                : NotificationType.patch;

            Map<String, dynamic> decodedData = json.decode(event.data);
            String path = decodedData['path'];
            Map<String, Object> data = decodedData['data'];

            Completer<Null> completer = new Completer<Null>();
            watcher.dataChanged(
              type,
              path,
              json.encode(data),
              completer.complete,
            );
            await completer.future;
            break;

          case 'keep-alive':
            // We can safely ignore this event.
            break;

          case 'cancel':
            log.fine('"cancel" event received.');
            await _reconnectToEventStream();
            break;

          case 'auth_revoked':
            log.fine('"auth_revoked" event received. The auth credential is no '
                'longer valid and should be renewed. Renewing the credential.');
            await _reconnectToEventStream();
            break;

          default:
            log.warning('Unknown event type from Firebase: $eventType');
            break;
        }
      },
      onError: (Object e, StackTrace stackTrace) {
        log
          ..severe('Error while processing the event stream', e, stackTrace)
          ..severe('Continuing to receive events.');
      },
      onDone: () {
        log.fine('Event stream is closed. Renewing the credential.');
        _reconnectToEventStream();
      },
      cancelOnError: false,
    );
  }

  void _resetHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = new Timer(_kHealthCheckPeriod, () {
      log.fine('Reinitializing: triggered by the health check timer.');
      initialize((FirebaseStatus status) {
        if (status != FirebaseStatus.ok) {
          log.warning('Failed to reconnect to event stream.');
        }
      });
    });
  }

  @override
  Future<Null> put(
    String path,
    String data,
    void callback(FirebaseStatus status, HttpResponse response),
  ) async {
    log.fine('put() call. path: "$path", data: "$data"');

    Uri url = _getFirebaseUrl(path);

    FirebaseStatus status = FirebaseStatus.ok;
    HttpResponse response;
    try {
      http.Response resp = await _client.put(
        url,
        headers: <String, String>{
          'content-type': 'application/json',
        },
        body: data,
      );

      response = new HttpResponse(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    } on Exception catch (e) {
      log.warning('Sending network error', e);
      status = FirebaseStatus.networkError;
    } finally {
      callback(status, response);
    }
  }

  @override
  Future<Null> delete(
    String path,
    void callback(FirebaseStatus status, HttpResponse response),
  ) async {
    log.fine('delete() call. path: "$path"');

    Uri url = _getFirebaseUrl(path);

    FirebaseStatus status = FirebaseStatus.ok;
    HttpResponse response;
    try {
      http.Response resp = await _client.delete(url);

      response = new HttpResponse(
        statusCode: resp.statusCode,
        body: resp.body,
      );
    } on Exception catch (e) {
      log.warning('Sending network error', e);
      status = FirebaseStatus.networkError;
    } finally {
      callback(status, response);
    }
  }

  /// Returns the firebase DB url with the given data path.
  Uri _getFirebaseUrl(String path) {
    return new Uri.https(
      '${_config.get('chat_firebase_project_id')}.firebaseio.com',
      '$path.json',
      <String, String>{
        'auth': _firebaseAuthToken,
      },
    );
  }

  /// Normalize the email address.
  String _normalizeEmail(String email) {
    int atSignIndex = email?.indexOf('@') ?? -1;
    if (atSignIndex == -1) {
      return email;
    }

    return email.toLowerCase();
  }

  @override
  void encodeKey(String key, void callback(String encodedKey)) {
    const List<String> toEncode = const <String>[
      '.',
      '\$',
      '[',
      ']',
      '#',
      '/',
      '%',
    ];

    String result = key;
    for (String ch in toEncode) {
      String radixString = ch.codeUnitAt(0).toRadixString(16).toUpperCase();
      if (radixString.length < 2) {
        radixString = '0$radixString';
      }
      result = result.replaceAll(ch, '&$radixString');
    }

    callback(result);
  }

  @override
  Future<Null> getCurrentUserEmail(void callback(String email)) async {
    String result = _email;

    if (_email == null) {
      try {
        await ready;
        result = _email;
      } on Object {
        result = '';
      }
    }

    callback(result);
  }

  @override
  Future<Null> terminate(void callback()) async {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    await _eventSourceSubscription?.cancel();
    _eventSourceSubscription = null;

    _eventSource?.client?.close();
    _eventSource = null;

    callback();
  }
}
