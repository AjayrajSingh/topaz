// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "task_observers.h"

#include <map>

namespace flutter_runner {

thread_local std::map<intptr_t, fit::closure> tTaskObservers;

void ExecuteAfterTaskObservers() {
  for (const auto& callback : tTaskObservers) {
    callback.second();
  }
}

void CurrentMessageLoopAddAfterTaskObserver(intptr_t key,
                                            fit::closure observer) {
  if (observer) {
    tTaskObservers[key] = std::move(observer);
  }
}

void CurrentMessageLoopRemoveAfterTaskObserver(intptr_t key) {
  tTaskObservers.erase(key);
}

}  // namespace flutter_runner
