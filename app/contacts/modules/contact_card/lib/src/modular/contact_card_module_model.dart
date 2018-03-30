// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:entity_schemas/entities.dart' as entities;
import 'package:fuchsia.fidl.component/component.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';

import '../models/contact_card_model.dart';
import 'link_data.dart';

/// The model for the contact card module
class ContactCardModuleModel extends ModuleModel {
  /// The data store for the module
  final ContactCardModel model;

  // Need component context and entity resolver for retrieving contact data
  final ComponentContextProxy _componentContextProxy =
      new ComponentContextProxy();
  final EntityResolverProxy _entityResolverProxy = new EntityResolverProxy();

  /// Instantiate new [ContactCardModuleModel] with a data store
  ContactCardModuleModel({@required this.model}) : assert(model != null);

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
  ) {
    super.onReady(moduleContext, link);
    log.fine('ContactCardModuleModel onReady');

    // This module needs the entity resolver to retrieve the contact data for it
    // to render
    moduleContext.getComponentContext(_componentContextProxy.ctrl.request());
    _componentContextProxy.getEntityResolver(
      _entityResolverProxy.ctrl.request(),
    );
  }

  @override
  Future<Null> onNotify(String json) async {
    log.fine('ContactCardModuleModel received link data $json');

    // TODO (meiyili): update UI to show loading indicator while resolving
    // entities SO-989
    LinkData linkData = new LinkData.fromJson(json);
    if (linkData != null) {
      entities.Contact contact = await _resolveEntity(linkData.entityReference);
      model.contact = contact;
    } else {
      log.warning('Malformed link data $json');
    }
  }

  @override
  void onStop() {
    log.fine('ContactCardModuleModel onStop');
    _componentContextProxy.ctrl.close();
    _entityResolverProxy.ctrl.close();
  }

  Future<entities.Contact> _resolveEntity(String entityReference) async {
    log.fine('Trying to resolve entity reference $entityReference');

    entities.Contact contact;

    EntityProxy entityProxy = new EntityProxy();
    _entityResolverProxy.resolveEntity(
      entityReference,
      entityProxy.ctrl.request(),
    );

    // Get the type of this entity to determine if the type of this entity
    // matches what we can render
    Completer<List<String>> typesCompleter = new Completer<List<String>>();
    List<String> currEntityTypes = <String>[];
    entityProxy.getTypes((List<String> types) {
      log.fine('Entity types = $types');
      typesCompleter.complete(types);
    });
    currEntityTypes = await typesCompleter.future;

    String contactType = entities.Contact.getType();
    if (currEntityTypes.contains(contactType)) {
      Completer<String> dataCompleter = new Completer<String>();

      // Retrieve the data for the type of entity we can render
      entityProxy.getData(contactType, (String data) {
        dataCompleter.complete(data);
      });

      // Ideally the framework could return typed information for us
      // feature request tracked in: MI4-696
      String data = await dataCompleter.future;
      try {
        contact = new entities.Contact.fromData(data);
        log.fine('Successfully resolved the entity');
      } on Exception catch (e) {
        log.warning(
            'Error decoding contact entity from data = $data, error = $e');
      }
    }

    // Close proxy to entity interface
    entityProxy.ctrl.close();
    return contact;
  }
}
