// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This agent uses Cobalt to record usage data in a privacy preserving way.
// To learn more about Cobalt, see:
// https://fuchsia.googlesource.com/garnet/+/master/bin/cobalt/README.md
//
// To view the data collected by this agent in Cobalt, read the following
// instructions:
// https://fuchsia.googlesource.com/garnet/+/master/bin/cobalt/README.md#Report-Client
//
// After downloading the reporting tool, run it with the command line:
// ./report_client -report_master_uri=35.188.119.76:7001 -project_id=101
//
// At the report tool command line, type "run full 1" to see the module URL
// report for the complete set of data.

import 'dart:collection';

import 'package:lib.app.dart/app.dart';
import 'package:lib.context.dart/context_listener_impl.dart';
import 'package:fidl_fuchsia_cobalt/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';

// The project ID of the usage_log registered in Cobalt.
const int _cobaltProjectID = 101;

// The IDs of the Cobalt metric and encoding we are using.
// These specify objects within our Cobalt project configuration.
enum Metric {
  moduleLaunched,
  modulePairsInStory,
}
const int _cobaltForculusEncodingID = 1;
const int _cobaltNoOpEncodingID = 2;
const String _existingModuleKey = 'existing_module';
const String _addedModuleKey = 'added_module';

// connection to context reader
final ContextReaderProxy _contextReader = new ContextReaderProxy();
ContextListenerImpl _contextListener;

// connection to Cobalt
final CobaltEncoderProxy _encoder = new CobaltEncoderProxy();

// Deduplication Map
final Map<String, LinkedHashSet<String>> _storyModules =
    <String, LinkedHashSet<String>>{};

// Transform Metric enum index to Cobalt Metric ID.
int _getCobaltMetricID(Metric metric) {
  return metric.index + 1;
}

// ContextListener callback
void _onContextUpdate(ContextUpdate update) {
  for (final ContextUpdateEntry entry in update.values) {
    if (entry.key != 'modules') {
      continue;
    }

    for (ContextValue value in entry.value) {
      String modUrl = '${value.meta.mod.url}';
      String storyId = '${value.meta.story?.id}';

      if (storyId == null) {
        return;
      }

      // To record module launches, we only process each topic once
      _storyModules.putIfAbsent(storyId, () => new LinkedHashSet<String>());
      if (_storyModules[storyId].contains(modUrl)) {
        return;
      }
      _addStringObservation(Metric.moduleLaunched, value.meta.mod.url);
      for (String existingMod in _storyModules[storyId]) {
        _addModulePairObservation(existingMod, modUrl);
      }
      _storyModules[storyId].add(modUrl);
    }
  }
}

void _addStringObservation(Metric metric, String metricString) {
  int metricId = _getCobaltMetricID(metric);
  _encoder.addStringObservation(metricId, _cobaltForculusEncodingID,
      metricString, (Status s) => _onAddObservationStatus(metricId, s));
}

void _addModulePairObservation(String existingMod, String newMod) {
  int metricId = _getCobaltMetricID(Metric.modulePairsInStory);
  _encoder.addMultipartObservation(
      metricId,
      <ObservationValue>[
        _getStringObservationValue(_existingModuleKey, existingMod),
        _getStringObservationValue(_addedModuleKey, newMod)
      ],
      (Status s) => _onAddObservationStatus(metricId, s));
}

ObservationValue _getStringObservationValue(String name, String value) {
  return new ObservationValue(
      name: name,
      value: new Value.withStringValue(value),
      encodingId: _cobaltNoOpEncodingID);
}

void _onAddObservationStatus(int metricId, Status status) {
  // If adding an observation fails, we simply drop it and do not retry.
  // TODO(jwnichols): Perhaps we should do something smarter if we fail
  if (status != Status.ok) {
    print('[USAGE LOG] Failed to add Cobalt observation: $status. '
        'Metric ID: $metricId');
  }
}

void main(List<String> args) {
  final StartupContext context = new StartupContext.fromStartupInfo();

  // Connect to the ContextReader
  _contextListener = new ContextListenerImpl(_onContextUpdate);
  connectToService(context.environmentServices, _contextReader.ctrl);
  assert(_contextReader.ctrl.isBound);

  // Subscribe to all topics
  ContextSelector selector =
      const ContextSelector(type: ContextValueType.module);
  ContextQuery query = new ContextQuery(selector: <ContextQueryEntry>[
    new ContextQueryEntry(key: 'modules', value: selector)
  ]);
  _contextReader.subscribe(query, _contextListener.getHandle());

  // Connect to Cobalt
  final CobaltEncoderFactoryProxy encoderFactory =
      new CobaltEncoderFactoryProxy();
  connectToService(context.environmentServices, encoderFactory.ctrl);
  assert(encoderFactory.ctrl.isBound);

  // Get an encoder
  encoderFactory.getEncoder(_cobaltProjectID, _encoder.ctrl.request());

  context.close();
  encoderFactory.ctrl.close();
}
