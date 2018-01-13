// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lib.agent.fidl.agent_controller/agent_controller.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.component.dart/component.dart';
import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.component.fidl/message_queue.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.widgets/modular.dart';
import 'package:topaz.app.chat.services/chat_content_provider.fidl.dart'
    as fidl;

const String _kChatContentProviderUrl = 'chat_content_provider';

const Duration _kErrorDuration = const Duration(seconds: 10);

/// The [ModuleModel] implementation for this project, which encapsulates how
/// this module interacts with the Modular framework.
class ConversationInfoModuleModel extends ModuleModel {
  static final ListEquality<int> _intListEquality = const ListEquality<int>();

  final AgentControllerProxy _chatContentProviderController =
      new AgentControllerProxy();

  final fidl.ChatContentProviderProxy _chatContentProvider =
      new fidl.ChatContentProviderProxy();

  final MessageQueueProxy _mqConversationEvents = new MessageQueueProxy();
  MessageReceiverImpl _mqConversationReceiver;
  final Completer<String> _mqConversationToken = new Completer<String>();

  fidl.Conversation _conversation;
  bool _fetchingConversation = false;
  final Completer<Null> _readyCompleter = new Completer<Null>();

  /// Gets the conversation title.
  String get title => _conversation?.title;

  /// The key to be used for scaffold.
  GlobalKey<ScaffoldState> get scaffoldKey => _scaffoldKey;
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  Uint8List _conversationId;

  /// Gets the current conversation id value.
  Uint8List get conversationId => _conversationId;

  /// Gets the list of participants in this conversation.
  List<fidl.Participant> get participants => _conversation != null
      ? new UnmodifiableListView<fidl.Participant>(
          _conversation.participants,
        )
      : null;

  /// Indicates whether the fetching is in progress or not.
  bool get fetchingConversation => _fetchingConversation;

  /// Sets the current conversation id value.
  void _setConversationId(List<int> id) {
    Uint8List newId = id == null ? null : new Uint8List.fromList(id);

    if (!_intListEquality.equals(_conversationId, newId)) {
      // Unsubscribe to get no further notification on the old conversation.
      if (_mqConversationToken.isCompleted) {
        _mqConversationToken.future.then(_chatContentProvider.unsubscribe);
      }

      _conversationId = newId;

      _fetchingConversation = true;
      _conversation = null;
      notifyListeners();

      // After fetching is done, a second notification will be sent out.
      _fetchConversation();
    }
  }

  /// Completer for the content provider url provided by the Link. This must be
  /// completed when onNotify() is called for the first time.
  final Completer<String> _contentProviderUrlCompleter =
      new Completer<String>();

  @override
  Future<Null> onReady(
    ModuleContext moduleContext,
    Link link,
  ) async {
    super.onReady(moduleContext, link);

    log.fine('ModuleModel::onReady call.');

    // Obtain the chat content provider url by reading the url from the Link. If
    // the initial onNotify() call doesn't contain the url, use the default chat
    // content provider.
    String contentProviderUrl = await _contentProviderUrlCompleter.future;
    contentProviderUrl ??= _kChatContentProviderUrl;

    // Obtain the component context.
    ComponentContextProxy componentContext = new ComponentContextProxy();
    moduleContext.getComponentContext(componentContext.ctrl.request());

    // Obtain the ChatContentProvider service.
    ServiceProviderProxy contentProviderServices = new ServiceProviderProxy();
    componentContext.connectToAgent(
      contentProviderUrl,
      contentProviderServices.ctrl.request(),
      _chatContentProviderController.ctrl.request(),
    );
    connectToService(contentProviderServices, _chatContentProvider.ctrl);

    // Obtain a message queue for title change events.
    componentContext.obtainMessageQueue(
      'chat_conversation',
      _mqConversationEvents.ctrl.request(),
    );
    // Save the message queue token for later use.
    _mqConversationEvents.getToken(_mqConversationToken.complete);
    _mqConversationReceiver = new MessageReceiverImpl(
      messageQueue: _mqConversationEvents,
      onReceiveMessage: _handleConversationEvent,
    );

    // Close all the unnecessary bindings.
    contentProviderServices.ctrl.close();
    componentContext.ctrl.close();

    _readyCompleter.complete();
  }

