// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert' show JSON;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lib.agent.fidl.agent_controller/agent_controller.fidl.dart';
import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.component.fidl/message_queue.fidl.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.module.fidl/module_controller.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.surface.fidl/surface.fidl.dart';
import 'package:collection/collection.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:models/user.dart';
import 'package:topaz.app.chat.services/chat_content_provider.fidl.dart'
    as chat_fidl;

import '../models.dart';

const String _kChatContentProviderUrl =
    'file:///system/apps/chat_content_provider';
const String _kChatConversationModuleUrl =
    'file:///system/apps/chat_conversation';

/// A [ModuleModel] providing chat conversation list specific data to the
/// descendant widgets.
class ChatConversationListModuleModel extends ModuleModel {
  static final ListEquality<int> _intListEquality = const ListEquality<int>();

  final AgentControllerProxy _chatContentProviderController =
      new AgentControllerProxy();

  final chat_fidl.ChatContentProviderProxy _chatContentProvider =
      new chat_fidl.ChatContentProviderProxy();

  final ModuleControllerProxy _conversationModuleController =
      new ModuleControllerProxy();

  final MessageQueueProxy _messageQueue = new MessageQueueProxy();
  MessageReceiverImpl _messageQueueReceiver;
  final Completer<String> _mqTokenCompleter = new Completer<String>();

  Uint8List _conversationId;

  Set<Conversation> _conversations;

  /// A temporary [Queue] for holding the new conversation notified via
  /// [MessageQueue], while the conversation list is being fetched.
  ///
  /// This is necessary because the message queue notification can arrive before
  /// the initial list of conversations are fetched.
  final Queue<Conversation> _newConversationQueue = new Queue<Conversation>();

  /// Indicates whether the spinner UI should be shown.
  bool get shouldDisplaySpinner => _isDownloading || _isFetching;

  /// Indicates whether Ledger is currently downloading the conversations page
  /// data from the cloud.
  bool _isDownloading = false;

  /// Indicates whether the data is being fetched from the local Ledger.
  bool _isFetching = true;

  /// Gets the [ChatContentProvider] service provided by the agent.
  chat_fidl.ChatContentProvider get chatContentProvider => _chatContentProvider;

  /// Gets and sets the current conversation id value.
  Uint8List get conversationId => _conversationId;

  /// Sets the current conversation id value.
  void setConversationId(List<int> id, {bool updateLink: true}) {
    Uint8List newId = id == null ? null : new Uint8List.fromList(id);
    if (!_intListEquality.equals(_conversationId, newId)) {
      _conversationId = newId;

      // Set the value to Link.
      if (updateLink) {
        link.set(null, JSON.encode(id));
      }

      notifyListeners();
    }
  }

  /// Focuses the conversation module
  void focusConversation() {
    _conversationModuleController.focus();
  }

  /// Compare the given two [Conversation]s for sorting.
  ///
  /// In the current implementation, it compares their conversation ids to be
  /// consistent with the way the information is stored in Ledger. This can
  /// change in the future, for example to place the most recently seen
  /// conversation at the top.
  int _compareConversation(Conversation c1, Conversation c2) {
    // Compare the ids lexicographically.
    int minLength =
        math.min(c1.conversationId.length, c2.conversationId.length);
    for (int i = 0; i < minLength; ++i) {
      if (c1.conversationId[i] < c2.conversationId[i]) return -1;
      if (c1.conversationId[i] > c2.conversationId[i]) return 1;
    }

    if (c2.conversationId.length > minLength) return -1;
    if (c1.conversationId.length < minLength) return 1;
    return 0;
  }

  /// Gets the set of chat conversations.
  ///
  /// Returns null when the conversation list is not yet retrieved.
  /// The returned [Set] is sorted by the [_compareConversation] method above.
  Set<Conversation> get conversations => _conversations == null
      ? null
      : new UnmodifiableSetView<Conversation>(_conversations);

  bool _shouldShowNewConversationForm = false;

