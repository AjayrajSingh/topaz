// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:fidl/fidl.dart' show InterfaceRequest;
import 'package:fuchsia.fidl.mem/mem.dart';
import 'package:lib.ledger.dart/ledger.dart';
import 'package:fuchsia.fidl.ledger/ledger.dart';
import 'package:lib.logging/logging.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:meta/meta.dart';
import 'package:fuchsia.fidl.chat_content_provider/chat_content_provider.dart';

import 'chat_message_transporter.dart';
import 'conversation_list_watcher.dart';
import 'conversation_watcher.dart';

/// Defines a reserved [Page] for the Ledger instance.
class _ReservedPage {
  final String name;
  final Uint8List id;
  const _ReservedPage({this.name, this.id});
}

/// List of reserved pages to be used for Chat modules.
final List<_ReservedPage> _kReservedPages = <_ReservedPage>[
  new _ReservedPage(
    name: 'conversations',
    id: new Uint8List.fromList(
      const <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
    ),
  ),
];

/// Creates a [Conversation] object from the given ledger [Entry].
Conversation _createConversationFromLedgerEntry(Entry entry) =>
    _createConversationFromLedgerKeyValue(entry.key, entry.value);

/// Creates a [Conversation] object from the given ledger entry's key-value.
Conversation _createConversationFromLedgerKeyValue(
    List<int> key, Buffer value) {
  Map<String, dynamic> decodedValue = decodeLedgerValue(value);
  return new Conversation(
      conversationId: key,
      title: decodedValue['title'],
      participants: decodedValue['participants']
          // TODO(SO-906): remove when the bug passing non-map types is fixed.
          .where((Map<String, String> el) => el != null && el is Map)
          .map(_createParticipantFromMap)
          .toList());
}

/// Creates a [Participant] object from the given map.
Participant _createParticipantFromMap(Map<String, String> participantMap) =>
    new Participant(
        email: participantMap['email'],
        displayName: participantMap['displayName'],
        photoUrl: participantMap['photoUrl']);

/// Creates a [Message] object from the given ledger [Entry].
Message _createMessageFromLedgerEntry(Entry entry) =>
    _createMessageFromLedgerKeyValue(entry.key, entry.value);

/// Creates a [Message] object from the given ledger entry's key-value.
Message _createMessageFromLedgerKeyValue(
    List<int> key, Buffer value) {
  Map<String, dynamic> decodedValue = decodeLedgerValue(value);
  return new Message(
      messageId: key,
      sender: decodedValue['sender'],
      timestamp: decodedValue['timestamp'] ?? 0,
      type: decodedValue['type'],
      jsonPayload: decodedValue['json_payload']);
}

class _KeyNotFoundException implements Exception {
  final String message;
  _KeyNotFoundException([this.message]);
  @override
  String toString() => 'KeyNotFound: $message';
}

/// Called when a new message is received.
typedef void OnMessageReceived(Conversation conversation, Message message);

/// Implementation of the [ChatContentProvider] fidl interface.
class ChatContentProviderImpl extends ChatContentProvider {
  // Keeps the list of bindings.
  final List<ChatContentProviderBinding> _bindings =
      <ChatContentProviderBinding>[];

  /// [ComponentContext] from which we obtain the [Ledger] and [MessageSender]s.
  final ComponentContext componentContext;

  /// [ChatMessageTransporter] for sending / receiveing messages between users.
  final ChatMessageTransporter chatMessageTransporter;

  /// The device id obtained from the [DeviceMap] service.
  final String deviceId;

  /// The device id encoded in UTF8.
  final Uint8List deviceIdBytes;

  /// [Ledger] instance given to the content provider.
  LedgerProxy _ledger;

  /// Reserved [Page]s in the ledger.
  final Map<String, PageProxy> _reservedPages = <String, PageProxy>{};

  /// Local cache of the [Conversation] objects.
  ///
  /// We have to manually provide the hashCode / equals implementation so that
  /// the [List<int>] ids can be used as keys.
  final Map<List<int>, Conversation> _conversationCache =
      createLedgerIdMap<Conversation>();

  ConversationListWatcher _conversationListWatcher;

  final Map<List<int>, ConversationWatcher> _conversationWatchers =
      createLedgerIdMap<ConversationWatcher>();

