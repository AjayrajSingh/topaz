// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:typed_data';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.agent.agent_controller/agent_controller.fidl.dart';
import 'package:apps.modular.services.component/component_context.fidl.dart';
import 'package:apps.modular.services.component/message_queue.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modular.services.surface/surface.fidl.dart';
import 'package:apps.modules.chat.services/chat_content_provider.fidl.dart'
    as chat_fidl;
import 'package:apps.modules.drive.services.gallery/gallery.fidl.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.fidl.dart/bindings.dart' hide Message;
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import '../models.dart';
import '../widgets.dart';

const String _kChatContentProviderUrl =
    'file:///system/apps/chat_content_provider';
const String _kGalleryModuleUrl = 'file:///system/apps/gallery';

const Duration _kScrollAnimationDuration = const Duration(milliseconds: 300);

/// A [ModuleModel] providing chat conversation specific data to the descendant
/// widgets.
class ChatConversationModuleModel extends ModuleModel {
  static final ListEquality<int> _intListEquality = const ListEquality<int>();

  final AgentControllerProxy _chatContentProviderController =
      new AgentControllerProxy();

  final chat_fidl.ChatContentProviderProxy _chatContentProvider =
      new chat_fidl.ChatContentProviderProxy();

  final MessageQueueProxy _mqConversationEvents = new MessageQueueProxy();
  MessageReceiverImpl _mqConversationReceiver;
  final Completer<String> _mqConversationToken = new Completer<String>();

  final MessageQueueProxy _mqSelectedImages = new MessageQueueProxy();
  MessageReceiverImpl _mqSelectedImagesReceiver;
  final Completer<String> _mqSelectedImagesToken = new Completer<String>();

  GalleryServiceProxy _galleryService;

  final LinkProxy _childLink = new LinkProxy();
  final LinkWatcherBinding _childLinkWatcherBinding = new LinkWatcherBinding();
  ModuleControllerProxy _childModuleController;
  String _currentChildModuleName;

  chat_fidl.Conversation _conversation;
  List<chat_fidl.Message> _messages;
  List<Section> _sections;
  bool _fetchingConversation = false;

  Uint8List _conversationId;

  /// Gets the current conversation id value.
  Uint8List get conversationId => _conversationId;

  /// Gets the list of participants in this conversation.
  List<String> get participants => _conversation != null
      ? new UnmodifiableListView<String>(_conversation.participants)
      : null;

  /// Indicates whether the fetching is in progress or not.
  bool get fetchingConversation => _fetchingConversation;

  /// Sets the current conversation id value.
  void _setConversationId(List<int> id) {
    Uint8List newId = id == null ? null : new Uint8List.fromList(id);
    if (!_intListEquality.equals(_conversationId, newId)) {
      _conversationId = newId;

      // We don't want to reuse the existing scroll controller, so create a new
      // one here. Otherwise, the scroll position will animate when jumping
      // between different conversation rooms.
      _scrollController = new ScrollController();

      // We set the conversation and messages as null and notify here first to
      // indicate the conversation id value is changed.
      _fetchingConversation = true;
      _conversation = null;
      _setMessages(null);

      // After fetching is done, a second notification will be sent out.
      _fetchConversation();
    }
  }

  /// Sets the new list of [chat_fidl.Message]s received from the agent.
  /// Calling this also recalculates the [Section]s, and notifies the listeners.
  void _setMessages(List<chat_fidl.Message> messages) {
    try {
      _messages = messages;
      if (_messages == null) {
        _sections = null;
        return;
      }

      List<chat_fidl.Message> sortedMessages =
          new List<chat_fidl.Message>.from(_messages)..sort(_compareMessages);

      _sections = createSectionsFromMessages(
        sortedMessages.map(_createMessageFromFidl).toList(),
      );
    } catch (e, stackTrace) {
      log.severe('Error occurred while setting _messages', e, stackTrace);
    } finally {
      notifyListeners();
    }
  }

  /// Gets the list of consecutive chat [Section]s in this conversation.
  List<Section> get sections => _sections == null
      ? const <Section>[]
      : new UnmodifiableListView<Section>(_sections);

