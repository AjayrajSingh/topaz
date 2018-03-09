// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:fuchsia/fuchsia.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl._service_provider/service_provider.fidl.dart';
import 'package:lib.context.fidl/context_writer.fidl.dart';
import 'package:lib.context.fidl/context_reader.fidl.dart';
import 'package:lib.context.fidl/metadata.fidl.dart';
import 'package:lib.context.fidl/value.fidl.dart';
import 'package:lib.context.fidl/value_type.fidl.dart';
import 'package:lib.user_intelligence.fidl/intelligence_services.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.lifecycle.fidl/lifecycle.fidl.dart';
import 'package:lib.module.fidl/module.fidl.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

// ignore_for_file: public_member_api_docs

/// The context topic for "focal entities".
const String _kFocalEntitiesTopic = 'inferred/focal_entities';

final ApplicationContext _appContext = new ApplicationContext.fromStartupInfo();
final TextEditingController _controller = new TextEditingController();

/// This is used for keeping the reference around.
ModuleImpl _module = new ModuleImpl();

void _log(String msg) {
  print('[Basic Text Reporter Module] $msg');
}

// A listener for finding updated focal entities and applying UI treatment to
// them.
class ContextListenerImpl extends ContextListener {
  final ContextListenerBinding _binding = new ContextListenerBinding();

  /// Constructor
  ContextListenerImpl();

  /// Gets the [InterfaceHandle]
  /// The returned handle should only be used once.
  InterfaceHandle<ContextListener> getHandle() => _binding.wrap(this);

  @override
  Future<Null> onContextUpdate(ContextUpdate result) async {
    String outputText = '';
    int lastEnd = 0;
    final String allControllerText = _controller.text;
    // Without this, selection might be overwritten.
    final TextSelection oldSelection = _controller.selection;
    bool found = false;
    for (final ContextUpdateEntry entry in result.values) {
      if (entry.key != _kFocalEntitiesTopic) {
        continue;
      }

      found = true;
      for (ContextValue value in entry.value) {
        final dynamic content = json.decode(value.content);
        // TODO(thatguy): Give the Entity a type instead of this ad-hoc schema
        // checking. Then use that type in the ContextQuery below.
        if (!(content is Map<String, dynamic>) &&
            content.containsKey('start') &&
            content.containsKey('end')) {
          final int start = content['start'];
          final int end = content['end'];
          outputText = '$outputText'
              '${allControllerText.substring(lastEnd, start).toLowerCase()}'
              '${allControllerText.substring(start, end).toUpperCase()}';
          lastEnd = end;
        }
      }
    }
    if (found == false) {
      return;
    }

    outputText = '$outputText'
        '${allControllerText.substring(lastEnd, allControllerText.length)}';
    if (outputText.length != allControllerText.length) {
      _log('LENGTH MISMATCH');
    } else {
      _controller.text = outputText;
      _controller.selection = oldSelection;
    }
  }
}

/// An implementation of the [Module] interface.
class ModuleImpl implements Module, Lifecycle {
  final ModuleBinding _moduleBinding = new ModuleBinding();
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();

  final ModuleContextProxy _moduleContext = new ModuleContextProxy();
  final LinkProxy _link = new LinkProxy();

  final ContextWriterProxy _writer = new ContextWriterProxy();
  final IntelligenceServicesProxy _intelligenceServices =
      new IntelligenceServicesProxy();

  final ContextReaderProxy _contextReader = new ContextReaderProxy();
  ContextListenerImpl _contextListenerImpl;

  /// Bind an [InterfaceRequest] for a [Module] interface to this object.
  void bindModule(InterfaceRequest<Module> request) {
    _moduleBinding.bind(this, request);
  }

  /// Bind an [InterfaceRequest] for a [Lifecycle] interface to this object.
  void bindLifecycle(InterfaceRequest<Lifecycle> request) {
    _lifecycleBinding.bind(this, request);
  }

  /// Implementation of the Initialize(ModuleContext story, Link link) method.
  @override
  void initialize(InterfaceHandle<ModuleContext> moduleContextHandle,
      InterfaceRequest<ServiceProvider> outgoingServices) {
    _log('ModuleImpl::initialize call');

    // NOTE: These story / link proxy variables must not be local variables.
    // When a handle is bound to a proxy and then the proxy variable is garbage
    // collected before the pipe is properly closed or unbound, the app will
    // crash due to the leaked handle.
    _moduleContext.ctrl.bind(moduleContextHandle);
    _moduleContext
      ..getLink(null, _link.ctrl.request())

      // Do something with the story and link services.
      ..getIntelligenceServices(_intelligenceServices.ctrl.request());
    _intelligenceServices
      ..getContextWriter(_writer.ctrl.request())

      // Listen to updates from the context service.
      ..getContextReader(_contextReader.ctrl.request());
    _contextListenerImpl = new ContextListenerImpl();

    ContextSelector selector = new ContextSelector(
        type: ContextValueType.entity,
        meta: new ContextMetadata(
            story: new StoryMetadata(
                focused: new FocusedState(state: FocusedStateState.focused)),
            entity: const EntityMetadata(topic: _kFocalEntitiesTopic)));
    ContextQuery query = new ContextQuery(
        selector: <ContextQueryEntry>[new ContextQueryEntry(
          key: _kFocalEntitiesTopic, value:  selector)]);

    _contextReader.subscribe(query, _contextListenerImpl.getHandle());

    // Indicate readiness
    _moduleContext.ready();
  }

  /// Implementation of the Lifecycle.Terminate method.
  @override
  void terminate() {
    _log('ModuleImpl::terminate call');

    // Do some clean up here.
    _moduleContext.ctrl.close();
    _link.ctrl.close();
    _moduleBinding.close();
    _lifecycleBinding.close();

    exit(0);
  }

  void publishText(String text) {
    _writer.writeEntityTopic(
      'raw/text',
      json.encode(
        <String, String>{
          'text': text,
        },
      ),
    );
  }

  void publishSelection(int start, int end) {
    _writer.writeEntityTopic(
      'raw/text_selection',
      json.encode(
        <String, int>{
          'start': start,
          'end': end,
        },
      ),
    );
  }
}

/// Entry point for this module.
void main() {
  _log('Module started with ApplicationContext: $_appContext');

  /// Add [ModuleImpl] to this application's outgoing ServiceProvider.
  _appContext.outgoingServices
    ..addServiceForName(
      (InterfaceRequest<Module> request) {
        _log('Received binding request for Module');
        _module.bindModule(request);
      },
      Module.serviceName,
    )
    ..addServiceForName(
      (InterfaceRequest<Lifecycle> request) {
        _module.bindLifecycle(request);
      },
      Lifecycle.serviceName,
    );

  _controller.addListener(() {
    String currentText = _controller.text;
    int selectionStart = _controller.selection.start;
    int selectionEnd = _controller.selection.end;
    _module
      ..publishText(currentText)
      ..publishSelection(selectionStart, selectionEnd);
  });

  runApp(new MaterialApp(
    title: 'Basic Text Reporter',
    home: new Scaffold(
      appBar: new AppBar(
        title: const Text('Basic Text Reporter'),
      ),
      body: new Container(
        child: new TextField(
          controller: _controller,
          decoration: const InputDecoration(
              hintText: 'Type something, selectable entities will become'
                  ' ALL CAPS'),
        ),
      ),
    ),
  ));
}