  /// Keeps the [PageProxy] and [PageSnapshotProxy] objects created in fidl
  /// method implementations.
  ///
  /// For some unknown reason, closing the proxies in try-finally blocks wasn't
  /// enough, and there were some instances where the "Failed to cancel wait for
  /// waiter" error occurred on the page snapshot proxies. Keeping them here to
  /// prevent the agent from crashing.
  final List<PageProxy> _pageProxies = <PageProxy>[];
  final List<PageSnapshotProxy> _snapshotProxies = <PageSnapshotProxy>[];

  /// The last index of the messages that the current user sent to other people.
  /// This value is added to the message ids to prevent id collision.
  int _messageIndex = 0;

  /// Indicates whether the [Ledger] initialization is successfully done.
  final Completer<Null> _ledgerReady = new Completer<Null>();

  /// Called when a new message is received.
  final OnMessageReceived onMessageReceived;

  /// Indicates whether the agent returned an unrecoverable error.
  bool _unrecoverable = false;

  /// Creates a new [ChatContentProviderImpl] instance.
  ChatContentProviderImpl({
    @required this.componentContext,
    @required this.chatMessageTransporter,
    this.deviceId,
    this.onMessageReceived,
  })
      : assert(componentContext != null),
        assert(chatMessageTransporter != null),
        deviceIdBytes = deviceId != null
            ? new Uint8List.fromList(utf8.encode(deviceId))
            : new Uint8List(0) {
    chatMessageTransporter.onReceived = _handleMessage;
  }

  Page get _conversationsPage => _reservedPages['conversations'];

  /// Runs the startup logic for the chat content provider.
  Future<Null> initialize() async {
    // Don't wait for the message transporter logic to be finished. It may take
    // significantly longer than the ledger setup, and there are many operations
    // that only require the ledger setup.
    //
    // ignore: unawaited_futures
    chatMessageTransporter.initialize().catchError((Object err) {
      // TODO: store this state and retry when the agent starts up again
      // https://fuchsia.atlassian.net/browse/SO-340
      log.severe('Failed to initialize transport', err);
      if (err is ChatUnrecoverableException) {
        _unrecoverable = true;
      }
    });

    try {
      await _initializeLedger();
    } on Exception catch (e, stackTrace) {
      log.severe('Failed to initialize', e, stackTrace);
      return;
    }
  }

  /// Initializes the Ledger instance with all the reserved pages created.
  Future<Null> _initializeLedger() async {
    _ledger?.ctrl?.close();
    _ledger = new LedgerProxy();

    try {
      // Obtain the Ledger instance for this agent.
      Completer<Status> statusCompleter = new Completer<Status>();
      componentContext.getLedger(
        _ledger.ctrl.request(),
        statusCompleter.complete,
      );
      Status status = await statusCompleter.future;

      if (status != Status.ok) {
        throw new Exception(
          'ComponentContext::GetLedger returned an error status: $status',
        );
      }

      for (PageProxy page in _reservedPages.values) {
        page?.ctrl?.close();
      }
      _reservedPages.clear();

      await Future.forEach(_kReservedPages, (_ReservedPage pageInfo) {
        PageProxy page = new PageProxy();
        _ledger.getPage(new PageId(id: pageInfo.id), page.ctrl.request(), (Status status) {
          if (status != Status.ok) {
            throw new Exception(
              'Ledger::GetPage() returned an error status: $status',
            );
          }
        });
        _reservedPages[pageInfo.name] = page;
      });

      // Setup the ConversationListWatcher.
      PageSnapshotProxy conversationsPageSnapshot = new PageSnapshotProxy();
      _conversationListWatcher = new ConversationListWatcher(
        initialSnapshot: conversationsPageSnapshot,
      );

      statusCompleter = new Completer<Status>();
      _conversationsPage.getSnapshot(
        conversationsPageSnapshot.ctrl.request(),
        null,
        _conversationListWatcher.pageWatcherHandle,
        statusCompleter.complete,
      );

      status = await statusCompleter.future;
      if (status != Status.ok) {
        throw new Exception(
          'Page::GetSnapshot() returned an error status: $status',
        );
      }

      statusCompleter = new Completer<Status>();
      _conversationsPage.setSyncStateWatcher(
        _conversationListWatcher.syncWatcherHandle,
        statusCompleter.complete,
      );

      status = await statusCompleter.future;
      if (status != Status.ok) {
        throw new Exception(
          'Page::SetSyncStateWatcher() returned an error status: $status',
        );
      }

      _ledgerReady.complete();
      log.fine('Ledger Initialized');
    } on Exception catch (e) {
      _ledgerReady.completeError(e);
      log.fine('Failed to initialize Ledger');
      rethrow;
    }
  }