  /// Indicates whether the conversation list screen should show the new
  /// conversation form.
  bool get shouldShowNewConversationForm => _shouldShowNewConversationForm;

  Uint8List _lastCreatedConversationId;

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) {
    super.onReady(moduleContext, link, incomingServices);

    log.fine('ModuleModel::onReady call.');
    // Start the chat conversation module.
    _startConversationModule();

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

    // Obtain a message queue.
    componentContext.obtainMessageQueue(
      'chat_conversation_list',
      _messageQueue.ctrl.request(),
    );
    // Save the message queue token for later use.
    _messageQueue.getToken((String token) => _mqTokenCompleter.complete(token));
    _messageQueueReceiver = new MessageReceiverImpl(
      messageQueue: _messageQueue,
      onReceiveMessage: _handleConversationListEvent,
    );

    // Close all the unnecessary bindings.
    contentProviderServices.ctrl.close();
    componentContext.ctrl.close();

    _fetchConversations();
  }

  /// Start the chat_conversation module in story shell.
  void _startConversationModule() {
    moduleContext.startModuleInShell(
      'chat_conversation',
      _kChatConversationModuleUrl,
      null, // Pass on our default link to the child.
      null,
      null,
      _conversationModuleController.ctrl.request(),
      new SurfaceRelation()
        ..arrangement = SurfaceArrangement.copresent
        ..dependency = SurfaceDependency.dependent
        ..emphasis = 2.0,
      false,
    );
  }

  /// Fetches the conversation list from the content provider. Also provide our
  /// message queue token to the agent so that the agent can notify us whenever
  /// a new conversation is added.
  ///
  /// The returned conversations will be stored in the [conversations] list.
  Future<Null> _fetchConversations() async {
    log.fine('_fetchConversations call.');

    try {
      _isFetching = true;

      String messageQueueToken = await _mqTokenCompleter.future;
      Completer<chat_fidl.ChatStatus> statusCompleter =
          new Completer<chat_fidl.ChatStatus>();
      List<chat_fidl.Conversation> conversations;
      chatContentProvider.getConversations(
        messageQueueToken,
        (
          chat_fidl.ChatStatus s,
          List<chat_fidl.Conversation> c,
        ) {
          log.fine('getConversations callback.');
          statusCompleter.complete(s);
          conversations = c;
        },
      );

      chat_fidl.ChatStatus status = await statusCompleter.future;

      // TODO(youngseokyoon): properly communicate the error status to the
      // user. (https://fuchsia.atlassian.net/browse/SO-365)
      if (status != chat_fidl.ChatStatus.ok) {
        log.severe('ChatContentProvider::GetConversations() returned an error '
            'status: $status');
        _conversations = null;
        notifyListeners();
        return;
      }

      // Use a SplayTreeSet to keep the list of conversations ordered.
      _conversations = conversations == null
          ? null
          : new SplayTreeSet<Conversation>.from(
              conversations.map(_getConversationFromFidl),
              _compareConversation,
            );

      if (_conversations != null) {
        while (_newConversationQueue.isNotEmpty) {
          _addConversation(_newConversationQueue.removeFirst());
        }
      }

      notifyListeners();
    } finally {
      _isFetching = false;
    }
  }

  /// Handles the conversation list level event passed via the [MessageQueue].
  ///
  /// Refer to the `chat_content_provider.fidl` file for the expected message
  /// format coming from the content provider.
  void _handleConversationListEvent(String message, void ack()) {
    log.fine('_handleConversationListEvent call with message: $message');

    try {
      ack();

      Map<String, dynamic> decoded = JSON.decode(message);
      String event = decoded['event'];
      switch (event) {
        case 'new_conversation':
          List<int> conversationId = decoded['conversation_id'];
          List<String> participants = decoded['participants'];

          Conversation newConversation = new Conversation(
            conversationId: conversationId,
            participants: participants.map(_getUserFromEmail).toList(),
          );

          if (_conversations != null) {
            _addConversation(newConversation);
          } else {
            _newConversationQueue.add(newConversation);
          }
          break;

        case 'download_status':
          String downloadStatus = decoded['status'];
          log.fine('Download status: $downloadStatus');
          switch (downloadStatus) {
            case 'idle':
              _isDownloading = false;
              break;

            case 'pending':
            case 'in_progress':
              _isDownloading = true;
              break;

            case 'error':
              _isDownloading = false;
              log.severe('Ledger data download failed: $downloadStatus');
              break;

            default:
              log.severe('Unknown download status: $downloadStatus');
              break;
          }
          notifyListeners();
          break;

        default:
          log.severe('Not a valid conversation list event: $event');
          break;
      }
    } catch (e, stackTrace) {
      log.severe('Decoding error while processing the message', e, stackTrace);
    }
  }

  void _addConversation(Conversation conversation) {
    assert(_conversations != null);

    // Because we are using a [Set], duplicate conversation will not be added.
    _conversations.add(conversation);

    List<int> id = conversation.conversationId;

    // If this conversation happens to be the last created conversation
    // from the current user, select it immediately. If not, just notify
    // that there is a new conversation added.
    if (_intListEquality.equals(_lastCreatedConversationId, id)) {
      _lastCreatedConversationId = null;
      // No need to notify here, because setConversationId does it.
      setConversationId(id);
      focusConversation();
    } else {
      notifyListeners();
    }
  }

  // TODO(youngseokyoon): get the last message and fill in the info.
  Conversation _getConversationFromFidl(chat_fidl.Conversation c) =>
      new Conversation(
        conversationId: c.conversationId,
        participants: c.participants.map(_getUserFromEmail).toList(),
      );

  User _getUserFromEmail(String email) => new User(
        email: email,
        name: email,
        picture: null,
      );

  @override
  void onStop() {
    _messageQueue.ctrl.close();
    _messageQueueReceiver.close();
    _conversationModuleController.ctrl.close();
    _chatContentProvider.ctrl.close();
    _chatContentProviderController.ctrl.close();

    super.onStop();
  }

  @override
  void onNotify(String json) {
    setConversationId(JSON.decode(json), updateLink: false);
  }

  /// Shows the new conversation form.
  void showNewConversationForm() {
    _shouldShowNewConversationForm = true;
    notifyListeners();
  }

  /// Hides the new conversation form.
  void hideNewConversationForm() {
    _shouldShowNewConversationForm = false;
    notifyListeners();
  }

  /// Create a new conversation with the specified participant emails.
  void newConversation(List<String> participants) {
    _chatContentProvider.newConversation(
      participants,
      (chat_fidl.ChatStatus status, chat_fidl.Conversation conversation) {
        // TODO(youngseokyoon): properly communicate the error status to the
        // user. (https://fuchsia.atlassian.net/browse/SO-365)
        if (status != chat_fidl.ChatStatus.ok) {
          log.severe('ChatContentProvider::NewConversation() returned an error '
              'status: $status');
          return;
        }

        // The intended behavior is to auto-select the newly created
        // conversation when it is successfully created. However, we don't know
        // whether the `_handleNewConversation()` notification or this callback
        // of `newConversation()` call will come first.
        //
        // In order to account for both scenarios, if the created conversation
        // id is already in our list of conversation ids, just select that
        // conversation right away. If not, store the id in a temporary variable
        // and select it later when the conversation is notified via the message
        // queue mechanism.
        if (conversations != null &&
            conversations.any((Conversation c) => _intListEquality.equals(
                  c.conversationId,
                  conversation.conversationId,
                ))) {
          setConversationId(conversation.conversationId);
          focusConversation();
        } else {
          _lastCreatedConversationId = new Uint8List.fromList(
            conversation.conversationId,
          );
        }
      },
    );
  }

  /// Callback that handles the user submitting a new conversation form
  void handleNewConversationFormSubmit(List<String> participants) {
    hideNewConversationForm();
    newConversation(participants);
  }
}
