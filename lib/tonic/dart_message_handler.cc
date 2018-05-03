// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/dart_message_handler.h"

#include "lib/fxl/logging.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/dart_sticky_error.h"
#include "lib/tonic/logging/dart_error.h"
#include "third_party/dart/runtime/include/dart_api.h"
#include "third_party/dart/runtime/include/dart_native_api.h"
#include "third_party/dart/runtime/include/dart_tools_api.h"

namespace tonic {

DartMessageHandler::DartMessageHandler()
    : handled_first_message_(false),
      isolate_exited_(false),
      isolate_had_uncaught_exception_error_(false),
      isolate_had_fatal_error_(false),
      isolate_last_error_(kNoError),
      task_runner_(nullptr) {}

DartMessageHandler::~DartMessageHandler() {
  task_runner_ = nullptr;
}

void DartMessageHandler::Initialize(const fxl::RefPtr<fxl::TaskRunner>& runner) {
  // Only can be called once.
  FXL_CHECK(!task_runner_);
  task_runner_ = runner;
  FXL_CHECK(task_runner_);
  Dart_SetMessageNotifyCallback(MessageNotifyCallback);
}

void DartMessageHandler::OnMessage(DartState* dart_state) {
  auto task_runner = dart_state->message_handler().task_runner();

  // Schedule a task to run on the message loop thread.
  fxl::WeakPtr<DartState> dart_state_ptr = dart_state->GetWeakPtr();
  task_runner->PostTask([dart_state_ptr]() {
    if (!dart_state_ptr)
      return;
    dart_state_ptr->message_handler().OnHandleMessage(dart_state_ptr.get());
  });
}

void DartMessageHandler::UnhandledError(Dart_Handle error) {
  FXL_DCHECK(Dart_CurrentIsolate());
  FXL_DCHECK(Dart_IsError(error));

  isolate_last_error_ = GetErrorHandleType(error);
  // Remember that we had an uncaught exception error.
  isolate_had_uncaught_exception_error_ = true;
  if (Dart_IsFatalError(error)) {
    isolate_had_fatal_error_ = true;
    // Stop handling messages.
    Dart_SetMessageNotifyCallback(nullptr);
    // Shut down the isolate.
    Dart_ShutdownIsolate();
  }
}

void DartMessageHandler::OnHandleMessage(DartState* dart_state) {
  if (isolate_had_fatal_error_) {
    // Don't handle any more messages.
    return;
  }

  DartIsolateScope scope(dart_state->isolate());
  DartApiScope dart_api_scope;
  Dart_Handle result = Dart_Null();
  bool error = false;

  // On the first message, check if we should pause on isolate start.
  if (!handled_first_message()) {
    set_handled_first_message(true);
    if (Dart_ShouldPauseOnStart()) {
      // Mark that we are paused on isolate start.
      Dart_SetPausedOnStart(true);
    }
  }

  if (Dart_IsPausedOnStart()) {
    // We are paused on isolate start. Only handle service messages until we are
    // requested to resume.
    if (Dart_HasServiceMessages()) {
      bool resume = Dart_HandleServiceMessages();
      if (!resume) {
        return;
      }
      Dart_SetPausedOnStart(false);
      // We've resumed, handle normal messages that are in the queue.
      result = Dart_HandleMessage();
      error = LogIfError(result);
      dart_state->MessageEpilogue(result);
      if (!Dart_CurrentIsolate()) {
        isolate_exited_ = true;
        return;
      }
    }
  } else if (Dart_IsPausedOnExit()) {
    // We are paused on isolate exit. Only handle service messages until we are
    // requested to resume.
    if (Dart_HasServiceMessages()) {
      bool resume = Dart_HandleServiceMessages();
      if (!resume) {
        return;
      }
      Dart_SetPausedOnExit(false);
    }
  } else {
    // We are processing messages normally.
    result = Dart_HandleMessage();
    // If the Dart program has set a return code, then it is intending to shut
    // down by way of a fatal error, and so there is no need to emit a log
    // message.
    if (dart_state->has_set_return_code() && Dart_IsError(result) &&
        Dart_IsFatalError(result)) {
      error = true;
    } else {
      error = LogIfError(result);
    }
    dart_state->MessageEpilogue(result);
    if (!Dart_CurrentIsolate()) {
      isolate_exited_ = true;
      return;
    }
  }

  if (error) {
    UnhandledError(result);
  } else if (!Dart_HasLivePorts()) {
    // The isolate has no live ports and would like to exit.
    if (!Dart_IsPausedOnExit() && Dart_ShouldPauseOnExit()) {
      // Mark that we are paused on exit.
      Dart_SetPausedOnExit(true);
    } else {
      isolate_exited_ = true;
    }
  }
}

void DartMessageHandler::MessageNotifyCallback(Dart_Isolate dest_isolate) {
  auto dart_state = DartState::From(dest_isolate);
  FXL_CHECK(dart_state);
  dart_state->message_handler().OnMessage(dart_state);
}

}  // namespace tonic
