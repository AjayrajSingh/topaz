// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.modular/modular.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.contacts.services/contacts_content_provider.fidl.dart';

import 'src/modular/contacts_content_provider_impl.dart';

ContactsContentProviderAgent _agent;

/// Contacts content provider implementation of the [Agent] interface.
class ContactsContentProviderAgent extends AgentImpl {
  ContactsContentProviderImpl _contentProviderImpl;

  /// Create a new instance of [ContactsContentProviderAgent].
  ContactsContentProviderAgent({
    @required ApplicationContext applicationContext,
  })
      : super(applicationContext: applicationContext);

  @override
  Future<Null> onReady(
    ApplicationContext applicationContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenProvider tokenProvider,
    ServiceProviderImpl outgoingServices,
  ) async {
    log.fine('onReady start');

    _contentProviderImpl = new ContactsContentProviderImpl();

    // Register the content provider to the outgoing services provider
    outgoingServices.addServiceForName(
      (InterfaceRequest<ContactsContentProvider> request) {
        log.fine('Received a ContactsContentProvider request');
        _contentProviderImpl.addBinding(request);
      },
      ContactsContentProvider.serviceName,
    );
    log.fine('onReady end');
  }

  @override
  Future<Null> onStop() async {
    _contentProviderImpl?.close();
  }
}

Future<Null> main(List<String> args) async {
  setupLogger(name: 'contacts/agent');

  _agent = new ContactsContentProviderAgent(
    applicationContext: new ApplicationContext.fromStartupInfo(),
  )..advertise();
}
