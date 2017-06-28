// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/handle_table.h"

#include <unordered_map>

#include <magenta/crashlogger.h>

#include "lib/ftl/logging.h"
#include "lib/ftl/random/rand.h"
#include "lib/tonic/dart_state.h"

namespace tonic {

namespace {

// 16-bit circular shift.
uint32_t rotate16(uint32_t in) {
  return in << 16 | in >> 16;
}

uint64_t to_dart(mx_handle_t in) {
  assert(in >= 0);
  return rotate16(in);
}

mx_handle_t from_dart(uint64_t in) {
  mx_handle_t out = rotate16(in);
  assert(out >= 0);
  return out;
}

}  // namespace

HandleTable::HandleTable() { }

HandleTable::~HandleTable() {
  for (mx_handle_t handle : handles_) {
    mx_handle_close(handle);
  }
}

HandleTable& HandleTable::Current() {
  return DartState::Current()->handle_table();
}

mx_handle_t HandleTable::Add(mx_handle_t handle) {
  if (handle != MX_HANDLE_INVALID) {
    handles_.insert(handle);
  }
  return handle;
}

Dart_Handle HandleTable::AddAndWrap(mx_handle_t handle) {
  uint64_t dart_handle = to_dart(Add(handle));
  return Dart_NewIntegerFromUint64(dart_handle);
}

Dart_Handle HandleTable::AddAndWrap(mx_handle_t* handles,
                                    size_t count,
                                    Dart_Handle array) {
  Dart_TypedData_Type array_type;
  uint32_t* array_data;
  intptr_t array_length;
  Dart_Handle err;

  if (count == 0) {
    // Nothing to do here, move along please.
    return array;
  }

  // Make sure that |array| is a typed data array that is can hold at least
  // |count| uint32s.
  if (Dart_IsNull(array) || !Dart_IsTypedData(array) ||
      Dart_GetTypeOfTypedData(array) != Dart_TypedData_kUint32) {
    // Allocate a Dart array if none was passed or what was passed isn't a
    // uint32 typed array.
    array = Dart_NewTypedData(Dart_TypedData_kUint32, count);
    FTL_DCHECK(!Dart_IsError(array));
  } else {
    void* data_ptr;
    err =
        Dart_TypedDataAcquireData(array, &array_type, &data_ptr, &array_length);
    FTL_DCHECK(!Dart_IsError(err));
    err = Dart_TypedDataReleaseData(array);
    FTL_DCHECK(!Dart_IsError(err));
    // The Dart typed data array that was passed in isn't large enough to hold
    // all of the handles. Try again without the array.
    if (array_length < static_cast<intptr_t>(count)) {
      return AddAndWrap(handles, count, Dart_Null());
    }
  }

  // Copy & transform handles.
  void* array_data_ptr;
  err = Dart_TypedDataAcquireData(array, &array_type, &array_data_ptr,
                                  &array_length);
  FTL_DCHECK(!Dart_IsError(err));
  FTL_DCHECK(array_length >= static_cast<intptr_t>(count));
  array_data = static_cast<uint32_t*>(array_data_ptr);
  for (size_t i = 0; i < count; i++) {
    array_data[i] = to_dart(Add(handles[i]));
  }
  err = Dart_TypedDataReleaseData(array);
  FTL_DCHECK(!Dart_IsError(err));

  return array;
}

mx_handle_t HandleTable::Remove(mx_handle_t handle) {
  if (handle != MX_HANDLE_INVALID) {
    const auto& iter = handles_.find(handle);
    if (iter == handles_.end()) {
      return MX_HANDLE_INVALID;
    } else {
      handles_.erase(iter);
    }
  }
  return handle;
}

mx_handle_t HandleTable::Unwrap(Dart_Handle dart_handle, Dart_Handle* error) {
  uint64_t dart = 0;
  Dart_Handle result = Dart_IntegerToUint64(dart_handle, &dart);
  if (Dart_IsError(result)) {
    crashlogger_request_backtrace();
    if (error) {
      *error = result;
    }
    return MX_HANDLE_INVALID;
  }

  return Unwrap(dart);
}

mx_handle_t HandleTable::Unwrap(mx_handle_t handle) {
  handle = from_dart(handle);

  if (handle == MX_HANDLE_INVALID) {
    return handle;
  }

  if (handles_.find(handle) == handles_.end()) {
    return MX_HANDLE_INVALID;
  }

  return handle;
}

mx_status_t HandleTable::Close(mx_handle_t handle) {
  if (handle == MX_HANDLE_INVALID) {
    return MX_ERR_BAD_HANDLE;
  }

  const auto& iter = handles_.find(handle);
  if (iter == handles_.end()) {
    return MX_ERR_BAD_HANDLE;
  } else {
    mx_status_t status = mx_handle_close(handle);
    handles_.erase(iter);
    return status;
  }
}

}  // namespace tonic
