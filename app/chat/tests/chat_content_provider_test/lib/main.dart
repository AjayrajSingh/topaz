// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert' show json;

import 'package:fidl/fidl.dart' hide Message;
import 'package:fuchsia/fuchsia.dart';
import 'package:fidl_chat_content_provider/fidl.dart';
import 'package:fidl_component/fidl.dart';
import 'package:fidl_ledger/fidl.dart' as ledger_fidl;
import 'package:fidl_modular/fidl.dart';
import 'package:fidl_test_runner/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.component.dart/component.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart' hide expect;
import 'package:topaz.app.chat.agents.content_provider._chat_content_provider_dart_library/src/chat_content_provider_impl.dart';

import 'src/expect.dart';
import 'src/mock_chat_message_transporter.dart';

const Duration _kTimeout = const Duration(seconds: 1);

final ApplicationContext _context = new ApplicationContext.fromStartupInfo();
ChatContentProviderTestModule _module = new ChatContentProviderTestModule();

/// Implementation of the [Module] interface which tests the functionalities of
/// [ChatContentProvider].
class ChatContentProviderTestModule implements Module, Lifecycle {
  final ModuleBinding _moduleBinding = new ModuleBinding();
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();

  final TestRunnerProxy _testRunner = new TestRunnerProxy();
  final ComponentContextProxy _componentContext = new ComponentContextProxy();
  final ledger_fidl.LedgerProxy _ledger = new ledger_fidl.LedgerProxy();

  ChatContentProviderImpl _chatContentProvider;
  final MockChatMessageTransporter _mockChatMessageTransporter =
      new MockChatMessageTransporter();

  /// Bind an [InterfaceRequest] for a [Module] interface to this object.
  void bindModule(InterfaceRequest<Module> request) {
    _moduleBinding.bind(this, request);
  }

  /// Bind an [InterfaceRequest] for a [Lifecycle] interface to this object.
  void bindLifecycle(InterfaceRequest<Lifecycle> request) {
    _lifecycleBinding.bind(this, request);
  }

  /// Implements [Module] interface.
  @override
  Future<Null> initialize(
    InterfaceHandle<ModuleContext> moduleContext,
    InterfaceRequest<ServiceProvider> outgoingServices,
  ) async {
    // Obtain TestRunner interface.
    connectToService(_context.environmentServices, _testRunner.ctrl);
    _testRunner.identify('chat_content_provider_test', () {});

    // Obtain the ComponentContext interface.
    ModuleContextProxy moduleContextProxy = new ModuleContextProxy();
    moduleContextProxy.ctrl.bind(moduleContext);
    moduleContextProxy.getComponentContext(_componentContext.ctrl.request());
    moduleContextProxy.ctrl.close();

    // Obtain Ledger
    _componentContext.getLedger(_ledger.ctrl.request(), (ledger_fidl.Status s) {
      if (s != ledger_fidl.Status.ok) {
        _testRunner.fail('ComponentContext::GetLedger() failed: $s');
      }
    });

    // Initialize the ChatContentProviderImpl with our ComponentContext.
    _chatContentProvider = new ChatContentProviderImpl(
      componentContext: _componentContext,
      chatMessageTransporter: _mockChatMessageTransporter,
    );
    await _chatContentProvider.initialize();

    // Now run the actual tests!
    try {
      await _testFromBlankSlate();
      await _testMessageQueues();
      log.info('Test passed.');
    } on Exception catch (e, stackTrace) {
      _testRunner.fail('Test Error. See the console logs for more details.');
      log.severe('Test Error', e, stackTrace);
    }

    _testRunner.teardown(() {});
  }

  /// Implements [Lifecycle] interface.
  @override
  void terminate() {
    _chatContentProvider?.close();
    _ledger.ctrl.close();
    _componentContext.ctrl.close();
    _testRunner.ctrl.close();
    _moduleBinding.close();
    _lifecycleBinding.close();
    exit(0);
  }

