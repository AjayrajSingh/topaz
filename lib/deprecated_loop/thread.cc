// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/lib/deprecated_loop/thread.h"

#include "topaz/lib/deprecated_loop/incoming_task_queue.h"
#include "topaz/lib/deprecated_loop/message_loop.h"

namespace deprecated_loop {

Thread::Thread()
    : thread_([this] { Main(); }),
      task_runner_(fxl::MakeRefCounted<internal::IncomingTaskQueue>()) {}

Thread::~Thread() {}

bool Thread::Run(size_t stack_size) { return thread_.Run(stack_size); }

bool Thread::IsRunning() const { return thread_.IsRunning(); }

fxl::RefPtr<fxl::TaskRunner> Thread::TaskRunner() const { return task_runner_; }

void Thread::Main(void) {
  MessageLoop message_loop(task_runner_);
  message_loop.Run();
}

bool Thread::Join() { return thread_.Join(); }

}  // namespace deprecated_loop