  /// Returns true if the given [email] address is not a valid one.
  bool _isEmailNotValid(String email) {
    // TODO(youngseokyoon): implement this properly.
    // https://fuchsia.atlassian.net/browse/SO-370
    return false;
  }

  /// Bind this instance with the given request, and keep the binding object
  /// in the binding list.
  void addBinding(InterfaceRequest<ChatContentProvider> request) {
    _bindings.add(new ChatContentProviderBinding()..bind(this, request));
  }

  /// Close all the bindings.
  void close() {
    for (PageProxy page in _reservedPages.values) {
      page?.ctrl?.close();
    }
    for (PageProxy page in _pageProxies) {
      page?.ctrl?.close();
    }
    for (PageSnapshotProxy snapshot in _snapshotProxies) {
      snapshot?.ctrl?.close();
    }
    for (ChatContentProviderBinding binding in _bindings) {
      binding.close();
    }

    _conversationListWatcher.close();
    for (ConversationWatcher watcher in _conversationWatchers.values) {
      watcher.close();
    }
  }

  @override
  Future<Null> currentUserEmail(void callback(String email)) async {
    callback(await chatMessageTransporter.currentUserEmail);
  }

  @override
  void getTitle(void callback(String title)) {
    callback('Chat');
  }

  @override
  Future<Null> newConversation(
    List<Participant> participants,
    void callback(
      ChatStatus chatStatus,
      Conversation conversation,
    ),
  ) async {
    if (_unrecoverable) {
      callback(ChatStatus.unrecoverableError, null);
      return;
    }

    try {
      try {
        await _ledgerReady.future;
      } on Exception {
        callback(ChatStatus.ledgerNotInitialized, null);
        return;
      }

      // Validate the email addresses first.
      if (participants == null ||
          participants.map((Participant p) => p.email).any(_isEmailNotValid)) {
        callback(ChatStatus.invalidEmailAddress, null);
        return;
      }

      PageProxy newConversationPage = new PageProxy();
      _pageProxies.add(newConversationPage);

      try {
        // Request a new page from Ledger.
        Completer<Status> statusCompleter = new Completer<Status>();
        _ledger.getPage(
          null,
          newConversationPage.ctrl.request(),
          statusCompleter.complete,
        );

        Status status = await statusCompleter.future;
        if (status != Status.ok) {
          log.severe('Ledger::GetPage() returned an error status: $status');
          callback(ChatStatus.ledgerOperationError, null);
          return;
        }

        // Get the ID of that page, which will be used as the conversation id.
        Completer<Uint8List> idCompleter = new Completer<Uint8List>();
        newConversationPage.getId(
          (PageId id) => idCompleter.complete(id.id),
        );
        Uint8List conversationId = await idCompleter.future;

        // Put the conversation entry to the conversations page.
        statusCompleter = new Completer<Status>();
        _conversationsPage.put(
          conversationId,
          encodeLedgerValue(<String, dynamic>{
            'participants': participants
                .map((Participant p) => <String, String>{
                      'email': p.email,
                      'displayName': p.displayName,
                      'photoUrl': p.photoUrl
                    })
                .toList(),
          }),
          statusCompleter.complete,
        );

        status = await statusCompleter.future;
        if (status != Status.ok) {
          log.severe('Page::Put() returned an error status: $status');
          callback(ChatStatus.ledgerOperationError, null);
          return;
        }

        // Return the created conversation.
        Conversation conversation = new Conversation(
            conversationId: conversationId, participants: participants);

        _conversationCache[conversationId] = conversation;

        callback(ChatStatus.ok, conversation);
      } finally {
        newConversationPage.ctrl.close();
        _pageProxies.remove(newConversationPage);
      }
    } on Exception catch (e, stackTrace) {
      log.severe('Sending ChatStatus.unknownError', e, stackTrace);
      callback(ChatStatus.unknownError, null);
    }
  }

