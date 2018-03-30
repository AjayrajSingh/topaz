// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:fuchsia.fidl.component/component.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.agent.dart/agent.dart';
import 'package:lib.app.dart/app.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;

import 'src/documents_content_provider_impl.dart';

/// Documents Agent instance
// ignore: unused_element
DocumentsAgent _agent;

/// Implementation of the [Agent] interface for the Documents Agent
class DocumentsAgent extends AgentImpl {
  DocumentsContentProviderImpl _documentsContentProviderImpl;
  final List<Binding<Object>> _bindings = <doc_fidl.DocumentInterfaceBinding>[];

  /// Creates a new instance of [DocumentsAgent].
  DocumentsAgent({
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
    log.fine('onReady fired');

    _documentsContentProviderImpl = new DocumentsContentProviderImpl(
      componentContext: componentContext,
      agentContext: agentContext,
    )..init();

    // This adds this agent's service to the outgoingServices so that the
    // ModuleModel can use it. Inside the ModuleModel, you would first connect
    // to an Agent, and then connect to one of its Services.
    outgoingServices.addServiceForName(
      _addBinding,
      doc_fidl.DocumentInterface.serviceName,
    );
  }

  /// Binds this implementation to the incoming [InterfaceRequest].
  /// This should only be called once. In other words, a new
  /// [DocumentsContentProviderImpl] object needs to be created per interface
  /// request.
  void _addBinding(InterfaceRequest<doc_fidl.DocumentInterface> request) {
    _bindings.add(new doc_fidl.DocumentInterfaceBinding()
      ..bind(_documentsContentProviderImpl, request));
  }

  @override
  Future<Null> onStop() async {
    log.fine('onStop fired');
    _documentsContentProviderImpl.close();
    for (doc_fidl.DocumentInterfaceBinding binding in _bindings) {
      binding.close();
    }
  }

  @override
  void advertise() {
    super.advertise();
    applicationContext.outgoingServices.addServiceForName(
      (InterfaceRequest<EntityProvider> request) {
        _bindings.add(
          new EntityProviderBinding()
            ..bind(_documentsContentProviderImpl, request),
        );
      },
      EntityProvider.serviceName,
    );
  }
}

/// Main entry point.
Future<Null> main(List<String> args) async {
  setupLogger(name: 'documents_content_provider');

  _agent = new DocumentsAgent(
    applicationContext: new ApplicationContext.fromStartupInfo(),
  )..advertise();
}
