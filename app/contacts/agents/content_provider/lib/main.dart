// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.agent.dart/agent.dart';
import 'package:lib.app.dart/app.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:fuchsia.fidl.contacts_content_provider/contacts_content_provider.dart';

import 'src/modular/contacts_content_provider_impl.dart';

// ignore: unused_element
ContactsContentProviderAgent _agent;

/// Contacts content provider implementation of the [Agent] interface.
class ContactsContentProviderAgent extends AgentImpl {
  /// Implementation of the contacts content provider and entity provider
  /// interfaces
  ContactsContentProviderImpl _contentProviderImpl;

  /// Store of the request bindings to the impl
  final List<Binding<Object>> _bindings = <Binding<Object>>[];

  /// Create a new instance of [ContactsContentProviderAgent].
  ContactsContentProviderAgent({
    @required ApplicationContext applicationContext,
  }) : super(applicationContext: applicationContext);

  @override
  void advertise() {
    super.advertise();

    // Add impl for processing Entity Provider service requests to the
    // application context outgoing services which differs from the
    // ServiceProviderImpl's outgoing services
    applicationContext.outgoingServices.addServiceForName(
      (InterfaceRequest<EntityProvider> request) {
        log.fine('Received an EntityProvider request');
        _bindings.add(
          new EntityProviderBinding()..bind(_contentProviderImpl, request),
        );
      },
      EntityProvider.$serviceName,
    );

    log.fine('Added entity provider implementation to outgoing services');
  }

  @override
  Future<Null> onReady(
    ApplicationContext applicationContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenProvider tokenProvider,
    ServiceProviderImpl outgoingServices,
  ) async {
    log.fine('onReady start');

    _contentProviderImpl = new ContactsContentProviderImpl(
      componentContext: componentContext,
      agentContext: agentContext,
    );
    await _contentProviderImpl.initialize();

    // Register the content provider to the outgoing services provider
    outgoingServices.addServiceForName(
      (InterfaceRequest<ContactsContentProvider> request) {
        log.fine('Received a ContactsContentProvider request');
        _bindings.add(
          new ContactsContentProviderBinding()
            ..bind(_contentProviderImpl, request),
        );
      },
      ContactsContentProvider.$serviceName,
    );
    log.fine('onReady end');
  }

  @override
  Future<Null> onStop() async {
    for (Binding<Object> binding in _bindings) {
      binding.close();
    }
    _bindings.clear();
    _contentProviderImpl?.close();
  }
}

Future<Null> main(List<String> args) async {
  setupLogger(name: 'contacts/agent');

  _agent = new ContactsContentProviderAgent(
    applicationContext: new ApplicationContext.fromStartupInfo(),
  )..advertise();
}
