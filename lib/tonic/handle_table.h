// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_TONIC_HANDLE_TABLE_H_
#define LIB_TONIC_HANDLE_TABLE_H_

#include <mx/handle.h>
#include <string>
#include <unordered_set>

#include "dart/runtime/include/dart_api.h"
#include "lib/ftl/macros.h"

namespace tonic {

class HandleTable {
 public:
  static HandleTable& Current();

  HandleTable();
  ~HandleTable();

  mx_handle_t Add(mx_handle_t handle);
  Dart_Handle AddAndWrap(mx_handle_t handle);
  Dart_Handle AddAndWrap(mx::handle handle) {
    return AddAndWrap(handle.release());
  }
  Dart_Handle AddAndWrap(mx_handle_t *handles, size_t count, Dart_Handle array);
  mx_handle_t Remove(mx_handle_t handle);
  mx_handle_t Unwrap(Dart_Handle handle, Dart_Handle* error);
  mx_handle_t Unwrap(mx_handle_t handle);
  mx_status_t Close(mx_handle_t handle);

  bool Empty() {
    return handles_.empty();
  }

 private:
  std::unordered_set<mx_handle_t> handles_;

  FTL_DISALLOW_COPY_AND_ASSIGN(HandleTable);
};

}

#endif  // LIB_TONIC_HANDLE_TABLE_H_
