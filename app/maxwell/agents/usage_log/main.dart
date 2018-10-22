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
import 'package:fidl_fuchsia_mem/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:zircon/zircon.dart';

// Path to Config proto
const String _cobaltConfigBinProtoPath = '/pkg/data/cobalt_config.pb';

// The IDs of the Cobalt metric and encoding we are using.
// These specify objects within our Cobalt project configuration.
enum Metric {
  moduleLaunched,
  modulePairsInStory,
}
const String _existingModuleKey = 'existing_module';
const String _addedModuleKey = 'added_module';

// connection to context reader
final ContextReaderProxy _contextReader = new ContextReaderProxy();
ContextListenerImpl _contextListener;

// connection to Cobalt
final LoggerProxy _logger = new LoggerProxy();

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
      _logStringEvent(Metric.moduleLaunched, value.meta.mod.url);
      for (String existingMod in _storyModules[storyId]) {
        _logModulePairEvent(existingMod, modUrl);
      }
      _storyModules[storyId].add(modUrl);
    }
  }
}

void _logStringEvent(Metric metric, String metricString) {
  int metricId = _getCobaltMetricID(metric);
  _logger.logString(
      metricId, metricString, (Status s) => _onLogEventStatus(metricId, s));
}

void _logModulePairEvent(String existingMod, String newMod) {
  int metricId = _getCobaltMetricID(Metric.modulePairsInStory);
  _logger.logCustomEvent(
      metricId,
      <CustomEventValue>[
        _getStringEventValue(_existingModuleKey, existingMod),
        _getStringEventValue(_addedModuleKey, newMod)
      ],
      (Status s) => _onLogEventStatus(metricId, s));
}

CustomEventValue _getStringEventValue(String name, String value) {
  return new CustomEventValue(
      dimensionName: name, value: new Value.withStringValue(value));
}

void _onLogEventStatus(int metricId, Status status) {
  // If logging an event fails, we simply drop it and do not retry.
  // TODO(jwnichols): Perhaps we should do something smarter if we fail
  if (status != Status.ok) {
    print('[USAGE LOG] Failed to log Cobalt event: $status. '
        'Metric ID: $metricId');
  }
}

ProjectProfile _loadCobaltConfig() {
  SizedVmo configVmo = SizedVmo.fromFile(_cobaltConfigBinProtoPath);
  ProjectProfile profile = ProjectProfile(
      config: Buffer(vmo: configVmo, size: configVmo.size),
      releaseStage: ReleaseStage.ga);

  return profile;
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
  final LoggerFactoryProxy loggerFactory = new LoggerFactoryProxy();
  connectToService(context.environmentServices, loggerFactory.ctrl);
  assert(loggerFactory.ctrl.isBound);

  // Get the loggers
  loggerFactory.createLogger(_loadCobaltConfig(), _logger.ctrl.request(),
      (Status s) {
    if (s != Status.ok) {
      print('[USAGE LOG] Failed to obtain Logger. Cobalt config is invalid.');
    }
  });

  context.close();
  loggerFactory.ctrl.close();
}
