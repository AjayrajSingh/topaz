// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef TOPAZ_SHELL_ERMINE_USER_SHELL_FIND_UNIQUE_PTR_H_
#define TOPAZ_SHELL_ERMINE_USER_SHELL_FIND_UNIQUE_PTR_H_

#include <algorithm>
#include <memory>

namespace ermine_user_shell {

template <typename Iter, typename T>
Iter FindUniquePtr(Iter begin, Iter end, T* object) {
  return std::find_if(begin, end, [object](const std::unique_ptr<T>& other) {
    return other.get() == object;
  });
}

}  // namespace ermine_user_shell

#endif  // TOPAZ_SHELL_ERMINE_USER_SHELL_APP_H_