  ScrollController _scrollController;

  /// Gets the [ScrollController] to be used in the [ChatConversation] widget.
  ///
  /// This is needed here because we want to programmatically manipulate the
  /// scroll position when a new message is added.
  ScrollController get scrollController => _scrollController;

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) {
    super.onReady(moduleContext, link, incomingServices);

    log.fine('ModuleModel::onReady call.');

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

    // Obtain a message queue for new messages.
    componentContext.obtainMessageQueue(
      'chat_conversation',
      _mqConversationEvents.ctrl.request(),
    );
    // Save the message queue token for later use.
    _mqConversationEvents
        .getToken((String token) => _mqConversationToken.complete(token));
    _mqConversationReceiver = new MessageReceiverImpl(
      messageQueue: _mqConversationEvents,
      onReceiveMessage: _handleConversationEvent,
    );

    // Obtain another message queue for getting notified of selected images from
    // gallery module.
    componentContext.obtainMessageQueue(
      'gallery',
      _mqSelectedImages.ctrl.request(),
    );
    // Save the message queue token for later use.
    _mqSelectedImages
        .getToken((String token) => _mqSelectedImagesToken.complete(token));
    // Start receiving stuff.
    _mqSelectedImagesReceiver = new MessageReceiverImpl(
      messageQueue: _mqSelectedImages,
      onReceiveMessage: _handleSelectedImages,
    );

    // Obtain a separate Link for storing the child module state.
    moduleContext.getLink('child', _childLink.ctrl.request());
    _childLink.watch(_childLinkWatcherBinding.wrap(new LinkWatcherImpl(
      onNotify: _onNotifyChild,
    )));

    // Close all the unnecessary bindings.
    contentProviderServices.ctrl.close();
    componentContext.ctrl.close();
  }

  /// Fetches the conversation metadata and the message history from the content
  /// provider. It also gives our message queue token to the agent so that the
  /// agent can notify us whenever a new message appears in the current
  /// conversation.
  ///
  /// The returned conversation will be stored in [_conversation], and the
  /// messages in the [_messages] list.
  Future<Null> _fetchConversation() async {
    log.fine('fetchConversation call.');

    if (conversationId == null) {
      return;
    }

    Completer<chat_fidl.ChatStatus> statusCompleter =
        new Completer<chat_fidl.ChatStatus>();
    Completer<chat_fidl.Conversation> conversationCompleter =
        new Completer<chat_fidl.Conversation>();
    Completer<List<chat_fidl.Message>> messagesCompleter =
        new Completer<List<chat_fidl.Message>>();

    // Get the conversation metadata.
    _chatContentProvider.getConversation(
      conversationId,
      true, // Wait until the conversation info is ready
      (chat_fidl.ChatStatus status, chat_fidl.Conversation conversation) {
        statusCompleter.complete(status);
        conversationCompleter.complete(conversation);
      },
    );

    // TODO(youngseokyoon): properly communicate the error status to the user.
    // https://fuchsia.atlassian.net/browse/SO-365
    chat_fidl.ChatStatus status = await statusCompleter.future;
    if (status != chat_fidl.ChatStatus.ok) {
      log.severe('ChatContentProvider::GetConversation() returned an error '
          'status: $status');
      _fetchingConversation = false;
      _conversation = null;
      _setMessages(null);
      return;
    }

    _conversation = await conversationCompleter.future;

    // Get the message history.
    String messageQueueToken = await _mqConversationToken.future;
    statusCompleter = new Completer<chat_fidl.ChatStatus>();
    _chatContentProvider.getMessages(
      conversationId,
      messageQueueToken,
      (chat_fidl.ChatStatus status, List<chat_fidl.Message> messages) {
        statusCompleter.complete(status);
        messagesCompleter.complete(messages);
      },
    );

    // TODO(youngseokyoon): properly communicate the error status to the user.
    // https://fuchsia.atlassian.net/browse/SO-365
    if (status != chat_fidl.ChatStatus.ok) {
      log.severe('ChatContentProvider::GetMessages() returned an error '
          'status: $status');
      _fetchingConversation = false;
      _conversation = null;
      _setMessages(null);
      return;
    }

    _fetchingConversation = false;
    _setMessages(
      new List<chat_fidl.Message>.from(await messagesCompleter.future),
    );
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
      List<int> conversationId = decoded['conversation_id'];
      List<int> messageId = decoded['message_id'];

      switch (event) {
        case 'add':
          // Ask for the new message content and add it to the message list.
          _chatContentProvider.getMessage(
            conversationId,
            messageId,
            (chat_fidl.ChatStatus status, chat_fidl.Message message) {
              log.fine('getMessage() callback');

              // TODO(youngseokyoon): properly communicate the error status to
              // the user. (https://fuchsia.atlassian.net/browse/SO-365)
              if (status != chat_fidl.ChatStatus.ok) {
                log.severe(
                    'ChatContentProvider::GetMessage() returned an error '
                    'status: $status');
                return;
              }

              if (message != null &&
                  _intListEquality.equals(
                      this.conversationId, conversationId)) {
                log.fine('adding the new message.');
                _setMessages(_messages..add(message));
                _scrollToEnd();
              }
            },
          );
          break;

        case 'delete':
          // Remove the message from the message list.
          if (_intListEquality.equals(this.conversationId, conversationId)) {
            log.fine('deleting an existing message.');
            _setMessages(_messages
              ..removeWhere((chat_fidl.Message m) =>
                  _intListEquality.equals(m.messageId, messageId)));
          }
          break;

        default:
          log.severe('Not a valid conversation event: $event');
          break;
      }
    } catch (e) {
      log.severe('Error occurred while processing the message received via the '
          'message queue: $e');
    }
  }

  /// Auto-scroll the chat conversation list to the end.
  ///
  /// Because the [ListView] used inside the [ChatConversation] widget is a
  /// reversed list, we can simply animate to 0.0 to scroll to end.
  void _scrollToEnd() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        curve: Curves.easeOut,
        duration: _kScrollAnimationDuration,
      );
    }
  }

  void _handleSelectedImages(String message, void ack()) {
    log.fine('handleSelectedImages: $message');

    ack();

    Map<String, dynamic> decoded = JSON.decode(message);
    if (decoded['selected_images'] != null) {
      List<String> imageUrls = decoded['selected_images'];
      imageUrls.forEach((String imageUrl) {
        log.fine('sending image url message: $imageUrl');
        _chatContentProvider.sendMessage(
          conversationId,
          'image-url',
          imageUrl,
          (_, __) => null,
        );
      });
    }

    // After adding the images, close the gallery module.
    _closeChildModule();
  }

  Message _createMessageFromFidl(chat_fidl.Message m) {
    DateTime time = new DateTime.fromMillisecondsSinceEpoch(m.timestamp);

    switch (m.type) {
      case 'text':
        return new TextMessage(
          messageId: m.messageId,
          time: time,
          sender: m.sender,
          onDelete: () {
            log.fine('TextMessage::onDelete');
            deleteMessage(m.messageId);
          },
          text: m.jsonPayload,
        );

      case 'image-url':
        return new ImageUrlMessage(
          messageId: m.messageId,
          time: time,
          sender: m.sender,
          onDelete: () {
            log.fine('ImageUrlMessage::onDelete');
            deleteMessage(m.messageId);
          },
          url: m.jsonPayload,
        );

      default:
        log.fine('Unsupported message type: ${m.type}');
        return null;
    }
  }

  static int _compareMessages(chat_fidl.Message m1, chat_fidl.Message m2) {
    if (m1.timestamp < m2.timestamp) return -1;
    if (m1.timestamp > m2.timestamp) return 1;
    return 0;
  }

  @override
  Future<Null> onStop() async {
    if (_mqConversationToken.isCompleted) {
      String messageQueueToken = await _mqConversationToken.future;
      _chatContentProvider.unsubscribe(messageQueueToken);
    }

    if (_mqSelectedImagesToken.isCompleted) {
      String messageQueueToken = await _mqSelectedImagesToken.future;
      _galleryService?.unsubscribe(messageQueueToken);
    }

    _galleryService?.ctrl?.close();
    _childModuleController?.ctrl?.close();
    _mqConversationEvents.ctrl.close();
    _mqConversationReceiver.close();
    _mqSelectedImages.ctrl.close();
    _mqSelectedImagesReceiver.close();
    _childLinkWatcherBinding.close();
    _childLink.ctrl.close();
    _chatContentProvider.ctrl.close();
    _chatContentProviderController.ctrl.close();

    super.onStop();
  }

  @override
  void onNotify(String json) {
    _setConversationId(JSON.decode(json));
  }

  /// Start or focus the gallery module on the right side.
  Future<Null> startGalleryModule() async {
    if (_currentChildModuleName == 'gallery') {
      _childModuleController.focus();
    } else {
      ServiceProviderProxy incomingServices = new ServiceProviderProxy();
      _startChildModule(
        'gallery',
        _kGalleryModuleUrl,
        incomingServices.ctrl.request(),
      );
      _galleryService = new GalleryServiceProxy();
      connectToService(incomingServices, _galleryService.ctrl);
      incomingServices.ctrl.close();

      _galleryService.subscribe(await _mqSelectedImagesToken.future);
    }
  }

  /// Start a sub-module, which will be added as a hierarchical child.
  void _startChildModule(
    String name,
    String url,
    InterfaceRequest<ServiceProvider> incomingServices,
  ) {
    _closeChildModule();
    _childModuleController = new ModuleControllerProxy();

    moduleContext.startModuleInShell(
      name,
      url,
      name,
      null,
      incomingServices,
      _childModuleController.ctrl.request(),
      new SurfaceRelation()
        ..arrangement = SurfaceArrangement.copresent
        ..dependency = SurfaceDependency.dependent
        ..emphasis = 0.5,
      true,
    );

    // Write to the child link so that this can be rehydrated later.
    _currentChildModuleName = name;
    _childLink.set(
      const <String>[],
      JSON.encode(<String, String>{'name': name, 'url': url}),
    );
  }

  /// Close an already running child module, if any.
  void _closeChildModule() {
    if (_childModuleController != null) {
      _childModuleController.stop(() => null);
      _childModuleController.ctrl.close();
      _childModuleController = null;
      _currentChildModuleName = null;
      _childLink.set(<String>[], JSON.encode(null));
    }

    if (_galleryService != null) {
      _galleryService.ctrl.close();
      _galleryService = null;
    }
  }

  Future<Null> _onNotifyChild(String json) async {
    try {
      bool shouldCloseChildModule = true;

      if (json != null) {
        dynamic decoded = JSON.decode(json);
        if (decoded is Map<String, String>) {
          String name = decoded['name'];
          String url = decoded['url'];

          if (name != null && url != null) {
            shouldCloseChildModule = false;

            ServiceProviderProxy incomingServices = new ServiceProviderProxy();

            _startChildModule(
              name,
              url,
              incomingServices.ctrl.request(),
            );

            // TODO(youngseokyoon): handle this in a more generalized way.
            if (name == 'gallery') {
              _galleryService?.ctrl?.close();
              _galleryService = new GalleryServiceProxy();
              connectToService(incomingServices, _galleryService.ctrl);

              _galleryService.subscribe(await _mqSelectedImagesToken.future);
            }

            incomingServices.ctrl.close();
          }
        }
      }

      if (shouldCloseChildModule) {
        _closeChildModule();
      }
    } catch (e, stackTrace) {
      log.severe('Could not parse the child Link data: $json', e, stackTrace);
    }
  }

  /// Sends a new message to the current conversation.
  /// Internally, it invokes the [chat_fidl.ChatContentProvider.sendMessage]
  /// method.
  void sendMessage(String message) {
    _chatContentProvider.sendMessage(
      conversationId,
      'text',
      message,
      (_, __) => null,
    );
  }

  /// Asks the content provider to delete the specified message.
  void deleteMessage(List<int> messageId) {
    _chatContentProvider.deleteMessage(conversationId, messageId, (_) => null);
  }
}
