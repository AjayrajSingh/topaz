// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.agent.fidl/agent_context.fidl.dart';
import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.modular/modular.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;

import 'src/documents_content_provider_impl.dart';

/// Documents Agent instance
DocumentsAgent agent;

/// Implementation of the [Agent] interface for the Documents Agent
class DocumentsAgent extends AgentImpl {
  DocumentsContentProviderImpl _documentsContentProviderImpl;

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

    _documentsContentProviderImpl =
        new DocumentsContentProviderImpl(componentContext: componentContext)
          ..init();

    // This adds this agent's service to the outgoingServices so that the ModuleModel
    // can use it. Inside the ModuleModel, you would first connect to an Agent,
    // and then connect to one of its Services.
    outgoingServices.addServiceForName(
      (InterfaceRequest<doc_fidl.DocumentInterface> request) {
        _documentsContentProviderImpl.addBinding(request);
      },
      doc_fidl.DocumentInterface.serviceName,
    );
  }

  @override
  Future<Null> onStop() async {
    log.fine('onStop fired');
    _documentsContentProviderImpl.close();
  }
}

/// Main entry point.
Future<Null> main(List<String> args) async {
  setupLogger(name: 'documents/content_provider');

  agent = new DocumentsAgent(
    applicationContext: new ApplicationContext.fromStartupInfo(),
  )..advertise();
}
