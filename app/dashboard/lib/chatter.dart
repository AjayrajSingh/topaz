// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:fuchsia.fidl.chat_content_provider/chat_content_provider.dart'
    as chat;
import 'package:fuchsia.fidl.component/component.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.module_resolver.dart/intent_builder.dart';

const String _kChatContentProviderUrl = 'chat_content_provider';
const String _kChatConversationModuleUrl = 'chat_conversation';

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
  ModuleControllerProxy _chatModuleControllerProxy;

  /// Constructor.
  Chatter(this.moduleContext);

  /// Launches the chat module.
  void launchChat() {
    if (_chatModuleControllerProxy != null) {
      _chatModuleControllerProxy.focus();
      return;
    }
    _chatModuleControllerProxy = new ModuleControllerProxy();

    const String chatLinkName = 'chatLink';
    IntentBuilder intentBuilder = new IntentBuilder.handler(_kChatConversationModuleUrl)
      ..addParameterFromLink(null /* default link */, chatLinkName);

    LinkProxy linkProxy = new LinkProxy();
    moduleContext
      ..getLink(chatLinkName, linkProxy.ctrl.request())
      ..startModule(
        'module:chat',
        intentBuilder.intent,
        null, // incomingServices,
        _chatModuleControllerProxy.ctrl.request(),
        const SurfaceRelation(
          arrangement: SurfaceArrangement.copresent,
          emphasis: 0.5,
        ),
        (StartModuleStatus status) {}
      );

    _getConversationId().then((List<int> conversationId) {
      if (conversationId == null) {
        log.severe('Failed to get conversation id.');
        _chatModuleControllerProxy?.ctrl?.close();
        _chatModuleControllerProxy = null;
        return;
      }
      log.fine('Creating convo with id: $conversationId');

      linkProxy
        ..set(<String>[], json.encode(conversationId))
        ..ctrl.close();
    });
  }

  /// Closes the chat module.
  void closeChat() {
    _chatModuleControllerProxy?.defocus();
  }

  /// Closes any open handles.
  void onStop() {
    _chatContentProviderController.ctrl.close();
    _chatContentProvider.ctrl.close();
    _chatModuleControllerProxy?.ctrl?.close();
    _chatModuleControllerProxy = null;
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
          log.severe('Couldn\'t retrieve existing accounts!');
          completer.complete(null);
        } else {
          List<chat.Conversation> conversationsWithFuchsia = conversations
              .where(
                (chat.Conversation conversation) =>
                    const ListEquality<String>().equals(
                      conversation.participants
                          .map((chat.Participant p) => p.email)
                          .toList(),
                      _kDashboardParticipants,
                    ),
              )
              .toList();
          if (conversationsWithFuchsia.length == 1) {
            log.fine(
                'Found chat with id: ${conversationsWithFuchsia[0].conversationId}');
            completer.complete(conversationsWithFuchsia[0].conversationId);
          } else {
            log.fine('No existing chat, create a new one!');
            _chatContentProvider.newConversation(
              _kDashboardParticipants
                  .map((String email) => new chat.Participant(email: email))
                  .toList(),
              (chat.ChatStatus status, chat.Conversation conversation) {
                if (status != chat.ChatStatus.ok) {
                  log.severe('Couldn\'t create new chat!');
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
