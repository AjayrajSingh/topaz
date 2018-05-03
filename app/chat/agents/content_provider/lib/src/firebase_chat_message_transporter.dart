// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show json;

import 'package:fuchsia.fidl.chat_content_provider/chat_content_provider.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

import 'chat_message_transporter.dart';

const int _kMaxRetryCount = 3;

/// A [ChatMessageTransporter] implementation that uses a Firebase Realtime
/// Database as its message transportation channel.
class FirebaseChatMessageTransporter extends ChatMessageTransporter
    implements FirebaseDbWatcher {
  final FirebaseDbClientProxy _firebaseClient = new FirebaseDbClientProxy();
  final FirebaseDbWatcherBinding _watcherBinding =
      new FirebaseDbWatcherBinding();

  /// Keep the last received message keys so that we don't process the same
  /// message more than once.
  final Set<String> _cachedMessageKeys = new Set<String>();

  /// Creates a new [FirebaseChatMessageTransporter] instance.
  FirebaseChatMessageTransporter({
    MessageReceivedCallback onReceived,
    @required FirebaseDbConnector firebaseDbConnector,
  })
      : super(onReceived: onReceived) {
    firebaseDbConnector.getClient(
      _watcherBinding.wrap(this),
      _firebaseClient.ctrl.request(),
    );
  }

  @override
  Future<String> get currentUserEmail {
    Completer<String> completer = new Completer<String>();
    _firebaseClient.getCurrentUserEmail(completer.complete);
    return completer.future;
  }

  @override
  Future<Null> initialize() async {
    Completer<FirebaseStatus> statusCompleter = new Completer<FirebaseStatus>();
    _firebaseClient.initialize(statusCompleter.complete);

    FirebaseStatus status = await statusCompleter.future;
    if (status != FirebaseStatus.ok) {
      if (status == FirebaseStatus.unrecoverableError) {
        throw new ChatUnrecoverableException(
          'Unrecoverable error from Firebase transport',
        );
      } else if (status == FirebaseStatus.authenticationError) {
        throw new ChatAuthenticationException('Failed to authenticate');
      } else {
        throw new ChatNetworkException('Unknown error');
      }
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
    // Construct the message.
    String key = await _encodeKey(json.encode(messageId));
    String email = await currentUserEmail;

    List<String> participants =
        conversation.participants.map((Participant p) => p.email).toList()
          ..add(email)
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
      'sender': email,
      'type': type,
      'json_payload': jsonPayload,
    };

    await Future.wait(
      conversation.participants.map(
        (Participant recipient) => _sendMessageTo(recipient.email, key, value),
      ),
    );
  }

  Future<Null> _sendMessageTo(
    String recipient,
    String key,
    Map<String, dynamic> value, [
    int retryCount = 0,
  ]) async {
    Completer<FirebaseStatus> statusCompleter = new Completer<FirebaseStatus>();
    HttpResponse response;

    _firebaseClient.put(
      'emails/${await _encodeKey(recipient)}/$key',
      json.encode(value),
      (FirebaseStatus status, HttpResponse resp) {
        response = resp;
        statusCompleter.complete(status);
      },
    );

    FirebaseStatus status = await statusCompleter.future;
    if (status != FirebaseStatus.ok) {
      throw new ChatNetworkException('Firebase error returned: $status');
    }

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

  // |FirebaseDBWatcher|
  /// Handles the 'put' event from the Firebase event stream, which usually
  /// indicates that there's a new incoming message.
  @override
  Future<Null> dataChanged(
    NotificationType type,
    String path,
    String data,
    void callback(),
  ) async {
    if (type != NotificationType.put) {
      log.severe('Expected to get only "put" events, but got: $type');
      callback();
      return;
    }

    try {
      dynamic decoded = json.decode(data);

      // If the path is given as '/', the data may contain multiple messages.
      // Otherwise, the path would be the message key, and the data should be
      // the encoded message.
      if (path == '/') {
        if (decoded != null) {
          // Sort the messages by their server timestamps assigned by Firebase.
          List<String> messageKeys = new List<String>.from(decoded.keys)
            ..sort(
              (String k1, String k2) => decoded[k1]['server_timestamp']
                  .compareTo(decoded[k2]['server_timestamp']),
            );

          for (String messageKey in messageKeys) {
            await _handleNewMessage(messageKey, decoded[messageKey]);
          }

          // In case the path is '/' and the data is not null, we received the
          // entire snapshot of the incoming messages. Store all the keys so
          // that we can correctly ignore the subsequent events about these
          // messages.
          _cachedMessageKeys
            ..clear()
            ..addAll(decoded.keys);
        } else {
          // In case the path is '/' and the data is null, that means we fetched
          // all the incoming messages already. Clear the message key cache.
          _cachedMessageKeys.clear();
        }
      } else if (new RegExp(r'^/[^/]+$').hasMatch(path)) {
        // In this case, the path is constructed by concatenating '/' and the
        // actual message key. Remove the leading '/' to obtain the message key.
        String messageKey = path.substring(1);

        if (decoded != null) {
          // If data is not null, we received a new incoming message. Handle
          // this message and add it to the cached keys.
          await _handleNewMessage(messageKey, decoded);
          _cachedMessageKeys.add(messageKey);
        } else {
          // If data is null, that means that this message is removed from the
          // Firebase DB. Just remove this key from the cache.
          _cachedMessageKeys.remove(messageKey);
        }
      } else {
        log
          ..warning("'put' event received from the event stream, but could not "
              'recognize the path.')
          ..warning('path: $path')
          ..warning('data: $data');
      }
    } on Exception catch (e, stackTrace) {
      log.severe('Decoding error', e, stackTrace);
    } finally {
      callback();
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

    String currentUser = await currentUserEmail;

    if (onReceived != null) {
      Conversation conversation = new Conversation(
          conversationId: messageValue['conversation_id'],
          participants: messageValue['participants']
              .where((String email) => email != currentUser)
              .map((String email) => new Participant(email: email))
              .toList());

      Message message = new Message(
          messageId: messageValue['message_id'],
          sender: messageValue['sender'],
          timestamp: new DateTime.now().millisecondsSinceEpoch,
          type: messageValue['type'],
          jsonPayload: messageValue['json_payload']);

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
    Completer<FirebaseStatus> statusCompleter = new Completer<FirebaseStatus>();
    HttpResponse response;

    _firebaseClient.delete(
      'emails/${await _encodeKey(await currentUserEmail)}/$messageKey',
      (FirebaseStatus status, HttpResponse resp) {
        response = resp;
        statusCompleter.complete(status);
      },
    );

    FirebaseStatus status = await statusCompleter.future;
    if (status != FirebaseStatus.ok) {
      throw new ChatNetworkException('Firebase error returned: $status');
    }

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

  // |FirebaseDBWatcher|
  @override
  Future<Null> getListenPath(void callback(String path)) async {
    callback('emails/${await _encodeKey(await currentUserEmail)}');
  }

  Future<String> _encodeKey(String key) {
    Completer<String> completer = new Completer<String>();
    _firebaseClient.encodeKey(key, completer.complete);
    return completer.future;
  }
}