  /// Fetches the conversation metadata and the message history from the content
  /// provider. It also gives our message queue token to the agent so that the
  /// agent can notify us whenever a new message appears in the current
  /// conversation.
  ///
  /// The returned conversation will be stored in [_conversation].
  Future<Null> _fetchConversation() async {
    if (conversationId == null) {
      return;
    }

    Completer<fidl.ChatStatus> statusCompleter =
        new Completer<fidl.ChatStatus>();
    Completer<fidl.Conversation> conversationCompleter =
        new Completer<fidl.Conversation>();
    Completer<List<fidl.Message>> messagesCompleter =
        new Completer<List<fidl.Message>>();

    // Get the conversation metadata.
    _chatContentProvider.getConversation(
      conversationId,
      true, // Wait until the conversation info is ready
      (fidl.ChatStatus status, fidl.Conversation conversation) {
        log.fine('got conversation from content provider');

        statusCompleter.complete(status);
        conversationCompleter.complete(conversation);
      },
    );

    fidl.ChatStatus status = await statusCompleter.future;

    if (status != fidl.ChatStatus.ok) {
      log.severe('ChatContentProvider::GetConversation() returned an error '
          'status: $status');
      _fetchingConversation = false;
      _conversation = null;
      notifyListeners();

      showError('Error: $status');
      return;
    }

    _conversation = await conversationCompleter.future;

    // Get the message history.
    String messageQueueToken = await _mqConversationToken.future;
    statusCompleter = new Completer<fidl.ChatStatus>();
    _chatContentProvider.getMessages(
      conversationId,
      messageQueueToken,
      (fidl.ChatStatus status, List<fidl.Message> messages) {
        statusCompleter.complete(status);
        messagesCompleter.complete(messages);
      },
    );

    status = await statusCompleter.future;
    if (status != fidl.ChatStatus.ok) {
      log.severe('ChatContentProvider::GetMessages() returned an error '
          'status: $status');
      _fetchingConversation = false;
      _conversation = null;
      notifyListeners();

      showError('Error: $status');
      return;
    }

    _fetchingConversation = false;
    notifyListeners();
  }

  /// Handle the message added / deleted event passed via the [MessageQueue].
  ///
  /// Refer to the `chat_content_provider.fidl` file for the expected message
  /// format coming from the content provider.
  void _handleConversationEvent(String message, void ack()) {
    log.fine('_handleConversationEvent call with message: $message');

    try {
      ack();

      Map<String, dynamic> decoded = JSON.decode(message);
      String event = decoded['event'];
      String title = decoded['title'];

      switch (event) {
        // Ignore these events.
        case 'add':
        case 'delete':
        case 'delete_conversation':
          break;

        case 'title':
          if (_conversation != null) {
            _conversation = new fidl.Conversation(
              title: title,
              conversationId: _conversation.conversationId,
              participants: _conversation.participants,
            );
          }
          notifyListeners();
          break;

        default:
          log.severe('Not a valid conversation event: $event');
          break;
      }
    } on Exception catch (e) {
      log.severe('Error occurred while processing the message received via the '
          'message queue: $e');
    }
  }

  @override
  Future<Null> onStop() async {
    if (_mqConversationToken.isCompleted) {
      String messageQueueToken = await _mqConversationToken.future;
      _chatContentProvider.unsubscribe(messageQueueToken);
    }

    _mqConversationEvents.ctrl.close();
    _mqConversationReceiver.close();
    _chatContentProvider.ctrl.close();
    _chatContentProviderController.ctrl.close();

    super.onStop();
  }

  @override
  Future<Null> onNotify(String json) async {
    Object decodedJson = JSON.decode(json);

    // See if the content provider url is provided. This must be done only once,
    // when the Link notification is provided for the first time.
    if (!_contentProviderUrlCompleter.isCompleted) {
      String contentProviderUrl;
      if (decodedJson is Map) {
        contentProviderUrl = decodedJson['content_provider_url'];
      }
      _contentProviderUrlCompleter.complete(contentProviderUrl);
    }

    List<int> conversationId;
    if (decodedJson is Map && decodedJson['conversation_id'] is List<int>) {
      conversationId = decodedJson['conversation_id'];
    }

    // The conversation ID must be set after the module model initialization is
    // finished.
    await _readyCompleter.future;

    _setConversationId(conversationId);
  }

  /// Sets the current conversation title to the specified one.
  void setConversationTitle(String title) {
    _chatContentProvider.setConversationTitle(
      conversationId,
      title,
      (fidl.ChatStatus status) {
        if (status != fidl.ChatStatus.ok) {
          showError('Error while setting conversation title: $status');
        }
      },
    );
  }

  /// Shows the given error message using snack bar.
  void showError(String message) {
    scaffoldKey.currentState?.showSnackBar(new SnackBar(
      content: new Text(message),
      duration: _kErrorDuration,
    ));
  }
}
