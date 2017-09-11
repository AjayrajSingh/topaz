// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/debugger/dart_debugger.h"

#include "dart/runtime/include/dart_api.h"
#include "dart/runtime/include/dart_native_api.h"
#include "dart/runtime/include/dart_tools_api.h"
#include "lib/fxl/logging.h"

namespace tonic {

void DartDebuggerIsolate::MessageLoop() {
  fxl::MonitorLocker locker(&monitor_);
  Dart_MessageNotifyCallback saved_message_notify_callback =
      Dart_GetMessageNotifyCallback();
  // Request notification on isolate messages.  This allows us to
  // respond to vm service messages while at breakpoint.
  Dart_SetMessageNotifyCallback(DartDebugger::NotifyIsolate);
  while (true) {
    // Handle all available vm service messages, up to a resume
    // request.
    bool resume = false;
    while (!resume && Dart_HasServiceMessages()) {
      monitor_.Exit();
      resume = Dart_HandleServiceMessages();
      monitor_.Enter();
    }
    if (resume) {
      break;
    }
    locker.Wait();
  }
  Dart_SetMessageNotifyCallback(saved_message_notify_callback);
}

void DartDebugger::BptResolvedHandler(Dart_IsolateId isolate_id,
                                      intptr_t bp_id,
                                      const Dart_CodeLocation& location) {
  // Nothing to do here. Service event is dispatched to let Observatory know
  // that a breakpoint was resolved.
}

void DartDebugger::PausedEventHandler(Dart_IsolateId isolate_id,
                                      intptr_t bp_id,
                                      const Dart_CodeLocation& loc) {
  Dart_EnterScope();
  intptr_t isolate_index = FindIsolateIndexById(isolate_id);
  FXL_CHECK(isolate_index != -1);
  (*isolates_)[isolate_index]->MessageLoop();
  Dart_ExitScope();
}

void DartDebugger::ExceptionThrownHandler(Dart_IsolateId isolate_id,
                                          Dart_Handle exception,
                                          Dart_StackTrace stack_trace) {
  Dart_EnterScope();
  intptr_t isolate_index = FindIsolateIndexById(isolate_id);
  FXL_CHECK(isolate_index != -1);
  (*isolates_)[isolate_index]->MessageLoop();
  Dart_ExitScope();
}

void DartDebugger::IsolateEventHandler(Dart_IsolateId isolate_id,
                                       Dart_IsolateEvent kind) {
  Dart_EnterScope();
  if (kind == Dart_IsolateEvent::kCreated) {
    AddIsolate(isolate_id);
  } else {
    intptr_t isolate_index = FindIsolateIndexById(isolate_id);
    FXL_CHECK(isolate_index != -1);
    if (kind == Dart_IsolateEvent::kInterrupted) {
      (*isolates_)[isolate_index]->MessageLoop();
    } else {
      FXL_CHECK(kind == Dart_IsolateEvent::kShutdown);
      RemoveIsolate(isolate_id);
    }
  }
  Dart_ExitScope();
}

void DartDebugger::NotifyIsolate(Dart_Isolate isolate) {
  fxl::MutexLocker locker(mutex_);
  Dart_IsolateId isolate_id = Dart_GetIsolateId(isolate);
  intptr_t isolate_index = FindIsolateIndexByIdLocked(isolate_id);
  if (isolate_index >= 0) {
    (*isolates_)[isolate_index]->Notify();
  }
}

void DartDebugger::InitDebugger() {
  Dart_SetIsolateEventHandler(IsolateEventHandler);
  Dart_SetPausedEventHandler(PausedEventHandler);
  Dart_SetBreakpointResolvedHandler(BptResolvedHandler);
  Dart_SetExceptionThrownHandler(ExceptionThrownHandler);
  mutex_ = new fxl::Mutex();
  isolates_ = new std::vector<std::unique_ptr<DartDebuggerIsolate>>();
}

intptr_t DartDebugger::FindIsolateIndexById(Dart_IsolateId id) {
  fxl::MutexLocker locker(mutex_);
  return FindIsolateIndexByIdLocked(id);
}

intptr_t DartDebugger::FindIsolateIndexByIdLocked(Dart_IsolateId id) {
  mutex_->AssertHeld();
  for (size_t i = 0; i < isolates_->size(); i++) {
    if ((*isolates_)[i]->id() == id) {
      return i;
    }
  }
  return -1;
}

void DartDebugger::AddIsolate(Dart_IsolateId id) {
  fxl::MutexLocker locker(mutex_);
  FXL_CHECK(FindIsolateIndexByIdLocked(id) == -1);
  std::unique_ptr<DartDebuggerIsolate> debugger_isolate =
      std::unique_ptr<DartDebuggerIsolate>(new DartDebuggerIsolate(id));
  isolates_->push_back(std::move(debugger_isolate));
}

void DartDebugger::RemoveIsolate(Dart_IsolateId id) {
  fxl::MutexLocker locker(mutex_);
  for (size_t i = 0; i < isolates_->size(); i++) {
    if (id == (*isolates_)[i]->id()) {
      isolates_->erase(isolates_->begin() + i);
      return;
    }
  }
  FXL_NOTREACHED();
}

fxl::Mutex* DartDebugger::mutex_ = nullptr;
std::vector<std::unique_ptr<DartDebuggerIsolate>>* DartDebugger::isolates_ =
    nullptr;

}  // namespace tonic