  @override
  Future<Null> deleteConversation(
    List<int> conversationId,
    void callback(ChatStatus chatStatus),
  ) async {
    if (_unrecoverable) {
      callback(ChatStatus.unrecoverableError);
      return;
    }

    try {
      try {
        await _ledgerReady.future;
      } on Exception {
        callback(ChatStatus.ledgerNotInitialized);
        return;
      }

      Completer<Status> statusCompleter = new Completer<Status>();
      _conversationsPage.delete(conversationId, statusCompleter.complete);

      Status status = await statusCompleter.future;
      if (status == Status.keyNotFound) {
        callback(ChatStatus.idNotFound);
      } else if (status != Status.ok) {
        callback(ChatStatus.ledgerOperationError);
      }

      callback(ChatStatus.ok);
    } on Exception catch (e, stackTrace) {
      log.severe('Sending ChatStatus.unknownError', e, stackTrace);
      callback(ChatStatus.unknownError);
    }
  }

  @override
  Future<Null> getConversation(
    List<int> conversationId,
    bool wait,
    void callback(ChatStatus chatStatus, Conversation conversation),
  ) async {
    if (_unrecoverable) {
      callback(ChatStatus.unrecoverableError, null);
      return;
    }

    try {
      try {
        await _ledgerReady.future;
      } on Exception {
        callback(ChatStatus.ledgerNotInitialized, null);
        return;
      }

      try {
        Conversation conversation = await _getConversation(
          conversationId,
          wait: wait,
        );
        callback(ChatStatus.ok, conversation);
      } on _KeyNotFoundException {
        log.warning('Specified conversation is not found.');
        callback(ChatStatus.idNotFound, null);
      }
    } on Exception catch (e, stackTrace) {
      log.severe('Sending ChatStatus.unknownError', e, stackTrace);
      callback(ChatStatus.unknownError, null);
    }
  }

  @override
  Future<Null> getConversations(
    String messageQueueToken,
    void callback(ChatStatus chatStatus, List<Conversation> conversations),
  ) async {
    if (_unrecoverable) {
      callback(ChatStatus.unrecoverableError, const <Conversation>[]);
      return;
    }

    try {
      try {
        await _ledgerReady.future;
      } on Exception {
        callback(ChatStatus.ledgerNotInitialized, const <Conversation>[]);
        return;
      }

      if (messageQueueToken != null) {
        MessageSenderProxy messageSender = new MessageSenderProxy();
        componentContext.getMessageSender(
          messageQueueToken,
          messageSender.ctrl.request(),
        );

        _conversationListWatcher.addMessageSender(
          messageQueueToken,
          messageSender,
        );
      }

      List<Entry> entries;
      try {
        entries = await getFullEntries(_conversationListWatcher.pageSnapshot);
      } on Exception catch (e, stackTrace) {
        log.severe('Failed to get entries', e, stackTrace);
        callback(ChatStatus.ledgerOperationError, const <Conversation>[]);
        return;
      }

      try {
        List<Conversation> conversations = <Conversation>[];

        for (Entry entry in entries) {
          Conversation conversation = _createConversationFromLedgerEntry(entry);
          conversations.add(conversation);
          _conversationCache[entry.key] = conversation;
        }

        callback(ChatStatus.ok, conversations);
      } on Exception catch (e, stackTrace) {
        log.severe('Decoding error', e, stackTrace);
        callback(ChatStatus.decodingError, const <Conversation>[]);
      }
    } on Exception catch (e, stackTrace) {
      log.severe('Sending ChatStatus.unknownError', e, stackTrace);
      callback(ChatStatus.unknownError, const <Conversation>[]);
    }
  }

