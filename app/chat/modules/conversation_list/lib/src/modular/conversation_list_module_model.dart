// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert' show json;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:entity_schemas/entities.dart' as entities;
import 'package:flutter/material.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.app.dart/app.dart';
import 'package:fuchsia.fidl.component/component.dart';
import 'package:lib.component.dart/component.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module_resolver.dart/daisy_builder.dart';
import 'package:lib.story.dart/story.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:fuchsia.fidl.chat_content_provider/chat_content_provider.dart'
    as chat_fidl;

import '../models.dart';

const String _kChatContentProviderUrl = 'chat_content_provider';
const String _kChatConversationModuleUrl = 'chat_conversation';

const Duration _kErrorDuration = const Duration(seconds: 10);

/// A [ModuleModel] providing chat conversation list specific data to the
/// descendant widgets.
class ChatConversationListModuleModel extends ModuleModel {
  static final ListEquality<int> _intListEquality = const ListEquality<int>();

  /// Creates a new instance of [ChatConversationListModuleModel].
  ChatConversationListModuleModel({@required this.formModel})
      : assert(formModel != null) {
    formModel.textController.addListener(() {
      handleNewConversationFormChanged(formModel.textController.text);
    });
  }

  final AgentControllerProxy _chatContentProviderController =
      new AgentControllerProxy();

  final chat_fidl.ChatContentProviderProxy _chatContentProvider =
      new chat_fidl.ChatContentProviderProxy();

  final ModuleControllerProxy _conversationModuleController =
      new ModuleControllerProxy();

  final ModuleControllerProxy _pickerModuleController =
      new ModuleControllerProxy();

  final EntityResolverProxy _entityResolver = new EntityResolverProxy();

  final LinkWatcherBinding _pickerWatcherBinding = new LinkWatcherBinding();

  final LinkProxy _pickerLink = new LinkProxy();

  final MessageQueueProxy _messageQueue = new MessageQueueProxy();
  MessageReceiverImpl _messageQueueReceiver;
  final Completer<String> _mqTokenCompleter = new Completer<String>();

  Uint8List _conversationId;

  Map<List<int>, Conversation> _conversations;

  /// A temporary [Queue] for holding the new conversation notified via
  /// [MessageQueue], while the conversation list is being fetched.
  ///
  /// This is necessary because the message queue notification can arrive before
  /// the initial list of conversations are fetched.
  final Queue<Conversation> _newConversationQueue = new Queue<Conversation>();

  /// The title value to be displayed at the top of the conversation list.
  String get title => _title;
  String _title;

  /// Indicates whether the spinner UI should be shown.
  bool get shouldDisplaySpinner => _isDownloading || _isFetching;

  /// Indicates whether Ledger is currently downloading the conversations page
  /// data from the cloud.
  bool _isDownloading = false;

  /// Indicates whether the data is being fetched from the local Ledger.
  bool _isFetching = true;

  /// Indicates whether the agent sent an unrecoverable error.
  bool get unrecoverable => _unrecoverable;
  set unrecoverable(bool value) {
    if (_unrecoverable != value) {
      _unrecoverable = value;
      if (value) {
        _conversationModuleController?.defocus();
      }
      notifyListeners();
    }
  }

  bool _unrecoverable = false;

  /// The form model.
  final FormModel formModel;

  /// The key to be used for scaffold.
  GlobalKey<ScaffoldState> get scaffoldKey => _scaffoldKey;
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  /// Gets the [ChatContentProvider] service provided by the agent.
  chat_fidl.ChatContentProvider get chatContentProvider => _chatContentProvider;

  /// Gets the [ChildViewConnection] to the contacts picker mod.
  ChildViewConnection get pickerConnection => _pickerConnection;
  ChildViewConnection _pickerConnection;

  /// Gets and sets the current conversation id value.
  Uint8List get conversationId => _conversationId;

