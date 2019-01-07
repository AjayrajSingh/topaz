// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "isolate_configurator.h"

#include "dart-pkg/fuchsia/sdk_ext/fuchsia.h"
#include "dart-pkg/zircon/sdk_ext/handle.h"
#include "lib/ui/flutter/sdk_ext/src/natives.h"
#include "third_party/dart/runtime/include/dart_api.h"
#include "third_party/tonic/converter/dart_converter.h"
#include "third_party/tonic/dart_state.h"
#include "third_party/tonic/logging/dart_error.h"

namespace flutter {

IsolateConfigurator::IsolateConfigurator(
    UniqueFDIONS fdio_ns,
#ifndef SCENIC_VIEWS2
    fidl::InterfaceHandle<fuchsia::ui::viewsv1::ViewContainer> view_container,
    fidl::InterfaceHandle<fuchsia::sys::Environment> environment,
#else
    fidl::InterfaceHandle<fuchsia::sys::Environment> environment,
#endif
    zx::channel directory_request)
    : fdio_ns_(std::move(fdio_ns)),
#ifndef SCENIC_VIEWS2
      view_container_(std::move(view_container)),
#endif
      environment_(std::move(environment)),
      directory_request_(std::move(directory_request)) {
}

IsolateConfigurator::~IsolateConfigurator() = default;

bool IsolateConfigurator::ConfigureCurrentIsolate(
    mozart::NativesDelegate* natives_delegate) {
  if (used_) {
    return false;
  }
  used_ = true;

  BindFuchsia();
  BindZircon();
  BindDartIO();
  BindScenic(natives_delegate);

  // This is now owned by the Dart bindings. So relinquish our ownership of the
  // handle.
  (void)fdio_ns_.release();

  return true;
}

void IsolateConfigurator::BindFuchsia() {
  fuchsia::dart::Initialize(std::move(environment_),
                            std::move(directory_request_));
}

void IsolateConfigurator::BindZircon() {
  // Tell dart:zircon about the FDIO namespace configured for this instance.
  Dart_Handle zircon_lib = Dart_LookupLibrary(tonic::ToDart("dart:zircon"));
  DART_CHECK_VALID(zircon_lib);

  Dart_Handle namespace_type =
      Dart_GetType(zircon_lib, tonic::ToDart("_Namespace"), 0, nullptr);
  DART_CHECK_VALID(namespace_type);
  DART_CHECK_VALID(
      Dart_SetField(namespace_type,               //
                    tonic::ToDart("_namespace"),  //
                    tonic::ToDart(reinterpret_cast<intptr_t>(fdio_ns_.get()))));
}

void IsolateConfigurator::BindDartIO() {
  // Grab the dart:io lib.
  Dart_Handle io_lib = Dart_LookupLibrary(tonic::ToDart("dart:io"));
  DART_CHECK_VALID(io_lib);

  // Disable dart:io exit()
  Dart_Handle embedder_config_type =
      Dart_GetType(io_lib, tonic::ToDart("_EmbedderConfig"), 0, nullptr);
  DART_CHECK_VALID(embedder_config_type);
  DART_CHECK_VALID(Dart_SetField(embedder_config_type,
                                 tonic::ToDart("_mayExit"), Dart_False()));

  // Tell dart:io about the FDIO namespace configured for this instance.
  Dart_Handle namespace_type =
      Dart_GetType(io_lib, tonic::ToDart("_Namespace"), 0, nullptr);
  DART_CHECK_VALID(namespace_type);
  Dart_Handle namespace_args[] = {
      Dart_NewInteger(reinterpret_cast<intptr_t>(fdio_ns_.get())),  //
  };
  DART_CHECK_VALID(namespace_args[0]);
  DART_CHECK_VALID(Dart_Invoke(namespace_type, tonic::ToDart("_setupNamespace"),
                               1, namespace_args));
}

void IsolateConfigurator::BindScenic(
    mozart::NativesDelegate* natives_delegate) {
  Dart_Handle mozart_internal =
      Dart_LookupLibrary(tonic::ToDart("dart:mozart.internal"));
  DART_CHECK_VALID(mozart_internal);
  DART_CHECK_VALID(Dart_SetNativeResolver(mozart_internal,       //
                                          mozart::NativeLookup,  //
                                          mozart::NativeSymbol)  //
  );
  DART_CHECK_VALID(Dart_SetField(
      mozart_internal,            //
      tonic::ToDart("_context"),  //
      tonic::DartConverter<uint64_t>::ToDart(reinterpret_cast<intptr_t>(
          static_cast<mozart::NativesDelegate*>(natives_delegate)))));
#ifndef SCENIC_VIEWS2
  DART_CHECK_VALID(
      Dart_SetField(mozart_internal,                  //
                    tonic::ToDart("_viewContainer"),  //
                    tonic::ToDart(zircon::dart::Handle::Create(
                        view_container_.TakeChannel().release()))));
#else
  // TODO(SCN-840): Remove remaining references to _viewContainer.
#endif
}

}  // namespace flutter
