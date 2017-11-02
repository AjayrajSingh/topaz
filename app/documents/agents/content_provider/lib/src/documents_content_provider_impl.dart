// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:lib.agent.fidl.agent_controller/agent_controller.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;

/// This is a concrete implementation of the generic Document FIDL interface
/// Currently, it can only take in one hardcoded Document Provider.
/// In the future, it would return back a list of Document Providers and their
/// documents
// TODO SO-880(maryxia) retrieve document providers from a list
class DocumentsContentProviderImpl extends doc_fidl.DocumentInterface {
  final List<doc_fidl.DocumentInterfaceBinding> _bindings =
      <doc_fidl.DocumentInterfaceBinding>[];
  final AgentControllerProxy _documentsAgentController =
      new AgentControllerProxy();
  // We use this interface proxy to talk to the doc_fidl
  final doc_fidl.DocumentInterfaceProxy _docInterfaceProxy =
      new doc_fidl.DocumentInterfaceProxy();

  /// componentContext passed in so that we can connect to an agent
  final ComponentContext componentContext;

  /// Constructor
  DocumentsContentProviderImpl({
    @required this.componentContext,
  })
      : assert(componentContext != null);

  /// Implements the Document interface to get a document based on id
  // TODO(maryxia) SO-820 search by name as well as id
  @override
  void get(
    String documentId,
    void callback(doc_fidl.Document doc),
  ) {
    log.fine('Retrieving a document in DocumentsContentProviderImpl');
    _docInterfaceProxy.get(documentId, (doc_fidl.Document doc) {
      log.fine('Retrieved a document');
      callback(doc);
    });
  }

  /// Implements the [Document] interface to List files
  @override
  void list(
    void callback(List<doc_fidl.Document> docs),
  ) {
    log.fine('Retrieving a list of documents in DocumentsContentProviderImpl');
    _docInterfaceProxy.list((List<doc_fidl.Document> docs) {
      log.fine('Retrieved a list of documents');
      callback(docs);
    });
  }

  // TODO(maryxia) SO-796 preload the results for documents
  /// Initializes DocumentsContentProviderImpl, sets up connections
  void init() {
    // The below is used to connect to the Document service
    ServiceProviderProxy serviceProviderProxy = new ServiceProviderProxy();
    // The incomingServices retrieved here are the ones sent from outgoingServices
    // in the DocumentsAgent
    componentContext.connectToAgent(
      // TODO(maryxia) SO-880 this should be read in from a file
      // launches the application at this location, as if it were an agent
      // Also, we need to check that the file location exists before calling this
      'file:///system/apps/reconciler/documents',
      serviceProviderProxy.ctrl.request(),
      _documentsAgentController.ctrl.request(),
    );
    // Connect the DocumentInterfaceProxy to a service that the agent manages.
    // Otherwise, you've only connected to the Agent, and can't do anything.
    // This is just a global function located in app.dart
    connectToService(serviceProviderProxy, _docInterfaceProxy.ctrl);
    serviceProviderProxy.ctrl.close();
    log.fine('Initialized DocumentsContentProviderImpl');
  }

  /// Binds this implementation to the incoming [InterfaceRequest].
  /// This should only be called once. In other words, a new
  /// [DocumentsContentProviderImpl] object needs to be created per interface
  /// request.
  void addBinding(InterfaceRequest<doc_fidl.DocumentInterface> request) {
    _bindings.add(new doc_fidl.DocumentInterfaceBinding()..bind(this, request));
  }

  /// Close all our bindings; called by our owner during termination.
  void close() {
    for (doc_fidl.DocumentInterfaceBinding binding in _bindings) {
      binding.close();
    }
    _docInterfaceProxy.ctrl.close();
    _documentsAgentController.ctrl.close();
  }
}