  /// Test adding a new conversation and a few messages, starting from a blank
  /// slate.
  Future<Null> _testFromBlankSlate() async {
    ChatStatus status;
    Conversation conversation;
    List<Conversation> conversations;
    Message message;
    List<Message> messages;
    List<int> messageId1, messageId2;

    // GetConversations() should return an empty list for the first call.
    await _chatContentProvider.getConversations(
      null,
      (ChatStatus s, List<Conversation> c) {
        status = s;
        conversations = c;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(conversations, isNotNull);
    expect(conversations, isEmpty);

    // Test NewConversation() method.
    List<Participant> participants = const <Participant>[
      const Participant(email: 'alice@example.com'),
      const Participant(email: 'bob@example.com'),
    ];
    await _chatContentProvider.newConversation(
      participants,
      (ChatStatus s, Conversation c) {
        status = s;
        conversation = c;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(conversation, isNotNull);
    expect(conversation.conversationId, isNotNull);
    expect(conversation.conversationId, isNotEmpty);
    expect(
      conversation.participants.map((Participant p) => p.email),
      unorderedEquals(participants.map((Participant p) => p.email)),
    );

    // Test GetConversation() method.
    await _chatContentProvider.getConversation(
      conversation.conversationId,
      false,
      (ChatStatus s, Conversation c) {
        status = s;
        conversation = c;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(conversation, isNotNull);
    expect(conversation.conversationId, isNotNull);
    expect(conversation.conversationId, isNotEmpty);
    expect(conversation.participants, unorderedEquals(participants));

    await new Future<Null>.delayed(const Duration(milliseconds: 100));

    // Test GetConversations() method again.
    await _chatContentProvider.getConversations(
      null,
      (ChatStatus s, List<Conversation> c) {
        status = s;
        conversations = c;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(conversations, isNotNull);
    expect(conversations, hasLength(1));
    expect(
      conversations[0].conversationId,
      orderedEquals(conversation.conversationId),
    );
    expect(
      conversations[0].participants.map((Participant p) => p.email),
      unorderedEquals(participants.map((Participant p) => p.email)),
    );

    // Test GetMessages() method.
    await _chatContentProvider.getMessages(
      conversation.conversationId,
      null,
      (ChatStatus s, List<Message> m) {
        status = s;
        messages = m;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(messages, isNotNull);
    expect(messages, isEmpty);

    // Test SendMessage() method #1.
    await _chatContentProvider.sendMessage(
      conversation.conversationId,
      'text',
      'My First Message',
      (ChatStatus s, List<int> mid) {
        status = s;
        messageId1 = mid;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(messageId1, isNotNull);
    expect(messageId1, isNotEmpty);

    // Test SendMessage() method #2.
    await _chatContentProvider.sendMessage(
      conversation.conversationId,
      'text',
      'My Second Message',
      (ChatStatus s, List<int> mid) {
        status = s;
        messageId2 = mid;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(messageId2, isNotNull);
    expect(messageId2, isNotEmpty);

    await new Future<Null>.delayed(const Duration(milliseconds: 100));

    // Test GetMessages() method again.
    await _chatContentProvider.getMessages(
      conversation.conversationId,
      null,
      (ChatStatus s, List<Message> m) {
        status = s;
        messages = m;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(messages, isNotNull);
    expect(messages, hasLength(2));
    expect(messages[0].messageId, orderedEquals(messageId1));
    expect(messages[0].sender, equals('me'));
    expect(messages[0].type, equals('text'));
    expect(messages[0].jsonPayload, equals('My First Message'));
    expect(messages[0].timestamp, isNotNull);
    expect(messages[1].messageId, orderedEquals(messageId2));
    expect(messages[1].sender, equals('me'));
    expect(messages[1].type, equals('text'));
    expect(messages[1].jsonPayload, equals('My Second Message'));
    expect(messages[1].timestamp, isNotNull);
    expect(messages[0].timestamp, lessThan(messages[1].timestamp));

    // Test GetMessage() method #1.
    await _chatContentProvider.getMessage(
      conversation.conversationId,
      messageId1,
      (ChatStatus s, Message m) {
        status = s;
        message = m;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(message, isNotNull);
    expect(message.messageId, orderedEquals(messageId1));
    expect(message.sender, equals('me'));
    expect(message.type, equals('text'));
    expect(message.jsonPayload, equals('My First Message'));
    expect(message.timestamp, isNotNull);

    // Test GetMessage() method #2.
    await _chatContentProvider.getMessage(
      conversation.conversationId,
      messageId2,
      (ChatStatus s, Message m) {
        status = s;
        message = m;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(message, isNotNull);
    expect(message.messageId, orderedEquals(messageId2));
    expect(message.sender, equals('me'));
    expect(message.type, equals('text'));
    expect(message.jsonPayload, equals('My Second Message'));
    expect(message.timestamp, isNotNull);

    // Test GetLastMessage() method.
    await _chatContentProvider.getLastMessage(
      conversation.conversationId,
      (ChatStatus s, Message m) {
        status = s;
        message = m;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(message, isNotNull);
    expect(message.messageId, orderedEquals(messageId2));
    expect(message.sender, equals('me'));
    expect(message.type, equals('text'));
    expect(message.jsonPayload, equals('My Second Message'));
    expect(message.timestamp, isNotNull);

    // Test DeleteMessage() method.
    await _chatContentProvider
        .deleteMessage(conversation.conversationId, messageId1, (ChatStatus s) {
      status = s;
    }).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));

    await new Future<Null>.delayed(const Duration(milliseconds: 100));

    // Test GetMessages() method again.
    await _chatContentProvider.getMessages(
      conversation.conversationId,
      null,
      (ChatStatus s, List<Message> m) {
        status = s;
        messages = m;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));
    expect(messages, isNotNull);
    expect(messages, hasLength(1));
    expect(messages[0].messageId, orderedEquals(messageId2));
    expect(messages[0].sender, equals('me'));
    expect(messages[0].type, equals('text'));
    expect(messages[0].jsonPayload, equals('My Second Message'));
    expect(messages[0].timestamp, isNotNull);
  }

  /// Test getting notified of new conversations / messages with message queues.
  /// This is assumed to be called after [_testFromBlankSlate()].
  Future<Null> _testMessageQueues() async {
    ChatStatus status;
    List<Conversation> conversations;
    Conversation conversation0, conversation1, conversation2;
    List<Message> messages;
    List<int> messageId1, messageId2;
    Completer<Null> completer1, completer2, completer3, completer4;
    dynamic decoded;

    _MessageQueueWrapper mqConversation1 = await _getMessageQueue('conv1');
    _MessageQueueWrapper mqConversation2 = await _getMessageQueue('conv2');
    _MessageQueueWrapper mqMessage1 = await _getMessageQueue('msg1');
    _MessageQueueWrapper mqMessage2 = await _getMessageQueue('msg2');

    // GetConversations() should return a single conversation.
    await _chatContentProvider.getConversations(
      mqConversation1.token,
      (ChatStatus s, List<Conversation> c) {
        status = s;
        conversations = c;
      },
    );
    expect(status, equals(ChatStatus.ok));
    expect(conversations, allOf(isNotNull, hasLength(1)));
    expect(mqConversation1.messagesOfType('new_conversation'), isEmpty);
    conversation0 = conversations[0];

    // GetMessages() should return two messages in the conversation.
    await _chatContentProvider.getMessages(
      conversation0.conversationId,
      mqMessage1.token,
      (ChatStatus s, List<Message> m) {
        status = s;
        messages = m;
      },
    ).timeout(_kTimeout);
    expect(status, equals(ChatStatus.ok));
    expect(messages, allOf(isNotNull, hasLength(1)));
    expect(mqMessage1.receivedMessages, allOf(isNotNull, isEmpty));

    // Add a new conversation and see if mqConversation1 gets notified.
    completer1 = new Completer<Null>();
    mqConversation1.completer = completer1;

    List<Participant> participants1 = const <Participant>[
      const Participant(email: 'foo@example.com'),
      const Participant(email: 'bar@example.com'),
    ];

    await _chatContentProvider.newConversation(
      participants1,
      (ChatStatus s, Conversation c) {
        status = s;
        conversation1 = c;
      },
    ).timeout(_kTimeout);
    expect(status, equals(ChatStatus.ok));
    expect(
      conversation1.participants.map((Participant p) => p.email),
      unorderedEquals(participants1.map((Participant p) => p.email)),
    );

    // Wait for the message queue notification.
    await completer1.future.timeout(_kTimeout);
    expect(mqConversation1.messagesOfType('new_conversation'), hasLength(1));
    decoded =
        json.decode(mqConversation1.messagesOfType('new_conversation').last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('new_conversation'));
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation1.conversationId),
    );
    expect(
      decoded['participants'].map((Map<String, String> p) => p['email']),
      unorderedEquals(participants1.map((Participant p) => p.email)),
    );

    // Register another message queue for conversation.
    await _chatContentProvider.getConversations(
      mqConversation2.token,
      (ChatStatus s, List<Conversation> c) {
        status = s;
        conversations = c;
      },
    ).timeout(_kTimeout);
    expect(status, equals(ChatStatus.ok));
    expect(conversations, allOf(isNotNull, hasLength(2)));

    // Create a new conversation. Both message queues should be notified.
    completer1 = new Completer<Null>();
    completer2 = new Completer<Null>();
    mqConversation1.completer = completer1;
    mqConversation2.completer = completer2;

    List<Participant> participants2 = const <Participant>[
      const Participant(email: 'qux@example.com'),
      const Participant(email: 'baz@example.com'),
    ];

    await _chatContentProvider.newConversation(
      participants2,
      (ChatStatus s, Conversation c) {
        status = s;
        conversation2 = c;
      },
    ).timeout(_kTimeout);
    expect(status, equals(ChatStatus.ok));
    expect(
      conversation2.participants.map((Participant p) => p.email),
      unorderedEquals(participants2.map((Participant p) => p.email)),
    );

    // Wait for the message queue notifications.
    await completer1.future.timeout(_kTimeout);
    expect(mqConversation1.messagesOfType('new_conversation'), hasLength(2));
    decoded =
        json.decode(mqConversation1.messagesOfType('new_conversation').last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('new_conversation'));
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation2.conversationId),
    );
    expect(
      decoded['participants'].map((Map<String, String> p) => p['email']),
      unorderedEquals(participants2.map((Participant p) => p.email)),
    );

    await completer2.future.timeout(_kTimeout);
    expect(mqConversation2.messagesOfType('new_conversation'), hasLength(1));
    decoded =
        json.decode(mqConversation1.messagesOfType('new_conversation').last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('new_conversation'));
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation2.conversationId),
    );
    expect(
      decoded['participants'].map((Map<String, String> p) => p['email']),
      unorderedEquals(participants2.map((Participant p) => p.email)),
    );

    // Now send a few messages to the initial conversation and see if that
    // message is delivered to the message queue.
    completer1 = new Completer<Null>();
    mqMessage1.completer = completer1;

    await _chatContentProvider.sendMessage(
      conversation0.conversationId,
      'text',
      json.encode('sample message1'),
      (ChatStatus s, List<int> mid) {
        status = s;
        messageId1 = mid;
      },
    ).timeout(_kTimeout);
    expect(status, equals(ChatStatus.ok));

    await completer1.future.timeout(_kTimeout);
    expect(mqMessage1.receivedMessages, hasLength(1));
    decoded = json.decode(mqMessage1.receivedMessages.last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('add'));
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation0.conversationId),
    );
    expect(
      decoded['message_id'],
      orderedEquals(messageId1),
    );

    // Register another message queue on the initial conversation.
    await _chatContentProvider.getMessages(
      conversation0.conversationId,
      mqMessage2.token,
      (ChatStatus s, List<Message> m) {
        status = s;
        messages = m;
      },
    ).timeout(_kTimeout);
    expect(status, equals(ChatStatus.ok));
    expect(messages, allOf(isNotNull, hasLength(2)));

    // Send another message and see if both message queues are notified.
    completer1 = new Completer<Null>();
    completer2 = new Completer<Null>();
    mqMessage1.completer = completer1;
    mqMessage2.completer = completer2;

    await _chatContentProvider.sendMessage(
      conversation0.conversationId,
      'text',
      json.encode('sample message2'),
      (ChatStatus s, List<int> mid) {
        status = s;
        messageId2 = mid;
      },
    ).timeout(_kTimeout);
    expect(status, equals(ChatStatus.ok));

    await completer1.future.timeout(_kTimeout);
    expect(mqMessage1.receivedMessages, hasLength(2));
    decoded = json.decode(mqMessage1.receivedMessages.last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('add'));
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation0.conversationId),
    );
    expect(
      decoded['message_id'],
      orderedEquals(messageId2),
    );

    await completer2.future.timeout(_kTimeout);
    expect(mqMessage2.receivedMessages, hasLength(1));
    decoded = json.decode(mqMessage1.receivedMessages.last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('add'));
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation0.conversationId),
    );
    expect(
      decoded['message_id'],
      orderedEquals(messageId2),
    );

    // Delete a message and see if both message queues are notified.
    completer1 = new Completer<Null>();
    completer2 = new Completer<Null>();
    mqMessage1.completer = completer1;
    mqMessage2.completer = completer2;

    await _chatContentProvider.deleteMessage(
      conversation0.conversationId,
      messageId1,
      (ChatStatus s) {
        status = s;
      },
    ).timeout(_kTimeout);

    expect(status, equals(ChatStatus.ok));

    await completer1.future.timeout(_kTimeout);
    expect(mqMessage1.receivedMessages, hasLength(3));
    decoded = json.decode(mqMessage1.receivedMessages.last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('delete'));
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation0.conversationId),
    );
    expect(
      decoded['message_id'],
      orderedEquals(messageId1),
    );

    await completer2.future.timeout(_kTimeout);
    expect(mqMessage2.receivedMessages, hasLength(2));
    decoded = json.decode(mqMessage1.receivedMessages.last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('delete'));
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation0.conversationId),
    );
    expect(
      decoded['message_id'],
      orderedEquals(messageId1),
    );

    // Simulate the situation where a new message arrives from some other user.
    // Both message queues should be notified.
    completer1 = new Completer<Null>();
    completer2 = new Completer<Null>();
    mqMessage1.completer = completer1;
    mqMessage2.completer = completer2;

    messageId1 = const <int>[0, 1, 2, 3, 4];
    await _mockChatMessageTransporter
        .mockReceiveMessage(
          conversation0,
          new Message(
              type: 'text',
              messageId: messageId1,
              sender: 'alice@example.com',
              timestamp: new DateTime.now().millisecondsSinceEpoch,
              jsonPayload: json.encode('A message from Alice!')),
        )
        .timeout(_kTimeout);

    await completer1.future.timeout(_kTimeout);
    expect(mqMessage1.receivedMessages, hasLength(4));
    decoded = json.decode(mqMessage1.receivedMessages.last);
    expect(decoded, isMap);
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation0.conversationId),
    );
    expect(
      decoded['message_id'],
      orderedEquals(messageId1),
    );

    await completer2.future.timeout(_kTimeout);
    expect(mqMessage2.receivedMessages, hasLength(3));
    decoded = json.decode(mqMessage1.receivedMessages.last);
    expect(decoded, isMap);
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation0.conversationId),
    );
    expect(
      decoded['message_id'],
      orderedEquals(messageId1),
    );

    // Try setting the title of a conversation and see if correct notifications
    // are sent.
    completer1 = new Completer<Null>();
    completer2 = new Completer<Null>();
    completer3 = new Completer<Null>();
    completer4 = new Completer<Null>();
    mqConversation1.completer = completer1;
    mqConversation2.completer = completer2;
    mqMessage1.completer = completer3;
    mqMessage2.completer = completer4;

    String conversationTitle = 'Sample Conversation Title 01';
    await _chatContentProvider.setConversationTitle(
      conversation0.conversationId,
      conversationTitle,
      (ChatStatus s) {
        status = s;
      },
    ).timeout(_kTimeout);

    // Check if the 4 notifications are correctly sent.
    await completer1.future.timeout(_kTimeout);
    expect(mqConversation1.messagesOfType('conversation_meta'), hasLength(1));
    decoded =
        json.decode(mqConversation1.messagesOfType('conversation_meta').last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('conversation_meta'));
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation0.conversationId),
    );

    await completer2.future.timeout(_kTimeout);
    expect(mqConversation2.messagesOfType('conversation_meta'), hasLength(1));
    decoded =
        json.decode(mqConversation2.messagesOfType('conversation_meta').last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('conversation_meta'));
    expect(
      decoded['conversation_id'],
      orderedEquals(conversation0.conversationId),
    );

    await completer3.future.timeout(_kTimeout);
    expect(mqMessage1.messagesOfType('title'), hasLength(1));
    decoded = json.decode(mqMessage1.messagesOfType('title').last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('title'));
    expect(decoded['title'], conversationTitle);

    await completer4.future.timeout(_kTimeout);
    expect(mqMessage2.messagesOfType('title'), hasLength(1));
    decoded = json.decode(mqMessage2.messagesOfType('title').last);
    expect(decoded, isMap);
    expect(decoded['event'], equals('title'));
    expect(decoded['title'], conversationTitle);

    mqConversation1.close();
    mqConversation2.close();
    mqMessage1.close();
    mqMessage2.close();
  }

  /// Helper method for obtaining a [MessageQueue] from the [ComponentContext].
  Future<_MessageQueueWrapper> _getMessageQueue(String name) async {
    MessageQueueProxy queue = new MessageQueueProxy();
    _componentContext.obtainMessageQueue(
      name,
      queue.ctrl.request(),
    );
    Completer<String> tokenCompleter = new Completer<String>();
    queue.getToken(tokenCompleter.complete);
    String token = await tokenCompleter.future;

    return new _MessageQueueWrapper(queue: queue, token: token);
  }
}

