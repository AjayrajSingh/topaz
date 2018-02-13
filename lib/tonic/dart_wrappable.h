// Copyright 2015 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef LIB_TONIC_DART_WRAPPABLE_H_
#define LIB_TONIC_DART_WRAPPABLE_H_

#include "third_party/dart/runtime/include/dart_api.h"
#include "lib/fxl/logging.h"
#include "lib/fxl/memory/ref_counted.h"
#include "lib/tonic/converter/dart_converter.h"
#include "lib/tonic/logging/dart_error.h"
#include "lib/tonic/dart_state.h"
#include "lib/tonic/dart_wrapper_info.h"

#include <type_traits>

namespace tonic {

// DartWrappable is a base class that you can inherit from in order to be
// exposed to Dart code as an interface.
class DartWrappable {
 public:
  enum DartNativeFields {
    kPeerIndex,  // Must be first to work with Dart_GetNativeReceiver.
    kWrapperInfoIndex,
    kNumberOfNativeFields,
  };

  DartWrappable() : dart_wrapper_(nullptr) {}

  // Subclasses that wish to expose a new interface must override this function
  // and provide information about their wrapper. There is no need to call your
  // base class's implementation of this function.
  virtual const DartWrapperInfo& GetDartWrapperInfo() const = 0;

  // Override this to customize the object size reported to the Dart garbage
  // collector.
  virtual size_t GetAllocationSize();

  Dart_Handle CreateDartWrapper(DartState* dart_state);
  void AssociateWithDartWrapper(Dart_NativeArguments args);
  void ClearDartWrapper();  // Warning: Might delete this.
  Dart_WeakPersistentHandle dart_wrapper() const { return dart_wrapper_; }

 protected:
  virtual ~DartWrappable();

  static Dart_PersistentHandle GetTypeForWrapper(
      tonic::DartState* dart_state, const tonic::DartWrapperInfo& wrapper_info);

 private:
  static void FinalizeDartWrapper(void* isolate_callback_data,
                                  Dart_WeakPersistentHandle wrapper,
                                  void* peer);

  Dart_WeakPersistentHandle dart_wrapper_;

  FXL_DISALLOW_COPY_AND_ASSIGN(DartWrappable);
};

#define DEFINE_WRAPPERTYPEINFO()                                      \
 public:                                                              \
  const tonic::DartWrapperInfo& GetDartWrapperInfo() const override { \
    return dart_wrapper_info_;                                        \
  }                                                                   \
  static Dart_PersistentHandle GetDartType(tonic::DartState* dart_state) { \
    return GetTypeForWrapper(dart_state, dart_wrapper_info_);         \
  }                                                                   \
                                                                      \
 private:                                                             \
  static const tonic::DartWrapperInfo& dart_wrapper_info_

#define IMPLEMENT_WRAPPERTYPEINFO(LibraryName, ClassName)                \
  static void RefObject_##LibraryName_##ClassName(                       \
      tonic::DartWrappable* impl) {                                      \
    static_cast<ClassName*>(impl)->AddRef();                             \
  }                                                                      \
  static void DerefObject_##LibraryName_##ClassName(                     \
      tonic::DartWrappable* impl) {                                      \
    static_cast<ClassName*>(impl)->Release();                            \
  }                                                                      \
  static const tonic::DartWrapperInfo                                    \
      kDartWrapperInfo_##LibraryName_##ClassName = {                     \
          #LibraryName,                                                  \
          #ClassName,                                                    \
          sizeof(ClassName),                                             \
          &RefObject_##LibraryName_##ClassName,                          \
          &DerefObject_##LibraryName_##ClassName,                        \
  };                                                                     \
  const tonic::DartWrapperInfo& ClassName::dart_wrapper_info_ =          \
      kDartWrapperInfo_##LibraryName_##ClassName;                        \
  static_assert(std::is_base_of<fxl::internal::RefCountedThreadSafeBase, \
                                ClassName>::value,                       \
                #ClassName " must be thread-safe reference-countable.");

struct DartConverterWrappable {
  static DartWrappable* FromDart(Dart_Handle handle);
  static DartWrappable* FromArguments(Dart_NativeArguments args,
                                      int index,
                                      Dart_Handle& exception);
};

template <typename T>
struct DartConverter<
    T*,
    typename std::enable_if<
        std::is_convertible<T*, const DartWrappable*>::value>::type> {
  static Dart_Handle ToDart(DartWrappable* val) {
    if (!val)
      return Dart_Null();
    if (Dart_WeakPersistentHandle wrapper = val->dart_wrapper())
      return Dart_HandleFromWeakPersistent(wrapper);
    return val->CreateDartWrapper(DartState::Current());
  }

  static void SetReturnValue(Dart_NativeArguments args,
                             DartWrappable* val,
                             bool auto_scope = true) {
    if (!val)
      Dart_SetReturnValue(args, Dart_Null());
    else if (Dart_WeakPersistentHandle wrapper = val->dart_wrapper())
      Dart_SetWeakHandleReturnValue(args, wrapper);
    else
      Dart_SetReturnValue(args, val->CreateDartWrapper(DartState::Current()));
  }

  static T* FromDart(Dart_Handle handle) {
    // TODO(abarth): We're missing a type check.
    return static_cast<T*>(DartConverterWrappable::FromDart(handle));
  }

  static T* FromArguments(Dart_NativeArguments args,
                          int index,
                          Dart_Handle& exception,
                          bool auto_scope = true) {
    // TODO(abarth): We're missing a type check.
    return static_cast<T*>(
        DartConverterWrappable::FromArguments(args, index, exception));
  }
};

template <typename T>
struct DartConverter<fxl::RefPtr<T>> {
  static Dart_Handle ToDart(const fxl::RefPtr<T>& val) {
    return DartConverter<T*>::ToDart(val.get());
  }

  static fxl::RefPtr<T> FromDart(Dart_Handle handle) {
    return DartConverter<T*>::FromDart(handle);
  }

  static fxl::RefPtr<T> FromArguments(Dart_NativeArguments args,
                                      int index,
                                      Dart_Handle& exception,
                                      bool auto_scope = true) {
    return fxl::RefPtr<T>(
        DartConverter<T*>::FromArguments(args, index, exception, auto_scope));
  }

  static void SetReturnValue(Dart_NativeArguments args,
                             const fxl::RefPtr<T>& val,
                             bool auto_scope = true) {
    DartConverter<T*>::SetReturnValue(args, val.get());
  }
};

template <typename T>
inline T* GetReceiver(Dart_NativeArguments args) {
  intptr_t receiver;
  Dart_Handle result = Dart_GetNativeReceiver(args, &receiver);
  FXL_DCHECK(!Dart_IsError(result));
  if (!receiver)
    Dart_ThrowException(ToDart("Object has been disposed."));
  return static_cast<T*>(reinterpret_cast<DartWrappable*>(receiver));
}

template <typename T>
struct DartListFactory<
    fxl::RefPtr<T>,
    typename std::enable_if<
        std::is_convertible<T*, const DartWrappable*>::value>::type> {
  static Dart_Handle NewList(intptr_t length) {
    Dart_PersistentHandle type = T::GetDartType(DartState::Current());
    FXL_DCHECK(!LogIfError(type));
    return Dart_NewListOfType(Dart_HandleFromPersistent(type), length);
  }
};

}  // namespace tonic

#endif  // LIB_TONIC_DART_WRAPPABLE_H_
