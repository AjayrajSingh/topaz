// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.agent.fidl.agent_controller/agent_controller.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.widgets/modular.dart';
import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;

/// The Model for the info view
class InfoModuleModel extends ModuleModel {
  // Interface Proxy. This is how we talk to the Doc FIDL
  final doc_fidl.DocumentInterfaceProxy _docsInterfaceProxy =
      new doc_fidl.DocumentInterfaceProxy();

  /// Used to talk to agents
  final AgentControllerProxy _agentControllerProxy = new AgentControllerProxy();

  /// Current Doc
  doc_fidl.Document _doc;

  /// Gets the currently-selected document
  doc_fidl.Document get doc => _doc;

  @override
  Future<Null> onReady(
    ModuleContext moduleContext,
    Link link,
  ) async {
    super.onReady(moduleContext, link);

    // The below is used to connect to the DocumentProvider service
    ComponentContextProxy componentContext = new ComponentContextProxy();
    moduleContext.getComponentContext(componentContext.ctrl.request());
    ServiceProviderProxy serviceProviderProxy = new ServiceProviderProxy();

    // The incomingServices here are the ones sent from outgoingServices in the
    // DocumentsAgent
    componentContext.connectToAgent(
      // TODO(maryxia) SO-880 get this from file manifest and add a check for
      // whether it can be found in the system
      // launches the application at this location, as if it were an agent
      'documents_content_provider',
      serviceProviderProxy.ctrl.request(),
      _agentControllerProxy.ctrl.request(),
    );
    // Connect the DocumentsInterfaceProxy to a service that the agent manages.
    // Otherwise, you've only connected to the Agent, and can't perform actions.
    connectToService(serviceProviderProxy, _docsInterfaceProxy.ctrl);
    serviceProviderProxy.ctrl.close();
    componentContext.ctrl.close();
    notifyListeners();
    log.fine('BrowserModuleModel onReady complete');
  }

  /// Receive currently-selected Document from the [Link],
  /// turn it back into a doc_fidl.Document, and show it
  @override
  Future<Null> onNotify(String linkJson) async {
    log.fine('Received updated Link Data in Info Module');
    Map<String, dynamic> linkData = JSON.decode(linkJson);
    if (linkData['currentDocId'] == null) {
      log.severe('Link does not contain a currently-selected Document');
      return;
    }
    _docsInterfaceProxy.getMetadata(linkData['currentDocId'],
        (doc_fidl.Document doc) {
      _doc = doc;
      log.fine('Updating currently-selected Document in Info Module');
      notifyListeners();
    });
  }

  @override
  void onStop() {
    _docsInterfaceProxy.ctrl.close();
    _agentControllerProxy.ctrl.close();
  }
}
