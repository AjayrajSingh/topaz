// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fidl/fidl.dart' as fidl;
import 'package:fidl_fuchsia_contacts_contentprovider/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:fidl_fuchsia_mem/fidl.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.component.dart/component.dart';
import 'package:lib.ledger.dart/ledger.dart';
import 'package:lib.schemas.dart/com.fuchsia.contact.dart' as entities;
import 'package:meta/meta.dart';
import 'package:zircon/zircon.dart';

import '../store/contacts_store.dart';
import 'contacts_watcher.dart';
import 'entity_helpers.dart';

const String _kDataProvidersConfig =
    '/system/data/contacts/data_providers.json';

/// Ledger operations
enum _LedgerOperation {
  put,
  delete,
}

/// Private class to store information about a [ContactsDataProvider] agent
class _DataProvider {
  final String sourceId;
  final String agentUrl;
  final ContactsDataProviderProxy dataProviderProxy;
  final AgentControllerProxy agentControllerProxy;

  _DataProvider({
    @required this.sourceId,
    @required this.agentUrl,
    @required this.dataProviderProxy,
    @required this.agentControllerProxy,
  })  : assert(sourceId != null && sourceId.isNotEmpty),
        assert(agentUrl != null && agentUrl.isNotEmpty),
        assert(dataProviderProxy != null),
        assert(agentControllerProxy != null);
}

