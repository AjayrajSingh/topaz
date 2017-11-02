// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "lib/tonic/dart_wrappable.h"

#include "lib/tonic/dart_class_library.h"
#include "lib/tonic/logging/dart_error.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/dart_wrapper_info.h"

namespace tonic {

DartWrappable::~DartWrappable() {
  FXL_CHECK(!dart_wrapper_);
}

Dart_Handle DartWrappable::CreateDartWrapper(DartState* dart_state) {
  FXL_DCHECK(!dart_wrapper_);
  const DartWrapperInfo& info = GetDartWrapperInfo();

  Dart_PersistentHandle type = dart_state->class_library().GetClass(info);
  FXL_DCHECK(!LogIfError(type));

  intptr_t native_fields[kNumberOfNativeFields];
  native_fields[kPeerIndex] = reinterpret_cast<intptr_t>(this);
  native_fields[kWrapperInfoIndex] = reinterpret_cast<intptr_t>(&info);
  Dart_Handle wrapper =
      Dart_AllocateWithNativeFields(type, kNumberOfNativeFields, native_fields);
  FXL_DCHECK(!LogIfError(wrapper));

  info.ref_object(this);  // Balanced in FinalizeDartWrapper.
  dart_wrapper_ = Dart_NewWeakPersistentHandle(
      wrapper, this, GetAllocationSize(), &FinalizeDartWrapper);

  return wrapper;
}

void DartWrappable::AssociateWithDartWrapper(Dart_NativeArguments args) {
  FXL_DCHECK(!dart_wrapper_);

  Dart_Handle wrapper = Dart_GetNativeArgument(args, 0);
  FXL_CHECK(!LogIfError(wrapper));

  intptr_t native_fields[kNumberOfNativeFields];
  FXL_CHECK(!LogIfError(Dart_GetNativeFieldsOfArgument(
      args, 0, kNumberOfNativeFields, native_fields)));
  FXL_CHECK(!native_fields[kPeerIndex]);
  FXL_CHECK(!native_fields[kWrapperInfoIndex]);

  const DartWrapperInfo& info = GetDartWrapperInfo();
  FXL_CHECK(!LogIfError(Dart_SetNativeInstanceField(
      wrapper, kPeerIndex, reinterpret_cast<intptr_t>(this))));
  FXL_CHECK(!LogIfError(Dart_SetNativeInstanceField(
      wrapper, kWrapperInfoIndex, reinterpret_cast<intptr_t>(&info))));

  info.ref_object(this);  // Balanced in FinalizeDartWrapper.
  dart_wrapper_ = Dart_NewWeakPersistentHandle(
      wrapper, this, GetAllocationSize(), &FinalizeDartWrapper);
}

void DartWrappable::ClearDartWrapper() {
  FXL_DCHECK(dart_wrapper_);
  Dart_Handle wrapper = Dart_HandleFromWeakPersistent(dart_wrapper_);
  FXL_CHECK(!LogIfError(Dart_SetNativeInstanceField(wrapper, kPeerIndex, 0)));
  FXL_CHECK(
      !LogIfError(Dart_SetNativeInstanceField(wrapper, kWrapperInfoIndex, 0)));
  Dart_DeleteWeakPersistentHandle(Dart_CurrentIsolate(), dart_wrapper_);
  dart_wrapper_ = nullptr;
  GetDartWrapperInfo().deref_object(this);
}

void DartWrappable::FinalizeDartWrapper(void* isolate_callback_data,
                                        Dart_WeakPersistentHandle wrapper,
                                        void* peer) {
  DartWrappable* wrappable = reinterpret_cast<DartWrappable*>(peer);
  wrappable->dart_wrapper_ = nullptr;
  const DartWrapperInfo& info = wrappable->GetDartWrapperInfo();
  info.deref_object(wrappable);  // Balanced in CreateDartWrapper.
}

size_t DartWrappable::GetAllocationSize() {
  return GetDartWrapperInfo().size_in_bytes;
}

DartWrappable* DartConverterWrappable::FromDart(Dart_Handle handle) {
  intptr_t peer = 0;
  Dart_Handle result =
      Dart_GetNativeInstanceField(handle, DartWrappable::kPeerIndex, &peer);
  if (Dart_IsError(result))
    return nullptr;
  return reinterpret_cast<DartWrappable*>(peer);
}

DartWrappable* DartConverterWrappable::FromArguments(Dart_NativeArguments args,
                                                     int index,
                                                     Dart_Handle& exception) {
  intptr_t native_fields[DartWrappable::kNumberOfNativeFields];
  Dart_Handle result = Dart_GetNativeFieldsOfArgument(
      args, index, DartWrappable::kNumberOfNativeFields, native_fields);
  if (Dart_IsError(result)) {
    exception = Dart_NewStringFromCString(DartError::kInvalidArgument);
    return nullptr;
  }
  if (!native_fields[DartWrappable::kPeerIndex])
    return nullptr;
  return reinterpret_cast<DartWrappable*>(
      native_fields[DartWrappable::kPeerIndex]);
}

}  // namespace tonic
