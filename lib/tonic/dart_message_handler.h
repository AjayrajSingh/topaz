// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_TONIC_DART_MESSAGE_HANDLER_H_
#define LIB_TONIC_DART_MESSAGE_HANDLER_H_

#include "dart/runtime/include/dart_api.h"
#include "lib/fxl/memory/ref_ptr.h"
#include "lib/fxl/memory/weak_ptr.h"
#include "lib/fxl/tasks/task_runner.h"
#include "lib/tonic/logging/dart_error.h"

namespace tonic {
class DartState;

class DartMessageHandler {
 public:
  DartMessageHandler();
  ~DartMessageHandler();

  // Messages for the current isolate will be scheduled on |runner|.
  void Initialize(const fxl::RefPtr<fxl::TaskRunner>& runner);

  // Did the isolate exit?
  bool isolate_exited() const { return isolate_exited_; }

  // Did the isolate have an uncaught exception error?
  bool isolate_had_uncaught_exception_error() const {
    return isolate_had_uncaught_exception_error_;
  }

  DartErrorHandleType isolate_last_error() const {
    return isolate_last_error_;
  }

 protected:
  // Called from an unknown thread for each message.
  void OnMessage(DartState* dart_state);
  // By default, called on the task runner's thread for each message.
  void OnHandleMessage(DartState* dart_state);

  const fxl::RefPtr<fxl::TaskRunner>& task_runner() const {
    return task_runner_;
  }

  bool handled_first_message() const { return handled_first_message_; }

  void set_handled_first_message(bool handled_first_message) {
    handled_first_message_ = handled_first_message;
  }

  bool handled_first_message_;
  bool isolate_exited_;
  bool isolate_had_uncaught_exception_error_;
  DartErrorHandleType isolate_last_error_;
  fxl::RefPtr<fxl::TaskRunner> task_runner_;

 private:
  static void MessageNotifyCallback(Dart_Isolate dest_isolate);
};

}  // namespace tonic

#endif  // LIB_TONIC_DART_MESSAGE_HANDLER_H_
