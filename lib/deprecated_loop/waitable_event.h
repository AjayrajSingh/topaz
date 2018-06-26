// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Provides classes with functionality analogous to (but much more limited than)
// Chromium's |base::WaitableEvent|, which in turn provides functionality
// analogous to Windows's Event. (Unlike these two, we have separate types for
// the manual- and auto-reset versions.)

#ifndef LIB_DEPRECATED_LOOP_WAITABLE_EVENT_H_
#define LIB_DEPRECATED_LOOP_WAITABLE_EVENT_H_

#include <condition_variable>
#include <mutex>

#include "lib/fxl/fxl_export.h"
#include "lib/fxl/macros.h"

namespace deprecated_loop {

// DEPRECATED
// An event that can be signaled and waited on. This version automatically
// returns to the unsignaled state after unblocking one waiter. (This is similar
// to Windows's auto-reset Event, which is also imitated by Chromium's
// auto-reset |base::WaitableEvent|. However, there are some limitations -- see
// |Signal()|.) This class is thread-safe.
class FXL_EXPORT AutoResetWaitableEvent final {
 public:
  AutoResetWaitableEvent() {}
  ~AutoResetWaitableEvent() {}

  // Put the event in the signaled state. Exactly one |Wait()| will be unblocked
  // and the event will be returned to the unsignaled state.
  //
  // Notes (these are arguably bugs, but not worth working around):
  // * That |Wait()| may be one that occurs on the calling thread, *after* the
  //   call to |Signal()|.
  // * We rely on pthreads's queueing for picking which waiting thread to
  //   unblock, rather than enforcing FIFO ordering.
  void Signal();

  // Blocks the calling thread until the event is signaled. Upon unblocking, the
  // event is returned to the unsignaled state, so that (unless |Reset()| is
  // called) each |Signal()| unblocks exactly one |Wait()|.
  void Wait();

 private:
  std::condition_variable cv_;
  std::mutex mutex_;

  // True if this event is in the signaled state.
  bool signaled_ = false;

  FXL_DISALLOW_COPY_AND_ASSIGN(AutoResetWaitableEvent);
};

}  // namespace deprecated_loop

#endif  // LIB_DEPRECATED_LOOP_WAITABLE_EVENT_H_
