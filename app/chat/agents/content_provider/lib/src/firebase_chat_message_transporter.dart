// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:apps.modular.services.auth/token_provider.fidl.dart';
import 'package:config/config.dart';
import 'package:eventsource/eventsource.dart';
import 'package:http/http.dart' as http;
import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.chat.services/chat_content_provider.fidl.dart';

import 'chat_message_transporter.dart';

const int _kMaxRetryCount = 3;
const Duration _kInitDebounceWindow = const Duration(seconds: 5);
const Duration _kHealthCheckPeriod = const Duration(minutes: 3);

/// A [ChatMessageTransporter] implementation that uses a Firebase Realtime
/// Database as its message transportation channel.
class FirebaseChatMessageTransporter extends ChatMessageTransporter {
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

  /// The [TokenProvider] instance from which the id_token can be obtained.
  final TokenProvider _tokenProvider;

  /// An http client for making requests to the Firebase DB server. This same
  /// client should be used for all https calls, so that data such as the DNS
  /// lookup results can be cached and reused.
  final http.Client _client = new http.Client();

  /// A [Completer] which completes when the Firebase initialization is done. In
  /// case of an error, this also completes with an error.
  Completer<Null> _ready = new Completer<Null>();

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

  /// Keep the last received message keys so that we don't process the same
  /// message more than once.
  final Set<String> _cachedMessageKeys = new Set<String>();

  /// Creates a new [FirebaseChatMessageTransporter] instance.
  FirebaseChatMessageTransporter({
    MessageReceivedCallback onReceived,
    @required TokenProvider tokenProvider,
  })
      : _tokenProvider = tokenProvider,
        super(onReceived: onReceived);

  /// Sign in to the firebase DB using the given google auth credentials.
  @override
  Future<Null> initialize() async {
    log.fine('initialize() start');
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
        return _ready.future;
      }
      _lastInitializeStartTime = now;

      _resetHealthCheckTimer();

      if (_ready.isCompleted) {
        _ready = new Completer<Null>();
      }

      if (_tokenProvider == null) {
        throw new Exception('TokenProvider is not provided.');
      }

      // See if the required config values are all provided.
      Config config = await Config.read('/system/data/modules/config.json');
      List<String> keys = <String>[
        'chat_firebase_api_key',
        'chat_firebase_project_id',
      ];

      config.validate(keys);
      _config = config;

      Completer<FirebaseToken> tokenCompleter = new Completer<FirebaseToken>();
      AuthErr authErr;
      _tokenProvider.getFirebaseAuthToken(
        _config.get('chat_firebase_api_key'),
        (FirebaseToken token, AuthErr err) {
          tokenCompleter.complete(token);
          authErr = err;
        },
      );

      FirebaseToken firebaseToken = await tokenCompleter.future;
      if (firebaseToken == null) {
        throw new Exception('Could not obtain the Firebase token.');
      }

      if (authErr.status != Status.ok) {
        throw new Exception('Error fetching firebase token:${authErr.message}');
      }

      _email = _normalizeEmail(firebaseToken.email);
      _firebaseAuthToken = firebaseToken.idToken;

      await _connectToEventStream();

      // We would like to start listeneing to the events but not necessarily
      // await for the stream to be completed. Just ignore the lint rule here.
      // ignore: unawaited_futures
      _startProcessingEventStream();

