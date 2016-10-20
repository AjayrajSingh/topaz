// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/dart_microtask_queue.h"

#include <vector>

#include "lib/tonic/logging/dart_invoke.h"
#include "lib/tonic/dart_persistent_value.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/dart_sticky_error.h"

namespace tonic {
namespace {

typedef std::vector<DartPersistentValue> MicrotaskQueue;

static MicrotaskQueue& GetQueue() {
  static MicrotaskQueue* queue = new MicrotaskQueue();
  return *queue;
}

}  // namespace

void DartMicrotaskQueue::ScheduleMicrotask(Dart_Handle callback) {
  GetQueue().emplace_back(DartState::Current(), callback);
}

void DartMicrotaskQueue::RunMicrotasks() {
  MicrotaskQueue& queue = GetQueue();
  while (!queue.empty()) {
    MicrotaskQueue local;
    std::swap(queue, local);
    for (const auto& callback : local) {
      ftl::WeakPtr<DartState> dart_state = callback.dart_state();
      if (!dart_state.get())
        continue;
      DartState::Scope dart_scope(dart_state.get());
      DartInvokeVoid(callback.value());
    }
  }
}
}
