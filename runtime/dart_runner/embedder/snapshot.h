// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <stdint.h>

#if defined(AOT_RUNTIME)

extern "C" uint8_t _kDartVmSnapshotData[];
extern "C" uint8_t _kDartVmSnapshotInstructions[];

#else  // !AOT_RUNTIME

namespace dart_content_handler {

extern uint8_t const* const vm_isolate_snapshot_buffer;
extern uint8_t const* const isolate_snapshot_buffer;

}  // namespace dart_content_handler

#endif  // !AOT_RUNTIME