      _ready.complete();
    } catch (e) {
      ChatAuthenticationException cae = new ChatAuthenticationException(
        'Firebase authentication failed.',
        e,
      );
      _ready.completeError(cae);
      throw cae;
    }
  }

  /// Sends a message to the specified conversation.
  @override
  Future<Null> sendMessage({
    @required Conversation conversation,
    @required List<int> messageId,
    @required String type,
    @required String jsonPayload,
  }) async {
    await _ready.future;

    // Construct the message.
    String key = _encodeFirebaseKey(JSON.encode(messageId));

    List<String> participants = new List<String>.from(conversation.participants)
      ..add(_email)
      ..sort();

    // Every message contains the conversation id as well as the list of all
    // participants in the conversation, which is apparently ineffieicnt. The
    // main reason for this is to allow the recipient to still see the message
    // even when their local history is cleared.
    Map<String, dynamic> value = <String, dynamic>{
      'conversation_id': conversation.conversationId,
      'participants': participants,
      'message_id': messageId,
      'server_timestamp': <String, String>{'.sv': 'timestamp'},
      'sender': _email,
      'type': type,
      'json_payload': jsonPayload,
    };

    await Future.wait(
      conversation.participants.map(
        (String recipient) => _sendMessageTo(recipient, key, value),
      ),
    );
  }

  Future<Null> _sendMessageTo(
    String recipient,
    String key,
    Map<String, dynamic> value, [
    int retryCount = 0,
  ]) async {
    http.Response response = await _firebaseDBPut(
      'emails/${_encodeFirebaseKey(recipient)}/$key',
      value,
    );

    if (response.statusCode != 200) {
      log.severe('Failed to send message to $recipient. '
          'Status Code: ${response.statusCode}\n'
          'Response body: ${response.body}');

      if (response.statusCode == 401) {
        // Retry after refreshing the auth token. If it still fails after the
        // maximum retry count, throw an authorization exception.
        if (retryCount < _kMaxRetryCount) {
          log.fine('retrying _sendMessageTo(). count: $retryCount');
          await initialize();
          await _sendMessageTo(recipient, key, value, retryCount + 1);
        } else {
          throw new ChatAuthorizationException(
            'Status Code: ${response.statusCode}',
          );
        }
      } else {
        throw new ChatNetworkException(
          'Status Code: ${response.statusCode}',
        );
      }
    }
  }

  Future<Null> _connectToEventStream() async {
    if (_eventSource != null) {
      _eventSource.client.close();
    }

    try {
      _eventSource = await EventSource.connect(
        _getFirebaseUrl('emails/${_encodeFirebaseKey(_email)}'),
      );
    } on EventSourceSubscriptionException catch (e) {
      log.severe('Event Source Subscription Exception: ${e.data}');
    }
  }

  Future<Null> _reconnectToEventStream() async {
    await _eventSourceSubscription?.cancel();
    _eventSourceSubscription = null;

    _eventSource?.client?.close();
    _eventSource = null;

    await initialize();
  }

  Future<Null> _startProcessingEventStream() async {
    assert(_eventSource != null);

    _eventSourceSubscription = _eventSource.listen(
      (Event event) async {
        _resetHealthCheckTimer();

        String eventType = event.event?.toLowerCase();

        // Don't spam with the keep-alive event.
        if (eventType != 'keep-alive') {
          log.fine('Event Received: $eventType');
          log.fine('Data: ${event.data}');
        }

        switch (eventType) {
          case 'put':
            await _handlePutEvent(event);
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
            log.warning('WARNING: Unknown event type from Firebase: '
                '$eventType');
        }
      },
      onError: (dynamic e, StackTrace stackTrace) {
        log.severe('Error while processing the event stream', e, stackTrace);
        log.severe('Continuing to receive events.');
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
      initialize();
    });
  }

  /// Handles the 'put' event from the Firebase event stream, which usually
  /// indicates that there's a new incoming message.
  Future<Null> _handlePutEvent(Event event) async {
    Map<String, dynamic> decodedData = JSON.decode(event.data);

    String path = decodedData['path'];
    Map<String, dynamic> data = decodedData['data'];

    // If the path is given as '/', the data may contain multiple messages.
    // Otherwise, the path would be the message key, and the data should be the
    // encoded message.
    if (path == '/') {
      if (data != null) {
        // Sort the messages by their server timestamps assigned by Firebase.
        List<String> messageKeys = new List<String>.from(data.keys);
        messageKeys.sort(
          (String k1, String k2) => data[k1]['server_timestamp']
              .compareTo(data[k2]['server_timestamp']),
        );

        for (String messageKey in messageKeys) {
          await _handleNewMessage(messageKey, data[messageKey]);
        }

        // In case the path is '/' and the data is not null, we received the
        // entire snapshot of the incoming messages. Store all the keys so that
        // we can correctly ignore the subsequent events about these messages.
        _cachedMessageKeys
          ..clear()
          ..addAll(data.keys);
      } else {
        // In case the path is '/' and the data is null, that means we fetched
        // all the incoming messages already. Clear the message key cache.
        _cachedMessageKeys.clear();
      }
    } else if (new RegExp(r'^/[^/]+$').hasMatch(path)) {
      // In this case, the path is constructed by concatenating '/' and the
      // actual message key. Remove the leading '/' to obtain the message key.
      String messageKey = path.substring(1);

      if (data != null) {
        // If data is not null, we received a new incoming message. Handle this
        // message and add it to the cached keys.
        await _handleNewMessage(messageKey, data);
        _cachedMessageKeys.add(messageKey);
      } else {
        // If data is null, that means that this message is removed from the
        // Firebase DB. Just remove this key from the cache.
        _cachedMessageKeys.remove(messageKey);
      }
    } else {
      log.warning("'put' event received from the event stream, but could not "
          'recognize the path.');
      log.warning('path: $path');
      log.warning('data: $data');
    }
  }

  /// Reconstruct the message from the data sent from Firebase DB and notify the
  /// listener that a new message has arrived.
  Future<Null> _handleNewMessage(
    String messageKey,
    Map<String, dynamic> messageValue,
  ) async {
    // Ignore if the given key is currently in the cache. This is to prevent the
    // same message to be handled multiple times.
    if (_cachedMessageKeys.contains(messageKey)) {
      return;
    }

    if (onReceived != null) {
      Conversation conversation = new Conversation()
        ..conversationId = messageValue['conversation_id']
        ..participants = messageValue['participants']
            .where((String email) => email != _email)
            .toList();

      Message message = new Message()
        ..messageId = messageValue['message_id']
        ..sender = messageValue['sender']
        ..timestamp = new DateTime.now().millisecondsSinceEpoch
        ..type = messageValue['type']
        ..jsonPayload = messageValue['json_payload'];

      await onReceived(conversation, message);
    }

    // Delete that message from Firebase DB.
    await _deleteMessageFromFirebase(messageKey);
  }

  Future<Null> _deleteMessageFromFirebase(
    String messageKey, [
    int retryCount = 0,
  ]) async {
    // Delete that message from Firebase DB.
    http.Response response = await _firebaseDBDelete(
      'emails/${_encodeFirebaseKey(_email)}/$messageKey',
    );

    if (response.statusCode != 200) {
      log.severe(
          'Failed to delete the processed incoming message from Firebase DB. '
          'Status Code: ${response.statusCode}\n'
          'Response Body: ${response.body}');

      if (response.statusCode == 401) {
        // Retry after refreshing the auth token. If it still fails after the
        // maximum retry count, throw an authorization exception.
        if (retryCount < _kMaxRetryCount) {
          log.fine('retrying _deleteMessageFromFirebase(). count: $retryCount');
          await initialize();
          await _deleteMessageFromFirebase(messageKey, retryCount + 1);
        } else {
          log.severe(
              'Failed to delete the message from Firebase after the maximum '
              'retry count.');
        }
      }
    }
  }

  /// Make a PUT request to the firebase DB.
  Future<http.Response> _firebaseDBPut(String path, dynamic data) async {
    Uri url = _getFirebaseUrl(path);
    try {
      return await _client.put(
        url,
        headers: <String, String>{
          'content-type': 'application/json',
        },
        body: JSON.encode(data),
      );
    } catch (e) {
      throw new ChatNetworkException('Network Error', e);
    }
  }

  /// Make a DELETE request to the firebase DB.
  Future<http.Response> _firebaseDBDelete(String path) async {
    Uri url = _getFirebaseUrl(path);
    try {
      return await _client.delete(url);
    } catch (e) {
      throw new ChatNetworkException('Network Error', e);
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

  /// Returns the encoded version of the given string that can be used in
  /// Firebase DB keys.
  ///
  /// Since there are certain characters that are not allowed in Firebase keys,
  /// encode each unallowed character to be '&' followed by the two digit upper
  /// case hex value of that character, similar to URI encoding.
  ///
  /// (e.g. `john.doe@example.com` becomes `john&2Edoe@example&2Ecom`).
  ///
  /// NOTE: Originally, we were using `%` instead of `&`, but Firebase API
  /// started to reject any `%` characters in a database path when using their
  /// REST API, so we now have to use a different character.
  String _encodeFirebaseKey(String original) {
    const List<String> toEncode = const <String>[
      '.',
      '\$',
      '[',
      ']',
      '#',
      '/',
      '%',
    ];

    String result = original;
    toEncode.forEach((String ch) {
      String radixString = ch.codeUnitAt(0).toRadixString(16).toUpperCase();
      if (radixString.length < 2) {
        radixString = '0$radixString';
      }
      result = result.replaceAll(ch, '&$radixString');
    });

    return result;
  }
}
