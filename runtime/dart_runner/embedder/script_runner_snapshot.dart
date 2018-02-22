// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Core SDK libraries.
import 'dart:async';
import 'dart:core';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:fuchsia.builtin';
import 'dart:zircon';
import 'dart:fuchsia';
import 'dart:typed_data';

// If new imports are added to this list, then it is also necessary to ensure
// that the dart_deps parameter in the rule
// gen_snapshot_cc("script_runner_snapshot") in the BUILD.gn file in this
// directory is updated with any new dependencies.

import 'package:fuchsia/fuchsia.dart';
import 'package:zircon/zircon.dart';

// FIDL bindings and application libraries.
import 'package:lib.app.dart/app.dart';
import 'package:lib.fidl.dart/bindings.dart';

// From //peridot/public/lib/agent
import 'package:lib.agent.fidl/agent.fidl.dart';
import 'package:lib.agent.fidl/agent_context.fidl.dart';
import 'package:lib.agent.fidl/agent_provider.fidl.dart';

// From //peridot/public/lib/clipboard
import 'package:lib.clipboard.fidl/clipboard.fidl.dart';

// From //peridot/public/lib/daisy
import 'package:lib.daisy.fidl/daisy.fidl.dart';

// From //peridot/public/lib/device
import 'package:lib.device.fidl/device_shell.fidl.dart';
import 'package:lib.device.fidl/device_runner_monitor.fidl.dart';
import 'package:lib.device.fidl/user_provider.fidl.dart';

// From //peridot/public/lib/entity
import 'package:lib.entity.fidl/entity.fidl.dart';
import 'package:lib.entity.fidl/entity_provider.fidl.dart';
import 'package:lib.entity.fidl/entity_reference_factory.fidl.dart';
import 'package:lib.entity.fidl/entity_resolver.fidl.dart';

// From //peridot/public/lib/module
import 'package:lib.module.fidl/module.fidl.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';

// From //peridot/public/lib/module_resolver
import 'package:lib.module_resolver.fidl/module_resolver.fidl.dart';

// From //peridot/public/lib/resolver
import 'package:lib.resolver.fidl/resolver.fidl.dart';

// From //peridot/public/lib/story
import 'package:lib.story.fidl/create_link.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.story.fidl/link_change.fidl.dart';
import 'package:lib.story.fidl/per_device_story_info.fidl.dart';
import 'package:lib.story.fidl/story_controller.fidl.dart';
import 'package:lib.story.fidl/story_info.fidl.dart';
import 'package:lib.story.fidl/story_marker.fidl.dart';
import 'package:lib.story.fidl/story_provider.fidl.dart';
import 'package:lib.story.fidl/story_state.fidl.dart';

// From //peridot/public/lib/user
import 'package:lib.user.fidl/device_map.fidl.dart';
import 'package:lib.user.fidl/user_shell.fidl.dart';

// From //peridot/public/lib/user_intelligence
import 'package:lib.user_intelligence.fidl/intelligence_services.fidl.dart';
import 'package:lib.user_intelligence.fidl/user_intelligence_provider.fidl.dart';