  @override
  Future<Null> setConversationTitle(
    List<int> conversationId,
    String title,
    void callback(ChatStatus chatStatus),
  ) async {
    if (_unrecoverable) {
      callback(ChatStatus.unrecoverableError);
      return;
    }

    try {
      try {
        await _ledgerReady.future;
      } on Exception {
        callback(ChatStatus.ledgerNotInitialized);
        return;
      }

      // Write the updated title in the conversation entry of the main
      // conversations page.
      Conversation conversation;
      try {
        conversation = await _getConversation(conversationId);
      } on _KeyNotFoundException {
        log.severe('The conversation ID is not found');
        callback(ChatStatus.idNotFound);
        return;
      }

      // Update the conversation entry with the new title in Ledger.
      Completer<Status> statusCompleter = new Completer<Status>();
      _conversationsPage.put(
        conversationId,
        encodeLedgerValue(<String, dynamic>{
          'title': title,
          'participants': conversation.participants
              .map((Participant p) => <String, String>{
                    'email': p.email,
                    'displayName': p.displayName,
                    'photoUrl': p.photoUrl
                  })
              .toList(),
        }),
        statusCompleter.complete,
      );

      Status status = await statusCompleter.future;
      if (status != Status.ok) {
        log.severe('Page::Put() returned an error status: $status');
        callback(ChatStatus.ledgerOperationError);
        return;
      }

      // Update the conversation cache.
      _conversationCache[conversationId] = new Conversation(
        title: title,
        conversationId: conversation.conversationId,
        participants: conversation.participants,
      );
    } on Exception catch (e, stackTrace) {
      log.severe('Sending ChatStatus.unknownError', e, stackTrace);
      callback(ChatStatus.unknownError);
    }
  }

  @override
  void supportsMembershipEditing(void callback(bool supported)) {
    callback(false);
  }

  @override
  void addParticipants(
    List<int> conversationId,
    List<Participant> participants,
    void callback(ChatStatus chatStatus),
  ) {
    callback(ChatStatus.unsupported);
  }

  @override
  void removeParticipants(
    List<int> conversationId,
    List<Participant> participants,
    void callback(ChatStatus chatStatus),
  ) {
    callback(ChatStatus.unsupported);
  }

  @override
  Future<Null> getMessages(
    List<int> conversationId,
    String messageQueueToken,
    void callback(ChatStatus chatStatus, List<Message> messages),
  ) async {
    if (_unrecoverable) {
      callback(ChatStatus.unrecoverableError, const <Message>[]);
      return;
    }

    try {
      try {
        await _ledgerReady.future;
      } on Exception {
        callback(ChatStatus.ledgerNotInitialized, const <Message>[]);
        return;
      }

      ConversationWatcher watcher =
          await _getConversationWatcher(conversationId);

      // Here, we create a new [MessageSender] instance in case the client gave
      // us a message queue token.
      if (messageQueueToken != null) {
        MessageSenderProxy messageSender = new MessageSenderProxy();
        componentContext.getMessageSender(
          messageQueueToken,
          messageSender.ctrl.request(),
        );

        watcher.addMessageSender(messageQueueToken, messageSender);
        _conversationListWatcher.addConversationMessageSender(
          conversationId,
          messageQueueToken,
          messageSender,
        );
      }

      List<Entry> entries;
      try {
        entries = await getFullEntries(watcher.pageSnapshot);
      } on Exception catch (e, stackTrace) {
        log.severe('Failed to get entries', e, stackTrace);
        callback(ChatStatus.ledgerOperationError, const <Message>[]);
        return;
      }

      try {
        // Exclude the title entry. The title entry key will always be one-byte
        // zero value.
        List<Message> messages = entries
            .where((Entry entry) => entry.key.length != 1 || entry.key[0] != 0)
            .map(_createMessageFromLedgerEntry)
            .toList();

        callback(ChatStatus.ok, messages);
      } on Exception catch (e, stackTrace) {
        log.severe('Decoding error', e, stackTrace);
        callback(ChatStatus.decodingError, const <Message>[]);
      }
    } on Exception catch (e, stackTrace) {
      log.severe('Sending ChatStatus.unknownError', e, stackTrace);
      callback(ChatStatus.unknownError, const <Message>[]);
    }
  }

