// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:typed_data';

import 'package:collection/collection.dart';
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

  final Completer<Null> _readyCompleter = new Completer<Null>();

  Uint8List _conversationId;

  /// Gets the current conversation id value.
  Uint8List get conversationId => _conversationId;

  /// Sets the current conversation id value.
  void _setConversationId(List<int> id) {
    Uint8List newId = id == null ? null : new Uint8List.fromList(id);

    if (!_intListEquality.equals(_conversationId, newId)) {
      // Unsubscribe to get no further notification on the old conversation.
      if (_mqConversationToken.isCompleted) {
        _mqConversationToken.future.then(_chatContentProvider.unsubscribe);
      }

      _conversationId = newId;

      // TODO(youngseokyoon): Update the UI with the new conversation data.
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
      onReceiveMessage: (String message, void ack()) {
        // TODO(youngseokyoon): Properly handle the events.
        ack();
      },
    );
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
}
