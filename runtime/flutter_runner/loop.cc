// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "loop.h"

#include <lib/async-loop/loop.h>

#include "task_observers.h"

namespace flutter_runner {

namespace {

static void LoopEpilogue(async_loop_t*, void*) {
  ExecuteAfterTaskObservers();
}

constexpr async_loop_config_t kAttachedLoopConfig = {
  .make_default_for_current_thread = true,
  .epilogue = &LoopEpilogue,
};

constexpr async_loop_config_t kDetachedLoopConfig = {
  .make_default_for_current_thread = false,
  .epilogue = &LoopEpilogue,
};

}  // namespace

async::Loop* MakeObservableLoop(bool attachToThread) {
  return new async::Loop(&(attachToThread ? kAttachedLoopConfig :
                                            kDetachedLoopConfig));
}

}  // namespace flutter_runner
