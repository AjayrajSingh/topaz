// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lib.agent.fidl.agent_controller/agent_controller.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.ledger.fidl/ledger.fidl.dart' as ledger;
import 'package:lib.logging/logging.dart';
import 'package:lib.modular/ledger.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.contacts.services/contacts_content_provider.fidl.dart'
    as fidl;

import '../store/contacts_store.dart';
import 'contacts_watcher.dart';

const String _kDataProvidersConfig =
    '/system/data/contacts/data_providers.json';

/// Private class to store information about a [fidl.ContactsDataProvider] agent
class _DataProvider {
  final String sourceId;
  final String agentUrl;
  final fidl.ContactsDataProviderProxy dataProviderProxy;
  final AgentControllerProxy agentControllerProxy;

  _DataProvider({
    @required this.sourceId,
    @required this.agentUrl,
    @required this.dataProviderProxy,
    @required this.agentControllerProxy,
  })
      : assert(sourceId != null && sourceId.isNotEmpty),
        assert(agentUrl != null && agentUrl.isNotEmpty),
        assert(dataProviderProxy != null),
        assert(agentControllerProxy != null);
}

/// Initial stub implementation
class ContactsContentProviderImpl extends fidl.ContactsContentProvider {
  /// Map of [fidl.ContactsDataProvider] sourceIds to the [_DataProvider]
  /// information
  final Map<String, _DataProvider> _dataProviders = <String, _DataProvider>{};

  /// Store for the consolidated contacts information
  final ContactsStore<fidl.Contact> _contactsStore =
      new ContactsStore<fidl.Contact>();

  /// Store of the request bindings to this impl
  final List<fidl.ContactsContentProviderBinding> _bindings =
      <fidl.ContactsContentProviderBinding>[];

  /// [ComponentContext] used for interfacing with Ledger
  final ComponentContext _componentContext;

  /// [Ledger] instance
  ledger.LedgerProxy _ledger;

  /// Ledger [Page] instance containing contacts
  ledger.PageProxy _page;

  /// Watcher to keep track of updates to the Ledger [Page]
  ContactsWatcher _contactsWatcher;

