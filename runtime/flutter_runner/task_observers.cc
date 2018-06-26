// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "task_observers.h"

#include <map>

#include "topaz/lib/deprecated_loop/message_loop.h"

namespace flutter {

thread_local std::map<intptr_t, fxl::Closure> tTaskObservers;

static void ExecuteAfterTaskObservers() {
  for (const auto& callback : tTaskObservers) {
    callback.second();
  }
}

void CurrentMessageLoopAddAfterTaskObserver(intptr_t key,
                                            fxl::Closure observer) {
  if (!observer) {
    return;
  }

  if (tTaskObservers.size() == 0) {
    deprecated_loop::MessageLoop::GetCurrent()->SetAfterTaskCallback(
        std::bind(&ExecuteAfterTaskObservers));
  }

  tTaskObservers[key] = observer;
}

void CurrentMessageLoopRemoveAfterTaskObserver(intptr_t key) {
  tTaskObservers.erase(key);

  if (tTaskObservers.size() == 0) {
    deprecated_loop::MessageLoop::GetCurrent()->ClearAfterTaskCallback();
  }
}

}  // namespace flutter