class _MessageQueueWrapper {
  final MessageQueueProxy queue;
  MessageReceiverImpl _queueReceiver;

  final String token;
  final List<String> receivedMessages = <String>[];

  Completer<Null> completer;

  _MessageQueueWrapper({
    @required this.queue,
    @required this.token,
  })
      : assert(queue != null),
        assert(token != null) {
    _queueReceiver = new MessageReceiverImpl(
      messageQueue: queue,
      onReceiveMessage: handleMessage,
    );
  }

  Iterable<String> messagesOfType(String eventType) => receivedMessages
      .where((String msg) => json.decode(msg)['event'] == eventType);

  void handleMessage(String message, void ack()) {
    receivedMessages.add(message);
    ack();

    // If a completer is given from outside, complete it and set it to null.
    if (completer != null && !completer.isCompleted) {
      completer.complete();
      completer = null;
    }
  }

  void close() {
    _queueReceiver.close();
    queue.ctrl.close();
  }
}

/// Main entry point.
Future<Null> main(List<String> args) async {
  setupLogger(name: 'chat/agent_test');

  _context.outgoingServices
    ..addServiceForName(
      (InterfaceRequest<Module> request) {
        _module.bindModule(request);
      },
      Module.$serviceName,
    )
    ..addServiceForName(
      (InterfaceRequest<Lifecycle> request) {
        _module.bindLifecycle(request);
      },
      Lifecycle.$serviceName,
    );
}