  @override
  Future<Null> getMessage(
    List<int> conversationId,
    List<int> messageId,
    void callback(ChatStatus chatStatus, Message message),
  ) async {
    if (_unrecoverable) {
      callback(ChatStatus.unrecoverableError, null);
      return;
    }

    try {
      try {
        await _ledgerReady.future;
      } on Exception {
        callback(ChatStatus.ledgerNotInitialized, null);
        return;
      }

      ConversationWatcher watcher =
          await _getConversationWatcher(conversationId);

      Completer<Status> statusCompleter = new Completer<Status>();
      Completer<Buffer> valueCompleter = new Completer<Buffer>();
      watcher.pageSnapshot.get(messageId,
          (Status status, Buffer value) {
        statusCompleter.complete(status);
        valueCompleter.complete(value);
      });

      Status status = await statusCompleter.future;
      if (status != Status.ok) {
        // Handle the KEY_NOT_FOUND error separately.
        if (status == Status.keyNotFound) {
          callback(ChatStatus.idNotFound, null);
          return;
        }

        log.severe('PageSnapshot::Get() returned an error status: $status');
        callback(ChatStatus.ledgerOperationError, null);
        return;
      }

      Buffer value = await valueCompleter.future;
      try {
        Message message = _createMessageFromLedgerKeyValue(messageId, value);
        callback(ChatStatus.ok, message);
      } on Exception catch (e, stackTrace) {
        log.severe('Decoding error', e, stackTrace);
        callback(ChatStatus.decodingError, null);
      }
    } on Exception catch (e, stackTrace) {
      log.severe('Sending ChatStatus.unknownError', e, stackTrace);
      callback(ChatStatus.unknownError, null);
    }
  }

  // TODO(youngseokyoon): implement this more efficiently by only fetching the
  // last message from the ledger.
  @override
  Future<Null> getLastMessage(
    List<int> conversationId,
    void callback(ChatStatus chatStatus, Message message),
  ) async {
    await getMessages(
      conversationId,
      null,
      (ChatStatus cs, List<Message> messages) {
        callback(
          cs,
          messages.isEmpty ? null : messages.last,
        );
      },
    );
  }

  @override
  Future<Null> sendMessage(
    Uint8List conversationId,
    String type,
    String jsonPayload,
    void callback(ChatStatus chatStatus, Uint8List messageId),
  ) async {
    if (_unrecoverable) {
      callback(ChatStatus.unrecoverableError, new Uint8List(0));
      return;
    }

    try {
      try {
        await _ledgerReady.future;
      } on Exception {
        callback(ChatStatus.ledgerNotInitialized, new Uint8List(0));
        return;
      }

      // First, store the message in the current user's Ledger.

      // The message_id is constructed by concatenating three values:
      //
      // 1. Local timestamp since epoch
      //  - Putting the timestamp at the beginning guarantees the sort order.
      //
      // 2. Incremental message index
      //  - This prevents id collision when adding a batch of messages at once.
      //
      // 3. Device id
      //  - This prevents accidental id collision when between multiple devices
      //    of the same user.
      int localTimestamp = new DateTime.now().millisecondsSinceEpoch;
      Uint8List messageId = new Uint8List(12 + deviceIdBytes.lengthInBytes);
      new ByteData.view(messageId.buffer)
        ..setInt64(0, localTimestamp)
        ..setInt32(8, _messageIndex++);
      messageId.setRange(12, 12 + deviceIdBytes.lengthInBytes, deviceIdBytes);

      Map<String, dynamic> localMessageObject = <String, dynamic>{
        'id': messageId,
        'timestamp': localTimestamp,
        'sender': 'me',
        'type': type,
        'json_payload': jsonPayload,
      };

      // Get the current snapshot of the specified conversation page.
      PageProxy conversationPage = new PageProxy();
      _pageProxies.add(conversationPage);

      try {
        Completer<Status> statusCompleter = new Completer<Status>();
        _ledger.getPage(
          new PageId(id: conversationId),
          conversationPage.ctrl.request(),
          statusCompleter.complete,
        );

        Status status = await statusCompleter.future;
        if (status != Status.ok) {
          log.severe('Ledger::GetPage() returned an error status: $status');
          callback(ChatStatus.ledgerOperationError, new Uint8List(0));
          return;
        }

        // Put the message object to the ledger.
        statusCompleter = new Completer<Status>();
        conversationPage.put(
          messageId,
          encodeLedgerValue(localMessageObject),
          statusCompleter.complete,
        );

        status = await statusCompleter.future;
        if (status != Status.ok) {
          log.severe('Page::Put() returned an error status: $status');
          callback(ChatStatus.ledgerOperationError, new Uint8List(0));
          return;
        }
      } finally {
        conversationPage.ctrl.close();
        _pageProxies.remove(conversationPage);
      }

      Conversation conversation = await _getConversation(conversationId);

      // Send the message via the chat message transporter.
      // In case of an error, depending on the type of exception we get, we
      // return different status codes to the client.
      try {
        await chatMessageTransporter.sendMessage(
          conversation: conversation,
          messageId: messageId,
          type: type,
          jsonPayload: jsonPayload,
        );
      } on ChatAuthenticationException {
        callback(ChatStatus.authenticationError, new Uint8List(0));
        return;
      } on ChatAuthorizationException {
        callback(ChatStatus.permissionError, new Uint8List(0));
        return;
      } on ChatNetworkException {
        callback(ChatStatus.networkError, new Uint8List(0));
        return;
      }

      callback(ChatStatus.ok, messageId);
    } on Exception catch (e, stackTrace) {
      log.severe('Sending ChatStatus.unknownError caused by', e, stackTrace);
      callback(ChatStatus.unknownError, new Uint8List(0));
    }
  }

