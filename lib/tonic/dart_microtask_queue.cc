// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/dart_microtask_queue.h"

#include "lib/tonic/logging/dart_invoke.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/dart_sticky_error.h"

namespace tonic {
namespace {

thread_local DartMicrotaskQueue* g_queue = nullptr;

}

DartMicrotaskQueue::DartMicrotaskQueue() : last_error_(kNoError) {}

DartMicrotaskQueue::~DartMicrotaskQueue() = default;

void DartMicrotaskQueue::StartForCurrentThread() {
  FTL_CHECK(!g_queue);
  g_queue = new DartMicrotaskQueue();
}

DartMicrotaskQueue* DartMicrotaskQueue::GetForCurrentThread() {
  FTL_DCHECK(g_queue);
  return g_queue;
}

void DartMicrotaskQueue::ScheduleMicrotask(Dart_Handle callback) {
  queue_.emplace_back(DartState::Current(), callback);
}

void DartMicrotaskQueue::RunMicrotasks() {
  while (!queue_.empty()) {
    MicrotaskQueue local;
    std::swap(queue_, local);
    for (const auto& callback : local) {
      ftl::WeakPtr<DartState> dart_state = callback.dart_state();
      if (!dart_state.get())
        continue;
      DartState::Scope dart_scope(dart_state.get());
      Dart_Handle result = DartInvokeVoid(callback.value());
      DartErrorHandleType error = GetErrorHandleType(result);
      if (error != kNoError)
        last_error_ = error;
    }
  }
}

void DartMicrotaskQueue::Destroy() {
  FTL_DCHECK(g_queue);
  delete g_queue;
  g_queue = nullptr;
}

DartErrorHandleType DartMicrotaskQueue::GetLastError() {
  return last_error_;
}

}
