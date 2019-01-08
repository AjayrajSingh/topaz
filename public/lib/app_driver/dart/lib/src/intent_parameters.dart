// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:fidl_fuchsia_mem/fidl.dart' as fuchsia_mem;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.schemas.dart/entity_codec.dart';
import 'package:zircon/zircon.dart';

/// A class which wraps parameters delivered to a module via the
/// [IntentHandler] interface. It provides access to the parameter
/// data in a uniform way, regardless of how the [Intent.parameters]
/// was constructed.
///
/// If a parameter was created with a link, it's possible for the
/// parameter data to change over time. In this case it's better to
/// use [IntentParameters.watchParameterData], which allows modules
/// to observe changes to the parameter. If the module does not care
/// about potential future updates, [IntentParameters.getParameterData]
/// will provide the data directly.
class IntentParameters {
  final Map<String, IntentParameterData> _parameters = {};
  // TODO: Refactor this class to use the new SDK instead of deprecated API
  // ignore: deprecated_member_use
  ModuleDriver _driver;

  /// [moduleDriver] is used to access Entity and Link parameters.
  /// [parameters] are the parmeters from an [Intent].
  IntentParameters({
    ModuleDriver moduleDriver, // ignore: deprecated_member_use
    List<IntentParameter> parameters,
  }) {
    _driver = moduleDriver;
    for (var parameter in parameters ?? []) {
      _parameters[parameter.name] = parameter.data;
    }
  }

  /// Returns the data for the parameter with name [parameterName].
  Future<T> getParameterData<T>(
      String parameterName, EntityCodec<T> codec) async {
    IntentParameterData data = _parameters[parameterName];
    if (data == null) {
      throw Exception('Invalid parameter name: $parameterName');
    }

    switch (data.tag) {
      case IntentParameterDataTag.json:
        return _getJsonData(data.json, codec);
      case IntentParameterDataTag.entityReference:
        return _getEntityData(data.entityReference, codec);
      default:
        throw Exception('Unsupported parameter type.');
    }
  }

  T _getJsonData<T>(fuchsia_mem.Buffer json, EntityCodec<T> codec) {
    final vmo = SizedVmo(json.vmo.handle, json.size);
    final data = vmo.read(json.size);
    if (data.status != 0) {
      throw Exception('Failed to read VMO');
    }
    vmo.close();
    return codec.decode(jsonDecode(utf8.decode(data.bytesAsUint8List())));
  }

  Future<T> _getEntityData<T>(
      String entityReference, EntityCodec<T> codec) async {
    final resolver = await _driver.getResolver();
    final entity = await resolver.resolveEntity(entityReference);
    final types = await entity.getTypes();

    if (!types.contains(codec.type)) {
      throw EntityTypeException(codec.type);
    }

    var data = await entity.getData(codec.type);
    return codec.decode(data);
  }

  /// Returns a stream of data. If the parameter is JSON, or an Entity the data
  /// will be added to the stream and the stream will then be closed. If the
  /// parameter is a Link, any observed updates to the Link will also be added
  /// to the stream.
  Stream<T> watchParameterData<T>(String parameterName, EntityCodec<T> codec) {
    IntentParameterData data = _parameters[parameterName];
    if (data == null) {
      throw Exception('Invalid parameter name');
    }

    StreamController<T> controller = new StreamController<T>(
      onListen: () => log.info('watch stream ($parameterName): listening'),
      onPause: () => log.info('watch stream ($parameterName): paused'),
      onResume: () => log.info('watch stream ($parameterName): resuming'),
      onCancel: () => log.info('watch stream ($parameterName): cancelled'),
    );

    switch (data.tag) {
      case IntentParameterDataTag.json:
        controller.add(_getJsonData(data.json, codec));
        controller.close();
        break;
      case IntentParameterDataTag.entityReference:
        _getEntityData(data.entityReference, codec).then((entityData) {
          controller
            ..add(entityData)
            ..close();
        });
        break;
      default:
        throw Exception('Unsupported parameter type: ${data.tag}');
    }
    return controller.stream;
  }
}
