// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "topaz/lib/deprecated_loop/waitable_event.h"

namespace deprecated_loop {

void AutoResetWaitableEvent::Signal() {
  std::lock_guard<std::mutex> locker(mutex_);
  signaled_ = true;
  cv_.notify_one();
}

void AutoResetWaitableEvent::Wait() {
  std::unique_lock<std::mutex> locker(mutex_);
  while (!signaled_)
    cv_.wait(locker);
  signaled_ = false;
}

}  // namespace deprecated_loop
