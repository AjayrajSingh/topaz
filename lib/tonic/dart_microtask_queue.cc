// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/dart_microtask_queue.h"

#include "lib/fxl/build_config.h"
#include "lib/tonic/logging/dart_invoke.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/dart_sticky_error.h"

#ifdef OS_IOS
#include <pthread.h>
#endif

namespace tonic {
namespace {

#ifdef OS_IOS
// iOS doesn't support the thread_local keyword.

pthread_key_t g_queue_key;
pthread_once_t g_queue_key_once = PTHREAD_ONCE_INIT;

void MakeKey() {
  pthread_key_create(&g_queue_key, nullptr);
}

void SetQueue(DartMicrotaskQueue* queue) {
  pthread_once(&g_queue_key_once, MakeKey);
  pthread_setspecific(g_queue_key, queue);
}

DartMicrotaskQueue* GetQueue() {
  return static_cast<tonic::DartMicrotaskQueue*>(
      pthread_getspecific(g_queue_key));
}

#else

thread_local DartMicrotaskQueue* g_queue = nullptr;

void SetQueue(DartMicrotaskQueue* queue) {
  g_queue = queue;
}

DartMicrotaskQueue* GetQueue() {
  return g_queue;
}

#endif

} // namespace

DartMicrotaskQueue::DartMicrotaskQueue() : last_error_(kNoError) {}

DartMicrotaskQueue::~DartMicrotaskQueue() = default;

void DartMicrotaskQueue::StartForCurrentThread() {
  SetQueue(new DartMicrotaskQueue());
}

DartMicrotaskQueue* DartMicrotaskQueue::GetForCurrentThread() {
  return GetQueue();
}

void DartMicrotaskQueue::ScheduleMicrotask(Dart_Handle callback) {
  queue_.emplace_back(DartState::Current(), callback);
}

void DartMicrotaskQueue::RunMicrotasks() {
  while (!queue_.empty()) {
    MicrotaskQueue local;
    std::swap(queue_, local);
    for (const auto& callback : local) {
      fxl::WeakPtr<DartState> dart_state = callback.dart_state();
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
  FXL_DCHECK(this == GetForCurrentThread());
  SetQueue(nullptr);
  delete this;
}

DartErrorHandleType DartMicrotaskQueue::GetLastError() {
  return last_error_;
}

}
