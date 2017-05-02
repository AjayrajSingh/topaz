// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.agent.agent_controller/agent_controller.fidl.dart';
import 'package:apps.modular.services.component/component_context.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modules.chat.services/chat_content_provider.fidl.dart'
    as chat;
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:collection/collection.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'debug.dart';

const String _kChatContentProviderUrl =
    'file:///system/apps/chat_content_provider';
const String _kChatConversationModuleUrl =
    'file:///system/apps/chat_conversation';

const List<String> _kDashboardParticipants = const <String>[
  'fuchsia_dashboard@google.com'
];

/// Communicates with the chat service to get a chat module connection.
class Chatter {
  /// The Module's context for getting the chat services.
  final ModuleContext moduleContext;

  final AgentControllerProxy _chatContentProviderController =
      new AgentControllerProxy();
  final chat.ChatContentProviderProxy _chatContentProvider =
      new chat.ChatContentProviderProxy();
  final ModuleControllerProxy _chatModuleController =
      new ModuleControllerProxy();

  /// Constructor.
  Chatter(this.moduleContext);

  /// Closes any open handles.
  void onStop() {
    _chatContentProviderController.ctrl.close();
    _chatContentProvider.ctrl.close();
    _chatModuleController.ctrl.close();
  }

  /// Creates a child view connection for embedding the chat module.  Returns
  /// null if somethign went wrong.
  Future<ChildViewConnection> load() async {
    List<int> conversationId = await _getConversationId();
    if (conversationId == null) {
      dashboardPrint('ERROR: Failed to get conversation id.');
      return null;
    }
    dashboardPrint('Creating convo with id: $conversationId');

    LinkProxy linkProxy = new LinkProxy();
    const String chatLinkName = 'chatLink';
    moduleContext.getLink(chatLinkName, linkProxy.ctrl.request());
    linkProxy
      ..set(<String>[], JSON.encode(conversationId))
      ..ctrl.close();

    final InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();

    moduleContext.startModule(
      'chat',
      _kChatConversationModuleUrl,
      chatLinkName,
      null,
      null,
      _chatModuleController.ctrl.request(),
      viewOwner.passRequest(),
    );

    ChildViewConnection connection = new ChildViewConnection(
      viewOwner.passHandle(),
      onAvailable: (ChildViewConnection connection) {},
      onUnavailable: (ChildViewConnection connection) {},
    );
    return connection;
  }

  /// Finds or creates the chat id for the dashboard.
  Future<List<int>> _getConversationId() async {
    Completer<List<int>> completer = new Completer<List<int>>();
    // Obtain the component context.
    ComponentContextProxy componentContext = new ComponentContextProxy();
    moduleContext.getComponentContext(componentContext.ctrl.request());

    // Obtain the ChatContentProvider service.
    ServiceProviderProxy contentProviderServices = new ServiceProviderProxy();
    componentContext.connectToAgent(
      _kChatContentProviderUrl,
      contentProviderServices.ctrl.request(),
      _chatContentProviderController.ctrl.request(),
    );
    connectToService(contentProviderServices, _chatContentProvider.ctrl);
    contentProviderServices.ctrl.close();
    componentContext.ctrl.close();

    _chatContentProvider.getConversations(
      null,
      (
        chat.ChatStatus status,
        List<chat.Conversation> conversations,
      ) {
        if (status != chat.ChatStatus.ok) {
          dashboardPrint('Couldn\'t retrieve existing accounts!');
          completer.complete(null);
        } else {
          List<chat.Conversation> conversationsWithFuchsia = conversations
              .where(
                (chat.Conversation conversation) =>
                    const ListEquality<String>().equals(
                      conversation.participants,
                      _kDashboardParticipants,
                    ),
              )
              .toList();
          if (conversationsWithFuchsia.length == 1) {
            dashboardPrint(
                'Found chat with id: ${conversationsWithFuchsia[0].conversationId}');
            completer.complete(conversationsWithFuchsia[0].conversationId);
          } else {
            dashboardPrint('No existing chat, create a new one!');
            _chatContentProvider.newConversation(
              _kDashboardParticipants,
              (chat.ChatStatus status, chat.Conversation conversation) {
                if (status != chat.ChatStatus.ok) {
                  dashboardPrint('Couldn\'t create new chat!');
                  completer.complete(null);
                  return;
                }
                print('Created chat with id: ${conversation.conversationId}');
                completer.complete(conversation.conversationId);
              },
            );
          }
        }
      },
    );
    return completer.future;
  }
}
