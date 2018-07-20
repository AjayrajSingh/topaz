// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_DEPRECATED_LOOP_THREAD_H_
#define LIB_DEPRECATED_LOOP_THREAD_H_

#include "lib/fxl/fxl_export.h"
#include "lib/fxl/macros.h"
#include "lib/fxl/memory/ref_ptr.h"
#include "lib/fxl/tasks/task_runner.h"
#include "lib/fxl/threading/thread.h"
#include "topaz/lib/deprecated_loop/incoming_task_queue.h"

namespace deprecated_loop {

namespace internal {
class IncomingTaskQueue;
}  // namespace internal

// DEPRECATED
class FXL_EXPORT Thread {
 public:
  static constexpr size_t default_stack_size = 1 * 1024 * 1024;

  Thread();
  ~Thread();
  bool Run(size_t stack_size = default_stack_size);
  bool IsRunning() const;
  bool Join();
  fxl::RefPtr<fxl::TaskRunner> TaskRunner() const;

 private:
  void Main();

  fxl::Thread thread_;
  fxl::RefPtr<internal::IncomingTaskQueue> task_runner_;

  FXL_DISALLOW_COPY_AND_ASSIGN(Thread);
};

}  // namespace deprecated_loop

#endif  // LIB_DEPRECATED_LOOP_THREAD_H_