// TODO: Handle cases where payloads exceeds fidl message size limit SO-1038
/// Initial stub implementation
class ContactsContentProviderImpl extends ContactsContentProvider
    implements EntityProvider {
  final entities.ContactEntityCodec _contactCodec =
      new entities.ContactEntityCodec();

  /// Map of [ContactsDataProvider] sourceIds to the [_DataProvider]
  /// information
  final Map<String, _DataProvider> _dataProviders = <String, _DataProvider>{};

  /// Store for the consolidated contacts information
  ContactsStore _contactsStore;

  /// [ComponentContext] used for interfacing with Ledger
  final ComponentContext _componentContext;

  /// [AgentContext] used for creating entity references
  final AgentContext _agentContext;

  /// [ledger.Ledger] instance
  ledger.LedgerProxy _ledger;

  /// Ledger [ledger.Page] instance containing contacts
  ledger.PageProxy _page;

  /// Watcher to keep track of updates to the Ledger [ledger.Page]
  ContactsWatcher _contactsWatcher;

  /// Keep track of subscribers via a map of message queue tokens to the
  /// message sender clients
  final Map<String, MessageSenderClient> _messageSenders =
      <String, MessageSenderClient>{};

  /// Constructor
  ContactsContentProviderImpl({
    @required ComponentContext componentContext,
    @required AgentContext agentContext,
  })  : assert(componentContext != null),
        assert(agentContext != null),
        _componentContext = componentContext,
        _agentContext = agentContext {
    _contactsStore = new ContactsStore();
  }

  /// Runs necessary methods to initialize the contacts content provider
  // TODO: remove async/error prone code SO-931
  Future<Null> initialize() async {
    // Connect to ledger
    try {
      await _initializeLedgerConnection();
    } on Exception catch (e, stackTrace) {
      log.severe('Failed to initialize ledger connection', e, stackTrace);
      return;
    }

    // Connect to data providers and ledger to grab contacts information
    _connectToDataProviders();
    bool errorReadingLedgerContacts = false;
    List<Contact> ledgerContacts;
    try {
      ledgerContacts = await _getLedgerContacts(_page);
    } on Exception catch (e, stackTrace) {
      errorReadingLedgerContacts = true;
      log.severe('Failed to read ledger contacts', e, stackTrace);
    }
    if (!errorReadingLedgerContacts && ledgerContacts.isNotEmpty) {
      _addContactsToStore(ledgerContacts);
      log.fine('Initialized contacts store from ledger');
    } else {
      log.fine('Ledger empty');
    }
  }

  @override
  Future<Null> getContactList(
    String prefix,
    String messageQueueToken,
    void callback(Status status, List<Contact> contacts),
  ) async {
    log.fine('getContactList called with prefix = \"$prefix\", '
        'token = \"$messageQueueToken\"');
    if (messageQueueToken != null) {
      _subscribe(messageQueueToken);
    }

    List<Contact> contactsList;
    if (prefix == null || prefix == '') {
      contactsList = _contactsStore.getAllContacts();
    } else {
      Map<String, Set<Contact>> contacts = _contactsStore.search(prefix);

      // Merge into a set first to avoid duplicates
      contactsList =
          contacts.values.expand((Set<Contact> s) => s).toSet().toList();
    }
    callback(Status.ok, contactsList);
    return;
  }

  @override
  Future<Null> getContact(
    String id,
    void callback(Status status, Contact contact),
  ) async {
    callback(Status.ok, _contactsStore.getContact(id));
    return;
  }

  @override
  Future<Null> getEntityReference(
    String id,
    void callback(Status status, String entityReference),
  ) async {
    // Create a proxy to the EntityReferenceFactory that will create the
    // entity reference
    EntityReferenceFactoryProxy entityReferenceProxy =
        new EntityReferenceFactoryProxy();
    Completer<String> entityReferenceCompleter = new Completer<String>();
    _agentContext.getEntityReferenceFactory(
      entityReferenceProxy.ctrl.request(),
    );
    entityReferenceProxy.createReference(
      id,
      (String entityReference) {
        if (entityReference.isNotEmpty) {
          entityReferenceCompleter.complete(entityReference);
        } else {
          // TODO(meiyili): better error handling
          String errorMsg =
              'Entity reference factory returned empty entity reference';
          log.warning(errorMsg);
          entityReferenceCompleter.completeError(errorMsg);
        }
      },
    );

    // Await the result and check the status before passing back to the caller
    Status status = Status.ok;
    String entityReference = await entityReferenceCompleter.future.catchError(
      (Object error) {
        status = Status.error;
        log.warning('Entity factory completed with error: $error');
      },
    );
    entityReference ??= '';
    entityReferenceProxy.ctrl.close();
    callback(status, entityReference);
  }

  void _subscribe(String messageQueueToken) {
    log.fine('Subscribe called');
    if (!_messageSenders.containsKey(messageQueueToken)) {
      // TODO: handle getMessageSender failures and somehow propagate that back
      // to the callers SO-1040
      var sender = new MessageSenderClient(
          onConnectionError: (MessageSenderError code, String msg) {
        log.severe('Message sender down for $messageQueueToken: $msg');
      });
      _componentContext.getMessageSender(
        messageQueueToken,
        sender.newRequest(),
      );
      _messageSenders[messageQueueToken] = sender;
      log.fine('Added subscription for token $messageQueueToken');
    }
  }

  @override
  void unsubscribe(String messageQueueToken) {
    log.fine('Unsubscribe called');
    MessageSenderClient messageSender = _messageSenders[messageQueueToken];
    if (messageSender != null) {
      messageSender.close();
      _messageSenders.remove(messageSender);
    }
  }

  @override
  Future<Null> refreshContacts(
    void callback(Status status, List<Contact> contacts),
  ) async {
    List<Contact> contacts = await _getContactsFromDataProviders();
    _addContactsToStore(contacts);
    callback(Status.ok, _contactsStore.getAllContacts());
  }

  @override
  void add(
    List<Contact> contacts,
    void callback(Status status),
  ) {
    log.fine('add called');
    _saveContactsToLedger(contacts).then((bool saved) {
      log.fine('add completed');
      callback(saved ? Status.ok : Status.error);
    });
  }

  @override
  void delete(
    List<Contact> contacts,
    void callback(Status status),
  ) {
    log.fine('delete called');
    _deleteContactsFromLedger(contacts).then((bool deleted) {
      log.fine('delete completed');
      callback(deleted ? Status.ok : Status.error);
    });
  }

  @override
  void getContactsFromSource(
    String sourceId,
    void callback(Status status, List<Contact> contacts),
  ) {
    log.fine('getContactsFromSource called');
    callback(Status.ok, _contactsStore.getContactsFromSource(sourceId));
  }

  // Entity Provider methods
  /// Get the types that the contacts content provider supports.
  /// For contacts, [cookie] maps to a contact's contactId
  @override
  void getTypes(String cookie, void callback(List<String> types)) {
    log.fine('getTypes called with cookie = $cookie');

    List<String> types = <String>[];
    if (_contactsStore.containsContact(cookie)) {
      log.fine('contacts store has the contact');
      types.add(_contactCodec.type);
    }
    callback(types);
  }

  /// Get the data for the entity specified by [type].
  /// For contacts, [cookie] maps to a contact's contactId
  @override
  void getData(
      String cookie, String type, void callback(fuchsia_mem.Buffer data)) {
    log.fine('getData called with cookie = $cookie and type = $type');

    String data;
    Contact contact = _contactsStore.getContact(cookie);
    if (contact != null && type == _contactCodec.type) {
      data = _contactCodec.encode(getEntityFromContact(contact));
    }

    log.fine('Retrieved contact = $contact');
    var serializedData = Uint8List.fromList(utf8.encode(data));
    callback(fuchsia_mem.Buffer(
      vmo: SizedVmo.fromUint8List(serializedData),
      size: data.length,
    ));
  }

  @override
  void writeData(String cookie, String type, fuchsia_mem.Buffer data,
      void callback(EntityWriteStatus status)) {
    callback(EntityWriteStatus.readOnly);
  }

  @override
  void watch(
      String cookie, String type, fidl.InterfaceHandle<EntityWatcher> watcher) {
    log.severe('EntityProvider.watch is unsupported.');
  }

  /// Close all connections
  void close() {
    // Close all data provider agent connections
    for (_DataProvider dataProvider in _dataProviders.values) {
      dataProvider.dataProviderProxy.ctrl.close();
      dataProvider.agentControllerProxy.ctrl.close();
    }
    _dataProviders.clear();

    // Close Ledger bindings
    _contactsWatcher?.close();
    _page?.ctrl?.close();
    _ledger?.ctrl?.close();
  }

  void _addContactsToStore(List<Contact> contacts) {
    for (Contact contact in contacts) {
      // Will only add the contact if it has a displayName that can be shown
      // to the user
      if (contact.displayName.trim().isNotEmpty) {
        _contactsStore.addContact(contact, updateIfExists: true);
      }
    }
  }

  /// Initialize connection to ledger and get the page of contacts data
  Future<Null> _initializeLedgerConnection() async {
    // Connect to ledger
    _ledger?.ctrl?.close();
    _ledger = new ledger.LedgerProxy();
    _ledger.ctrl.onConnectionError = () {
      log.severe('Ledger disconnected.');
      throw new Exception('Contacts Content Provider Ledger disconnected.');
    };
    _componentContext.getLedgerNew(_ledger.ctrl.request());

    // Grab the page of contacts
    _page?.ctrl?.close();
    _page = new ledger.PageProxy();
    Completer<ledger.Status> statusCompleter = new Completer<ledger.Status>();
    _ledger.getRootPage(
      _page.ctrl.request(),
      statusCompleter.complete,
    );
    ledger.Status pageStatus = await statusCompleter.future;
    _handleLedgerResponseStatus(
      status: pageStatus,
      ledgerCall: 'ledger.getRootPage()',
    );
  }

  Future<List<Contact>> _getLedgerContacts(ledger.PageProxy page) async {
    if (page == null) {
      // TODO(meiyili): handle ledger errors gracefully SO-810
      log.warning('getLedgerContacts was called on a null page');
      return <Contact>[];
    }
    ledger.PageSnapshotProxy snapshot = new ledger.PageSnapshotProxy();

    // Create the watcher that will listen to changes on the page
    _contactsWatcher = new ContactsWatcher(
      initialSnapshot: snapshot,
      processEntriesCallback: (List<ledger.Entry> entries) {
        _addContactsToStore(_getContactsFromEntries(entries));

        // Notify all subscribers that the list of contacts has changed
        Map<String, dynamic> message = <String, dynamic>{
          'contact_list': _contactsStore
              .getAllContacts()
              .map(_convertContactToJsonEncodable)
              .toList()
        };

        var encoded = Uint8List.fromList(utf8.encode(json.encode(message)));
        log.fine('Sending update to ${_messageSenders.length} subscribers');
        for (MessageSenderClient ms in _messageSenders.values) {
          ms.sendUint8List(encoded);
        }
      },
    );

    Completer<ledger.Status> statusCompleter = new Completer<ledger.Status>();
    page.getSnapshot(
      snapshot.ctrl.request(),
      new Uint8List(0),
      _contactsWatcher.pageWatcherHandle,
      statusCompleter.complete,
    );
    ledger.Status status = await statusCompleter.future;
    _handleLedgerResponseStatus(
      status: status,
      ledgerCall: 'page.getSnapshot()',
    );

    return _getContactsFromEntries(await getFullEntries(snapshot));
  }

  List<Contact> _getContactsFromEntries(List<ledger.Entry> entries) {
    List<Contact> contacts = <Contact>[];
    if (entries.isNotEmpty) {
      contacts = entries.map(_getContactFromEntry);
    }
    return contacts;
  }

  Contact _getContactFromEntry(ledger.Entry entry) {
    String contactId = utf8.decode(entry.key);
    Map<String, dynamic> decodedValue = decodeLedgerValue(entry.value);

    List<EmailAddress> emails = <EmailAddress>[];
    for (Map<String, String> email in decodedValue['emails']) {
      emails.add(
        new EmailAddress(label: email['label'], value: email['value']),
      );
    }

    List<PhoneNumber> phoneNumbers = <PhoneNumber>[];
    for (Map<String, String> number in decodedValue['phoneNumbers']) {
      phoneNumbers.add(
        new PhoneNumber(label: number['label'], value: number['value']),
      );
    }
    return new Contact(
        contactId: contactId,
        sourceContactId: decodedValue['sourceContactId'],
        sourceId: decodedValue['sourceId'],
        displayName: decodedValue['displayName'],
        givenName: decodedValue['givenName'],
        middleName: decodedValue['middleName'],
        familyName: decodedValue['familyName'],
        photoUrl: decodedValue['photoUrl'],
        emails: emails,
        phoneNumbers: phoneNumbers);
  }

  /// Saves the list of contacts to ledger and returns true if it was successful
  Future<bool> _saveContactsToLedger(List<Contact> contacts) async {
    // TODO(meiyili): add retrieval timestamp to contacts to better resolve
    // ledger conflicts SO-1117
    return await _updateLedgerContacts(contacts, _LedgerOperation.put);
  }

  /// Deletes the list of contacts from ledger and returns true if it was
  /// successful
  Future<bool> _deleteContactsFromLedger(List<Contact> contacts) async {
    return await _updateLedgerContacts(contacts, _LedgerOperation.delete);
  }

  Future<bool> _updateLedgerContacts(
    List<Contact> contacts,
    _LedgerOperation operation,
  ) async {
    bool updated = false;
    if (_page == null) {
      // TODO(meiyili): handle ledger errors gracefully SO-810
      log.warning('saveContactsToLedger was called on a null page');
      return updated;
    }

    // TODO(meiyili): retry transactions that returned with an error SO-810
    Completer<ledger.Status> completer = new Completer<ledger.Status>();

    // Start transaction will error if called again before the previous
    // transation completed
    // TODO: queue up save contacts requests SO-1051
    _page.startTransaction(completer.complete);
    bool startTransactionOk = (await completer.future) == ledger.Status.ok;
    if (startTransactionOk) {
      log.fine('Started ledger transaction');
      List<Future<ledger.Status>> opStatuses = <Future<ledger.Status>>[];
      for (Contact contact in (contacts ?? <Contact>[])) {
        Completer<ledger.Status> statusCompleter =
            new Completer<ledger.Status>();
        opStatuses.add(statusCompleter.future);
        List<int> contactId = utf8.encode(contact.contactId);
        List<int> ledgerValue = encodeLedgerValue(
          _convertContactToJsonEncodable(contact),
        );
        if (operation == _LedgerOperation.put) {
          _page.put(
            contactId,
            ledgerValue,
            (ledger.Status status) => statusCompleter.complete(status),
          );
        } else if (operation == _LedgerOperation.delete) {
          _page.delete(
            contactId,
            (ledger.Status status) => statusCompleter.complete(status),
          );
        }
      }

      List<ledger.Status> statuses = await Future.wait(opStatuses);
      bool allSucceeded = statuses.every(
        (ledger.Status s) => s == ledger.Status.ok,
      );

      // TODO: determine what to do if the commit or rollback fails SO-1041
      if (allSucceeded) {
        log.fine('Ledger operations succeeded');
        completer = new Completer<ledger.Status>();
        _page.commit(completer.complete);
        if ((await completer.future) == ledger.Status.ok) {
          updated = true;
        }
      } else {
        completer = new Completer<ledger.Status>();
        _page.rollback(completer.complete);
        await completer.future;
        updated = false;
        log.fine('Ledger operations failed, rolled back');
      }
    }
    return updated;
  }

  Map<String, dynamic> _convertContactToJsonEncodable(Contact c) {
    List<Map<String, String>> emails = <Map<String, String>>[];
    for (EmailAddress e in c.emails) {
      emails.add(<String, String>{
        'label': e.label,
        'value': e.value,
      });
    }

    List<Map<String, String>> phoneNumbers = <Map<String, String>>[];
    for (PhoneNumber p in c.phoneNumbers) {
      phoneNumbers.add(<String, String>{
        'label': p.label,
        'value': p.value,
      });
    }
    Map<String, dynamic> jsonEncodable = <String, dynamic>{
      'contactId': c.contactId,
      'sourceContactId': c.sourceContactId,
      'sourceId': c.sourceId,
      'displayName': c.displayName,
      'givenName': c.givenName,
      'middleName': c.middleName,
      'familyName': c.familyName,
      'photoUrl': c.photoUrl,
      'emails': emails,
      'phoneNumbers': phoneNumbers,
    };

    return jsonEncodable;
  }

  /// Handles response status, throws an exception if the status is not ok
  void _handleLedgerResponseStatus({ledger.Status status, String ledgerCall}) {
    // TODO(meiyili): handle ledger errors and try to reconnect if there were
    // status errors SO-810
    if (status != ledger.Status.ok) {
      log.severe('Ledger error: $ledgerCall');
      throw new Exception(
        'Contacts Content Provider Ledger call error: '
            'status = $status, message = "$ledgerCall returned an error"',
      );
    } else {
      log.fine('$ledgerCall succeeded');
    }
  }

  /// Looks for the contacts data providers json file that contains the list
  /// of data providers.
  ///
  /// The content of the config file has the format:
  /// {
  ///   "data_providers": [
  ///     {
  ///       "source_id": "provider_source_id",
  ///       "agent_url": "some_provider"
  ///     }
  ///   ]
  /// }
  ///
  /// If it exists, it will parse out the providers' information and attempt
  /// to connect to the agent. If it is successful, it will save the data
  /// provider's information and connection.
  void _connectToDataProviders() {
    log.fine('Looking for config file at $_kDataProvidersConfig');
    File configFile = new File(_kDataProvidersConfig);
    if (!configFile.existsSync()) {
      log.fine('Config file does not exist');
      return;
    }

    try {
      Map<String, dynamic> config = json.decode(configFile.readAsStringSync());
      dynamic dataProviders = config['data_providers'];
      if (dataProviders is List) {
        for (Map<String, dynamic> info
            in dataProviders.cast<Map<String, dynamic>>()) {
          String sourceId = info['source_id'] ?? '';
          String agentUrl = info['agent_url'] ?? '';
          _DataProvider provider = _connectToDataProvider(sourceId, agentUrl);
          if (provider != null) {
            _dataProviders[provider.sourceId] = provider;
          }
        }
      }
    } on Exception catch (e) {
      log.warning('Error reading contacts data provider config file: $e');
    }
  }

  /// Connects to the data provider specified by the url and returns the
  /// [_DataProvider] information. If the sourceId or url are empty it will
  /// return null.
  _DataProvider _connectToDataProvider(String sourceId, String agentUrl) {
    if (sourceId.isEmpty || agentUrl.isEmpty) {
      return null;
    }

    // Connect to the agent
    ContactsDataProviderProxy contactsDataProviderProxy =
        new ContactsDataProviderProxy();
    AgentControllerProxy contactsDataProviderController =
        new AgentControllerProxy();
    ServiceProviderProxy dataProviderService = new ServiceProviderProxy();
    _componentContext.connectToAgent(
      agentUrl,
      dataProviderService.ctrl.request(),
      contactsDataProviderController.ctrl.request(),
    );
    connectToService(dataProviderService, contactsDataProviderProxy.ctrl);

    // Close all unnecessary bindings
    dataProviderService.ctrl.close();

    // Save the proxies and data provider info
    return new _DataProvider(
      sourceId: sourceId,
      agentUrl: agentUrl,
      dataProviderProxy: contactsDataProviderProxy,
      agentControllerProxy: contactsDataProviderController,
    );
  }

  /// Grab contacts from the contacts providers and save to ledger, rather
  /// than adding them to the store immediately we will wait until the
  /// changes propagate back from Ledger via the page watcher to add them
  /// the store.
  Future<List<Contact>> _getContactsFromDataProviders() async {
    // TODO(meiyili) grab last sync tokens and save those as well so the shape
    // of the content in the future will change and be less ugly
    List<Future<List<Contact>>> completers = <Future<List<Contact>>>[];
    for (_DataProvider provider in _dataProviders.values) {
      log.fine('Connecting to data provider = $provider');
      Completer<List<Contact>> completer = new Completer<List<Contact>>();
      provider.dataProviderProxy.getContactList(
        (Status status, List<Contact> contacts) {
          if (status == Status.ok) {
            completer.complete(contacts);
          } else {
            completer.complete(<Contact>[]);
          }
        },
      );
      completers.add(completer.future);
    }
    List<Contact> contacts =
        (await Future.wait(completers)).expand((List<Contact> c) => c).toList();
    await _saveContactsToLedger(contacts);

    // TODO (meiyili): this is temporary until I finish SO-891
    return contacts;
  }
}