  @override
  Future<Null> deleteMessage(
    List<int> conversationId,
    List<int> messageId,
    void callback(ChatStatus chatStatus),
  ) async {
    if (_unrecoverable) {
      callback(ChatStatus.unrecoverableError);
      return;
    }

    try {
      try {
        await _ledgerReady.future;
      } on Exception {
        callback(ChatStatus.ledgerNotInitialized);
        return;
      }

      // Get the current snapshot of the specified conversation page.
      PageProxy conversationPage = new PageProxy();
      _pageProxies.add(conversationPage);

      try {
        Completer<Status> statusCompleter = new Completer<Status>();
        _ledger.getPage(
          new PageId(id: conversationId),
          conversationPage.ctrl.request(),
          statusCompleter.complete,
        );

        Status status = await statusCompleter.future;
        if (status != Status.ok) {
          log.severe('Ledger::GetPage() returned an error status: $status');
          callback(ChatStatus.ledgerOperationError);
          return;
        }

        // Delete the message from the ledger.
        statusCompleter = new Completer<Status>();
        conversationPage.delete(
          messageId,
          statusCompleter.complete,
        );

        status = await statusCompleter.future;
        if (status != Status.ok) {
          log.severe('Page::Delete() returned an error status: $status');
          callback(ChatStatus.ledgerOperationError);
          return;
        }
      } finally {
        conversationPage.ctrl.close();
        _pageProxies.remove(conversationPage);
      }

      callback(ChatStatus.ok);
    } on Exception catch (e, stackTrace) {
      log.severe('Sending ChatStatus.unknownError caused by', e, stackTrace);
      callback(ChatStatus.unknownError);
    }
  }

  @override
  void unsubscribe(String messageQueueToken) {
    _conversationListWatcher
      ..removeMessageSender(messageQueueToken)
      ..removeConversationMessageSender(messageQueueToken);

    for (ConversationWatcher watcher in _conversationWatchers.values) {
      watcher.removeMessageSender(messageQueueToken);
    }
  }

  /// Gets the [Conversation] object associated with the given [conversationId].
  ///
  /// The [conversationId] is assumed to be valid, and this method will throw an
  /// exception when the given id is not found in the `Conversations` page.
  Future<Conversation> _getConversation(
    List<int> conversationId, {
    bool wait: false,
  }) async {
    // Look for the conversation id from the local cache.
    if (_conversationCache.containsKey(conversationId)) {
      return _conversationCache[conversationId];
    }

    Completer<Status> statusCompleter = new Completer<Status>();
    Completer<Buffer> valueCompleter = new Completer<Buffer>();
    _conversationListWatcher.pageSnapshot.get(conversationId,
        (Status status, Buffer value) {
      statusCompleter.complete(status);
      valueCompleter.complete(value);
    });

    Status status = await statusCompleter.future;

    // If the key is not found in the current snapshot and the wait parameter
    // is set to true, we need to wait for the specified conversation to
    // appear in the snapshot and use that.
    if (wait && status == Status.keyNotFound) {
      Entry entry =
          await _conversationListWatcher.waitForConversation(conversationId);
      Conversation conversation = _createConversationFromLedgerEntry(entry);
      _conversationCache[conversationId] = conversation;

      return conversation;
    }

    // Distinguish keyNotFound status and others.
    if (status == Status.keyNotFound) {
      throw new _KeyNotFoundException('The conversation ID is not found');
    } else if (status != Status.ok) {
      throw new Exception(
        'PageSnapshot::Get() returned an error status: $status',
      );
    }

    Buffer value = await valueCompleter.future;
    Conversation conversation =
        _createConversationFromLedgerKeyValue(conversationId, value);
    _conversationCache[conversationId] = conversation;

    return conversation;
  }

