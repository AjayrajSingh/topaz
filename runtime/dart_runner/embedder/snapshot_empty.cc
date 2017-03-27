// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file is linked into the dart executable when it has a snapshot
// linked into it.

#include "apps/dart_content_handler/embedder/snapshot.h"

namespace dart_content_handler {

uint8_t const* const vm_isolate_snapshot_buffer = nullptr;
uint8_t const* const isolate_snapshot_buffer = nullptr;

}  // namespace dart_content_handler
