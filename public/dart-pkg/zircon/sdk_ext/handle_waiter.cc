// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "dart-pkg/zircon/sdk_ext/handle_waiter.h"

#include <lib/async/default.h>

#include "dart-pkg/zircon/sdk_ext/handle.h"
#include "src/lib/fxl/logging.h"
#include "third_party/dart/runtime/include/dart_api.h"
#include "third_party/tonic/converter/dart_converter.h"
#include "third_party/tonic/dart_args.h"
#include "third_party/tonic/dart_binding_macros.h"
#include "third_party/tonic/dart_library_natives.h"
#include "third_party/tonic/dart_message_handler.h"
#include "third_party/tonic/dart_microtask_queue.h"
#include "third_party/tonic/logging/dart_invoke.h"

using tonic::DartInvokeField;
using tonic::DartState;
using tonic::ToDart;

namespace zircon {
namespace dart {

IMPLEMENT_WRAPPERTYPEINFO(zircon, HandleWaiter);

#define FOR_EACH_BINDING(V) V(HandleWaiter, Cancel)

FOR_EACH_BINDING(DART_NATIVE_CALLBACK)

void HandleWaiter::RegisterNatives(tonic::DartLibraryNatives* natives) {
  natives->Register({FOR_EACH_BINDING(DART_REGISTER_NATIVE)});
}

fxl::RefPtr<HandleWaiter> HandleWaiter::Create(Handle* handle,
                                               zx_signals_t signals,
                                               Dart_Handle callback) {
  return fxl::MakeRefCounted<HandleWaiter>(handle, signals, callback);
}

HandleWaiter::HandleWaiter(Handle* handle, zx_signals_t signals,
                           Dart_Handle callback)
    : wait_(this, handle->handle(), signals),
      handle_(handle),
      callback_(DartState::Current(), callback) {
  FXL_CHECK(handle_ != nullptr);
  FXL_CHECK(handle_->is_valid());

  zx_status_t status = wait_.Begin(async_get_default_dispatcher());
  FXL_DCHECK(status == ZX_OK);
}

HandleWaiter::~HandleWaiter() { Cancel(); }

void HandleWaiter::Cancel() {
  FXL_DCHECK(wait_.is_pending() == !!handle_);
  if (handle_) {
    // Cancel the wait.
    wait_.Cancel();

    // Release this object from the handle and clear handle_.
    handle_->ReleaseWaiter(this);
    handle_ = nullptr;
  }
  FXL_DCHECK(!wait_.is_pending());
}

void HandleWaiter::OnWaitComplete(async_dispatcher_t* dispatcher,
                                  async::WaitBase* wait, zx_status_t status,
                                  const zx_packet_signal_t* signal) {
  FXL_DCHECK(handle_);

  FXL_DCHECK(!callback_.is_empty());

  // Hold a reference to this object.
  fxl::RefPtr<HandleWaiter> ref(this);

  // Remove this waiter from the handle.
  handle_->ReleaseWaiter(this);

  // Clear handle_.
  handle_ = nullptr;

  auto state = callback_.dart_state().lock();
  FXL_DCHECK(state);
  DartState::Scope scope(state);

  // Put the closure invocation on the microtask queue.
  Dart_Handle zircon_lib = Dart_LookupLibrary(ToDart("dart:zircon"));
  FXL_DCHECK(!tonic::LogIfError(zircon_lib));

  Dart_Handle owc_type =
      Dart_GetClass(zircon_lib, ToDart("_OnWaitCompleteClosure"));
  FXL_DCHECK(!tonic::LogIfError(owc_type));

  FXL_DCHECK(!callback_.is_empty());
  std::vector<Dart_Handle> owc_args{
      callback_.Release(), ToDart(status), ToDart(signal->observed)};
  Dart_Handle owc = Dart_New(
      owc_type, Dart_Null(), owc_args.size(), owc_args.data());
  FXL_DCHECK(!tonic::LogIfError(owc));

  Dart_Handle closure = Dart_GetField(owc, ToDart("_closure"));
  FXL_DCHECK(!tonic::LogIfError(closure));

  // TODO(issue#tbd): Use tonic::DartMicrotaskQueue::ScheduleMicrotask()
  // instead when tonic::DartState gets a microtask queue field.
  Dart_Handle async_lib = Dart_LookupLibrary(ToDart("dart:async"));
  FXL_DCHECK(!tonic::LogIfError(async_lib));
  std::vector<Dart_Handle> sm_args{closure};
  Dart_Handle sm_result = Dart_Invoke(
      async_lib, ToDart("scheduleMicrotask"), sm_args.size(), sm_args.data());
  FXL_DCHECK(!tonic::LogIfError(sm_result));
}

}  // namespace dart
}  // namespace zircon