  Future<ConversationWatcher> _getConversationWatcher(
      List<int> conversationId) async {
    // If we don't have a conversation watcher for this conversation, create a
    // new one and put it in the cache.
    ConversationWatcher watcher = _conversationWatchers[conversationId];
    if (watcher != null) {
      return watcher;
    }

    PageProxy conversationPage = new PageProxy();
    _pageProxies.add(conversationPage);
    PageSnapshotProxy snapshot = new PageSnapshotProxy();

    watcher = new ConversationWatcher(
      initialSnapshot: snapshot,
      conversationId: conversationId,
    );

    try {
      Completer<Status> statusCompleter = new Completer<Status>();
      _ledger.getPage(
        new PageId(id: conversationId),
        conversationPage.ctrl.request(),
        statusCompleter.complete,
      );

      Status status = await statusCompleter.future;
      if (status != Status.ok) {
        throw new Exception(
          'Ledger::GetPage() returned an error status: $status',
        );
      }

      statusCompleter = new Completer<Status>();
      conversationPage.getSnapshot(
        snapshot.ctrl.request(),
        null,
        watcher.pageWatcherHandle,
        statusCompleter.complete,
      );

      status = await statusCompleter.future;
      if (status != Status.ok) {
        throw new Exception(
          'Page::GetSnapshot() returned an error status: $status',
        );
      }

      _conversationWatchers[conversationId] = watcher;
      return watcher;
    } finally {
      conversationPage.ctrl.close();
      _pageProxies.remove(conversationPage);
    }
  }

  /// Handles a newly received message from another user.
  Future<Null> _handleMessage(
    Conversation conversation,
    Message message,
  ) async {
    try {
      await _ledgerReady.future;

      Conversation cachedConversation =
          _conversationCache[conversation.conversationId];

      PageProxy conversationPage = new PageProxy();
      _pageProxies.add(conversationPage);

      try {
        // Request a new page from Ledger.
        Completer<Status> statusCompleter = new Completer<Status>();
        _ledger.getPage(
          new PageId(id: conversation.conversationId),
          conversationPage.ctrl.request(),
          statusCompleter.complete,
        );

        Status status = await statusCompleter.future;
        if (status != Status.ok) {
          log.severe('Ledger::GetPage() returned an error status: $status');
          return;
        }

        if (cachedConversation == null) {
          // Put the conversation entry to the conversations page.
          statusCompleter = new Completer<Status>();
          _conversationsPage.put(
            conversation.conversationId,
            encodeLedgerValue(<String, dynamic>{
              'participants': conversation.participants,
            }),
            statusCompleter.complete,
          );

          status = await statusCompleter.future;
          if (status != Status.ok) {
            log.severe('Page::Put() returned an error status: $status');
          }

          _conversationCache[conversation.conversationId] = conversation;
        }

        Map<String, dynamic> localMessageObject = _messageToJson(message);

        // Put the message object to the ledger.
        statusCompleter = new Completer<Status>();
        conversationPage.put(
          message.messageId,
          encodeLedgerValue(localMessageObject),
          statusCompleter.complete,
        );

        status = await statusCompleter.future;
        if (status != Status.ok) {
          log.severe('Page::Put() returned an error status: $status');
          return;
        }

        onMessageReceived?.call(conversation, message);
      } finally {
        conversationPage.ctrl.close();
        _pageProxies.remove(conversationPage);
      }
    } on Exception catch (e, stackTrace) {
      log.severe('Error while processing an incoming message', e, stackTrace);
    }
  }

  /// Returns the JSON encodable [Map] representation of the given message,
  /// which can be encoded and stored in [Ledger].
  Map<String, dynamic> _messageToJson(Message message) => <String, dynamic>{
        'id': message.messageId,
        'timestamp': message.timestamp,
        'sender': message.sender,
        'type': message.type,
        'json_payload': message.jsonPayload,
      };
}