  /// Constructor
  ContactsContentProviderImpl({@required ComponentContext componentContext})
      : assert(componentContext != null),
        _componentContext = componentContext;

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
    List<fidl.Contact> ledgerContacts;
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
      await _getContactsFromDataProviders();
      log.fine('Ledger empty, initialized contacts store from service');
    }
  }

  @override
  Future<Null> getContactList(String prefix,
      void callback(fidl.Status status, List<fidl.Contact> contacts)) async {
    List<fidl.Contact> contactsList;
    if (prefix == null || prefix == '') {
      contactsList = _contactsStore.getAllContacts();
    } else {
      Map<String, Set<fidl.Contact>> contacts = _contactsStore.search(prefix);

      // Merge into a set first to avoid duplicates
      contactsList =
          contacts.values.expand((Set<fidl.Contact> s) => s).toSet().toList();
    }
    callback(fidl.Status.ok, contactsList);
    return;
  }

  @override
  Future<Null> getContact(String id,
      void callback(fidl.Status status, fidl.Contact contact)) async {
    callback(fidl.Status.ok, _contactsStore.getContact(id));
    return;
  }

  /// Add request to the list of binding objects.
  void addBinding(InterfaceRequest<fidl.ContactsContentProvider> request) {
    _bindings
        .add(new fidl.ContactsContentProviderBinding()..bind(this, request));
  }

  /// Close all the bindings and connections
  void close() {
    // Close bindings
    for (fidl.ContactsContentProviderBinding binding in _bindings) {
      binding.close();
    }
    _bindings.clear();

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

  void _addContactsToStore(List<fidl.Contact> contacts) {
    for (fidl.Contact contact in contacts) {
      if (contact.displayName.trim().isNotEmpty) {
        // Will only add the contact if it has a displayName that can be shown
        // to the user
        List<String> searchableValues = <String>[
          contact.displayName.trim().toLowerCase()
        ];

        if (contact.familyName != null &&
            contact.familyName.trim().isNotEmpty) {
          searchableValues.add(contact.familyName.trim());
        }

        // Allow contact to be searchable on all of their email addresses
        for (fidl.EmailAddress e in contact.emails) {
          if (e != null && e.value.trim().isNotEmpty) {
            searchableValues.add(e.value.trim());
          }
        }

        _contactsStore.addContact(
          contact.contactId,
          contact.displayName,
          searchableValues,
          contact,
          updateIfExists: true,
        );
      }
    }
  }

  /// Initialize connection to ledger and get the page of contacts data
  Future<Null> _initializeLedgerConnection() async {
    // Connect to ledger
    _ledger?.ctrl?.close();
    _ledger = new ledger.LedgerProxy();
    Completer<ledger.Status> statusCompleter = new Completer<ledger.Status>();
    _componentContext.getLedger(
      _ledger.ctrl.request(),
      statusCompleter.complete,
    );
    ledger.Status status = await statusCompleter.future;
    _handleLedgerResponseStatus(
      status: status,
      ledgerCall: '_componentContext.getLedger()',
    );

    // Grab the page of contacts
    _page?.ctrl?.close();
    _page = new ledger.PageProxy();
    statusCompleter = new Completer<ledger.Status>();
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

  Future<List<fidl.Contact>> _getLedgerContacts(ledger.PageProxy page) async {
    if (page == null) {
      // TODO(meiyili): handle ledger errors gracefully SO-810
      log.warning('getLedgerContacts was called on a null page');
      return <fidl.Contact>[];
    }
    ledger.PageSnapshotProxy snapshot = new ledger.PageSnapshotProxy();

    // Create the watcher that will listen to changes on the page
    _contactsWatcher = new ContactsWatcher(
      initialSnapshot: snapshot,
      processEntriesCallback: (List<ledger.Entry> entries) {
        _addContactsToStore(_getContactsFromEntries(entries));
      },
    );

    Completer<ledger.Status> statusCompleter = new Completer<ledger.Status>();
    page.getSnapshot(
      snapshot.ctrl.request(),
      null,
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

  List<fidl.Contact> _getContactsFromEntries(List<ledger.Entry> entries) {
    List<fidl.Contact> contacts = <fidl.Contact>[];
    if (entries.isNotEmpty) {
      contacts = entries.map(_getContactFromEntry);
    }
    return contacts;
  }

  fidl.Contact _getContactFromEntry(ledger.Entry entry) {
    String contactId = UTF8.decode(entry.key);
    Map<String, dynamic> decodedValue = decodeLedgerValue(entry.value);

    List<fidl.EmailAddress> emails = <fidl.EmailAddress>[];
    for (Map<String, String> email in decodedValue['emails']) {
      emails.add(new fidl.EmailAddress()
        ..label = email['label']
        ..value = email['value']);
    }

    List<fidl.PhoneNumber> phoneNumbers = <fidl.PhoneNumber>[];
    for (Map<String, String> number in decodedValue['phoneNumbers']) {
      phoneNumbers.add(new fidl.PhoneNumber()
        ..label = number['label']
        ..value = number['value']);
    }
    return new fidl.Contact()
      ..contactId = contactId
      ..sourceContactId = decodedValue['sourceContactId']
      ..sourceId = decodedValue['sourceId']
      ..displayName = decodedValue['displayName']
      ..givenName = decodedValue['givenName']
      ..middleName = decodedValue['middleName']
      ..familyName = decodedValue['familyName']
      ..photoUrl = decodedValue['photoUrl']
      ..emails = emails
      ..phoneNumbers = phoneNumbers;
  }

  Future<Null> _saveContactsToLedger(List<fidl.Contact> contacts) async {
    if (_page == null) {
      // TODO(meiyili): handle ledger errors gracefully SO-810
      log.warning('saveContactsToLedger was called on a null page');
      return;
    }

    for (fidl.Contact contact in contacts) {
      List<int> contactId = UTF8.encode(contact.contactId);
      List<int> ledgerValue = encodeLedgerValue(contact);
      _page.put(
        contactId,
        ledgerValue,
        (ledger.Status status) {
          // TODO(meiyili): retry put calls that returned with an error SO-810
          if (status != ledger.Status.ok) {
            log.severe('page.put returned an error');
          } else {
            log.fine('page.put succeeded');
          }
        },
      );
    }
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
  ///       "agent_url": "file:///system/apps/path_to_some_provider"
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
      Map<String, Object> config = JSON.decode(configFile.readAsStringSync());
      Object dataProviders = config['data_providers'];
      if (dataProviders is List) {
        for (Map<String, String> info in dataProviders) {
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
    fidl.ContactsDataProviderProxy contactsDataProviderProxy =
        new fidl.ContactsDataProviderProxy();
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
  Future<Null> _getContactsFromDataProviders() async {
    // TODO(meiyili) grab last sync tokens and save those as well
    Completer<List<fidl.Contact>> completer;
    for (_DataProvider provider in _dataProviders.values) {
      log.fine('Connecting to data provider = $provider');
      completer = new Completer<List<fidl.Contact>>();
      provider.dataProviderProxy.getContactList(
        (fidl.Status status, List<fidl.Contact> contacts) {
          if (status == fidl.Status.ok) {
            completer.complete(contacts);
          } else {
            completer.complete(<fidl.Contact>[]);
          }
        },
      );
      List<fidl.Contact> contacts = await completer.future;
      await _saveContactsToLedger(contacts);
    }
  }
}