  /// Sets the current conversation id value.
  void setConversationId(List<int> id, {bool updateLink: true}) {
    log.info('setting conversation id to: $id');
    Uint8List newId = id == null ? null : new Uint8List.fromList(id);
    if (!_intListEquality.equals(_conversationId, newId)) {
      _conversationId = newId;

      // Set the value to Link.
      if (updateLink) {
        link.set(const <String>['conversation_id'], json.encode(id));
      }

      // Start the child conversation, if it hasn't been started yet.
      if (!_conversationModuleStarted) {
        _startConversationModule();
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
    return _compareConversationId(c1.conversationId, c2.conversationId);
  }

  int _compareConversationId(List<int> id1, List<int> id2) {
    // Compare the ids lexicographically.
    int minLength = math.min(id1.length, id2.length);
    for (int i = 0; i < minLength; ++i) {
      if (id1[i] < id2[i]) {
        return -1;
      }
      if (id1[i] > id2[i]) {
        return 1;
      }
    }

    if (id2.length > minLength) {
      return -1;
    }
    if (id1.length < minLength) {
      return 1;
    }
    return 0;
  }

  /// Gets the set of chat conversations.
  ///
  /// Returns null when the conversation list is not yet retrieved.
  /// The returned [Set] is sorted by the [_compareConversation] method above.
  Set<Conversation> get conversations => _conversations == null
      ? null
      : new UnmodifiableSetView<Conversation>(_conversations.values.toSet());

  /// Indicates whether the conversation list screen should show the new
  /// conversation form.
  bool get shouldShowNewConversationForm => _shouldShowNewConversationForm;
  bool _shouldShowNewConversationForm = false;

  /// Indicates whether we should automatically select a conversation.
  bool _shouldAutoSelectConversation = false;

  /// Indicates whether the child conversation module has been started.
  bool _conversationModuleStarted = false;

  Uint8List _lastCreatedConversationId;

  /// Completer for the content provider url provided by the Link. This must be
  /// completed when onNotify() is called for the first time.
  final Completer<String> _contentProviderUrlCompleter =
      new Completer<String>();

  /// Indicates whether the contacts picker should be shown on screen.
  bool get shouldShowContactsPicker =>
      shouldShowNewConversationForm && formModel.textController.text.isNotEmpty;

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

    // Get the conversation title.
    _chatContentProvider.getTitle((String title) {
      _title = title;
      notifyListeners();
    });

    // Obtain a message queue.
    componentContext.obtainMessageQueue(
      'chat_conversation_list',
      _messageQueue.ctrl.request(),
    );
    // Save the message queue token for later use.
    _messageQueue.getToken(_mqTokenCompleter.complete);
    _messageQueueReceiver = new MessageReceiverImpl(
      messageQueue: _messageQueue,
      onReceiveMessage: _handleConversationListEvent,
    );

    // Obtain the entity resolver.
    componentContext.getEntityResolver(_entityResolver.ctrl.request());

    // Close all the unnecessary bindings.
    contentProviderServices.ctrl.close();
    componentContext.ctrl.close();

    // Start the contacts picker. We'll start it early and reuse it, instead of
    // launching it every time when it's needed.
    _startContactsPicker();

    // ignore: unawaited_futures
    _fetchConversations();
  }

  /// Start the chat_conversation module in story shell.
  void _startConversationModule() {
    moduleContext.startModuleInShellDeprecated(
      'chat_conversation',
      _kChatConversationModuleUrl,
      null, // Pass on our default link to the child.
      null,
      _conversationModuleController.ctrl.request(),
      const SurfaceRelation(
        arrangement: SurfaceArrangement.copresent,
        dependency: SurfaceDependency.dependent,
        emphasis: 2.0,
      ),
      false,
    );
    _conversationModuleStarted = true;
  }

  /// Starts the contacts picker using Daisy.
  void _startContactsPicker() {
    String name = 'contacts_picker';

    Map<String, String> prefixEntity = <String, String>{
      '@type': 'com.google.fuchsia.string',
      'content': '',
    };
    Map<String, String> detailTypeEntity = <String, String>{
      '@type': 'com.google.fuchsia.string',
      'content': 'email',
    };

    DaisyBuilder daisyBuilder =
        new DaisyBuilder.verb('com.google.fuchsia.pick-contacts')
          ..addNoun('prefix', prefixEntity)
          ..addNoun('detailType', detailTypeEntity);

    InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
    moduleContext
      ..embedModule(
        name, // mod name
        daisyBuilder.daisy,
        null,  // incomingServices
        _pickerModuleController.ctrl.request(),
        viewOwner.passRequest(),
        (StartModuleStatus status) {
          // Handle daisy resolution here
          log.info('Start daisy status = $status');
        },
      )
      ..getLink(name, _pickerLink.ctrl.request());

    // Register a LinkWatcher, which would read the selected contact.
    LinkWatcherImpl watcher = new LinkWatcherImpl(onNotify: (String encoded) {
      Object jsonObject = json.decode(encoded);
      if (jsonObject is Map<String, Object> &&
          jsonObject['selectedContact'] is String) {
        String entityReference = jsonObject['selectedContact'];
        _handleSelectedContact(entityReference);
      }
    });

    _pickerLink.watch(_pickerWatcherBinding.wrap(watcher));

    _pickerConnection = new ChildViewConnection(viewOwner.passHandle());
    notifyListeners();
  }

  /// Handles the selected contact from the contacts picker.
  Future<Null> _handleSelectedContact(String entityReference) async {
    EntityProxy entity = new EntityProxy();
    _entityResolver.resolveEntity(entityReference, entity.ctrl.request());

    // Assume that the returned entity would have 'Contact' type.
    Completer<List<String>> typesCompleter = new Completer<List<String>>();
    entity.getTypes(typesCompleter.complete);
    List<String> types = await typesCompleter.future;

    if (!types.contains('Contact')) {
      log.warning('The selected entity does not provide the "Contact" type.');
      return;
    }

    Completer<String> dataCompleter = new Completer<String>();
    entity.getData('Contact', dataCompleter.complete);
    String data = await dataCompleter.future;

    try {
      entities.Contact contact = new entities.Contact.fromData(data);
      String email = contact.primaryEmail?.value;
      if (email != null) {
        formModel.addNewParticipants(null, email, refocus: false);
      }
    } on Exception catch (e, stackTrace) {
      log.warning('Failed to decode contact data: $data', e, stackTrace);
    }

    _pickerLink.erase(const <String>['selectedContact']);

    moduleContext.requestFocus();
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

      if (status != chat_fidl.ChatStatus.ok) {
        log.severe('ChatContentProvider::GetConversations() returned an error '
            'status: $status');
        _conversations = null;

        if (status == chat_fidl.ChatStatus.unrecoverableError) {
          unrecoverable = true;
        }

        notifyListeners();

        showError('Error: $status');
        return;
      }

      // Use a SplayTreeMap to keep the list of conversations ordered.
      _conversations = null;
      if (conversations != null) {
        _conversations =
            new SplayTreeMap<List<int>, Conversation>(_compareConversationId);
        for (Conversation c in conversations.map(_getConversationFromFidl)) {
          _conversations[c.conversationId] = c;
        }

        while (_newConversationQueue.isNotEmpty) {
          _addConversation(_newConversationQueue.removeFirst());
        }

        if (_shouldAutoSelectConversation && _conversations.isNotEmpty) {
          setConversationId(_conversations.values.first.conversationId);
          _shouldAutoSelectConversation = false;
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

      Map<String, dynamic> decoded = json.decode(message);
      String event = decoded['event'];
      switch (event) {
        case 'new_conversation':
          List<int> conversationId = decoded['conversation_id'];
          List<Map<String, String>> participants = decoded['participants'];
          String title = decoded['title'];

          Conversation newConversation = new Conversation(
            conversationId: conversationId,
            participants: participants.map(_getUserFromParticipantMap).toList(),
            title: title,
          );

          if (_conversations != null) {
            _addConversation(newConversation);
            if (_shouldAutoSelectConversation) {
              setConversationId(newConversation.conversationId);
              _shouldAutoSelectConversation = false;
            }
          } else {
            _newConversationQueue.add(newConversation);
          }
          break;

        case 'delete_conversation':
          List<int> conversationId = decoded['conversation_id'];
          _conversations.remove(conversationId);

          // If the given conversation is the currently selected one, attempt to
          // auto-select another conversation.
          if (_intListEquality.equals(_conversationId, conversationId)) {
            if (_conversations.isNotEmpty) {
              setConversationId(_conversations.keys.first);
            } else {
              setConversationId(null);
              _conversationModuleController?.defocus();
              _shouldAutoSelectConversation = true;
            }
          } else {
            notifyListeners();
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

        case 'conversation_meta':
          List<int> conversationId = decoded['conversation_id'];
          log.fine('conversation_meta event with id: $conversationId');

          // Fetch the full conversation metadata.
          _chatContentProvider.getConversation(
            conversationId,
            false,
            (chat_fidl.ChatStatus status, chat_fidl.Conversation conversation) {
              if (status != chat_fidl.ChatStatus.ok) {
                log.warning('GetConversation() call failed', status);
                return;
              }

              _conversations[conversationId] =
                  _getConversationFromFidl(conversation);
              notifyListeners();
            },
          );
          break;

        default:
          log.severe('Not a valid conversation list event: $event');
          break;
      }
    } on Exception catch (e, stackTrace) {
      log.severe('Decoding error while processing the message', e, stackTrace);
    }
  }

  void _addConversation(Conversation conversation) {
    assert(_conversations != null);

    // Because we are using a [Map], duplicate conversation will not be added.
    _conversations[conversation.conversationId] = conversation;

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
        title: c.title,
        participants: c.participants.map(_getUserFromParticipant).toList(),
      );

  User _getUserFromParticipant(chat_fidl.Participant participant) {
    Map<String, String> json = <String, String>{
      'email': participant.email,
      'name': participant.displayName,
      'picture': participant.photoUrl,
    };

    return new User.fromJson(json);
  }

  User _getUserFromParticipantMap(Map<String, String> participantMap) =>
      _getUserFromParticipant(
        new chat_fidl.Participant(
            email: participantMap['email'],
            displayName: participantMap['displayName'],
            photoUrl: participantMap['photoUrl']),
      );

  @override
  void onStop() {
    _messageQueue.ctrl.close();
    _messageQueueReceiver.close();
    _conversationModuleController.ctrl.close();
    _pickerWatcherBinding.close();
    _pickerLink.ctrl.close();
    _pickerModuleController.ctrl.close();
    _chatContentProvider.ctrl.close();
    _chatContentProviderController.ctrl.close();
    _entityResolver.ctrl.close();

    super.onStop();
  }

  @override
  void onNotify(String encoded) {
    Object decodedJson = json.decode(encoded);

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

    setConversationId(conversationId, updateLink: false);
    if (conversationId == null) {
      _shouldAutoSelectConversation = true;
    }
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
  void newConversation(List<chat_fidl.Participant> participants) {
    _chatContentProvider.newConversation(
      participants,
      (chat_fidl.ChatStatus status, chat_fidl.Conversation conversation) {
        if (status != chat_fidl.ChatStatus.ok) {
          log.severe('ChatContentProvider::NewConversation() returned an error '
              'status: $status');

          if (status == chat_fidl.ChatStatus.unrecoverableError) {
            unrecoverable = true;
          } else {
            showError('Error: $status');
          }

          return;
        }

        // The intended behavior is to auto-select the newly created
        // conversation when it is successfully created. However, we don't know
        // whether the `_handleConversationListEvent()` notification or this
        // callback of `newConversation()` call will come first.
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

  /// Callback that handles the text change event in the new conversation form.
  void handleNewConversationFormChanged(String text) {
    // Update the link data for contacts picker.
    _pickerLink.updateObject(
      const <String>['prefix'],
      json.encode(<String, String>{'content': text}),
    );

    // Notify listeners so that the contacts picker can be shown or hidden
    // depending on the text (should be hidden when the text is empty).
    notifyListeners();
  }

  /// Callback that handles the user submitting a new conversation form
  void handleNewConversationFormSubmit(List<String> emails) {
    hideNewConversationForm();

    List<chat_fidl.Participant> participants = emails.map((String email) {
      return new chat_fidl.Participant(email: email);
    }).toList();

    newConversation(participants);
  }

  /// Delete the specified conversation.
  void deleteConversation(List<int> conversationId) {
    _chatContentProvider.deleteConversation(
      conversationId,
      (chat_fidl.ChatStatus status) {
        if (status != chat_fidl.ChatStatus.ok) {
          if (status == chat_fidl.ChatStatus.unrecoverableError) {
            unrecoverable = true;
          } else {
            showError('Error: $status');
          }
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
